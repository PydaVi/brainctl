provider "aws" {
  region = var.region
}

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  alb_internal       = var.lb_scheme == "private" ? true : false
  cw_log_group_name  = "/brainctl/${var.name}/${var.environment}"
  app_instance_label = "${var.name}-${var.environment}-app"
  db_instance_label  = "${var.name}-${var.environment}-db"

  resolved_app_ami = var.app_ami_id != "" ? var.app_ami_id : data.aws_ami.windows_2022.id
  resolved_db_ami  = var.db_ami_id != "" ? var.db_ami_id : data.aws_ami.windows_2022.id

  app_custom_user_data = var.app_user_data_base64 != "" ? base64decode(var.app_user_data_base64) : ""
  db_custom_user_data  = var.db_user_data_base64 != "" ? base64decode(var.db_user_data_base64) : ""

  app_default_user_data = var.enable_observability ? local.cw_user_data_app : ""
  db_default_user_data  = var.enable_observability ? local.cw_user_data_db : ""

  app_effective_user_data = var.app_user_data_mode == "default" ? local.app_default_user_data : (
    var.app_user_data_mode == "custom" ? local.app_custom_user_data : trimspace(join("\n", compact([local.app_default_user_data, local.app_custom_user_data])))
  )
  db_effective_user_data = var.db_user_data_mode == "default" ? local.db_default_user_data : (
    var.db_user_data_mode == "custom" ? local.db_custom_user_data : trimspace(join("\n", compact([local.db_default_user_data, local.db_custom_user_data])))
  )

  sns_enabled   = var.enable_observability && var.alert_email != ""
  alarm_actions = local.sns_enabled ? [aws_sns_topic.alerts[0].arn] : []

  cw_agent_config_app = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    metrics = {
      namespace = "BrainCTL/${var.name}/${var.environment}"
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }
      metrics_collected = {
        LogicalDisk = {
          measurement = ["% Free Space"]
          resources   = ["*"]
        }
        Memory = {
          measurement = ["% Committed Bytes In Use"]
        }
      }
    }
    logs = {
      logs_collected = {
        windows_events = {
          collect_list = [
            {
              event_name      = "System"
              levels          = ["ERROR", "WARNING", "CRITICAL"]
              log_group_name  = local.cw_log_group_name
              log_stream_name = "${local.app_instance_label}/system"
            }
          ]
        }
      }
    }
  })

  cw_agent_config_db = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    metrics = {
      namespace = "BrainCTL/${var.name}/${var.environment}"
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }
      metrics_collected = {
        LogicalDisk = {
          measurement = ["% Free Space"]
          resources   = ["*"]
        }
        Memory = {
          measurement = ["% Committed Bytes In Use"]
        }
      }
    }
    logs = {
      logs_collected = {
        windows_events = {
          collect_list = [
            {
              event_name      = "Application"
              levels          = ["ERROR", "WARNING", "CRITICAL"]
              log_group_name  = local.cw_log_group_name
              log_stream_name = "${local.db_instance_label}/application"
            }
          ]
        }
      }
    }
  })

  cw_user_data_app = <<-EOT
    <powershell>
      $ErrorActionPreference = "Stop"
      New-Item -ItemType Directory -Force -Path "C:\ProgramData\Amazon\AmazonCloudWatchAgent" | Out-Null

      @'
${local.cw_agent_config_app}
'@ | Set-Content -Path "C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json" -Encoding UTF8

      & "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" `
        -a fetch-config -m ec2 -s `
        -c file:"C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json"
    </powershell>
  EOT

  cw_user_data_db = <<-EOT
    <powershell>
      $ErrorActionPreference = "Stop"
      New-Item -ItemType Directory -Force -Path "C:\ProgramData\Amazon\AmazonCloudWatchAgent" | Out-Null

      @'
${local.cw_agent_config_db}
'@ | Set-Content -Path "C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json" -Encoding UTF8

      & "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" `
        -a fetch-config -m ec2 -s `
        -c file:"C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json"
    </powershell>
  EOT
}
