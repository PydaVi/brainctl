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

  app_instance_subnet_ids       = var.enable_lb && length(var.lb_subnet_ids) > 0 ? var.lb_subnet_ids : [var.subnet_id]
  db_subnet_group_subnet_ids    = var.enable_lb && length(var.lb_subnet_ids) > 0 ? var.lb_subnet_ids : [var.subnet_id]
  endpoint_subnet_ids          = length(var.endpoint_subnet_ids) > 0 ? var.endpoint_subnet_ids : [var.subnet_id]

  resolved_app_ami = var.app_ami_id != "" ? var.app_ami_id : data.aws_ami.windows_2022.id
  resolved_db_ami  = var.db_ami_id  != "" ? var.db_ami_id  : data.aws_ami.windows_2022.id

  app_custom_user_data = var.app_user_data_base64 != "" ? base64decode(var.app_user_data_base64) : ""
  db_custom_user_data  = var.db_user_data_base64  != "" ? base64decode(var.db_user_data_base64)  : ""

  app_default_user_data = var.enable_observability ? local.cw_user_data_app : ""
  db_default_user_data  = var.enable_observability ? local.cw_user_data_db  : ""

  app_effective_user_data_script = (
    var.app_user_data_mode == "default" ? local.app_default_user_data :
    var.app_user_data_mode == "custom"  ? local.app_custom_user_data :
    trimspace(join("\n", compact([
      local.app_default_user_data,
      local.app_custom_user_data
    ])))
  )

  db_effective_user_data_script = (
    var.db_user_data_mode == "default" ? local.db_default_user_data :
    var.db_user_data_mode == "custom"  ? local.db_custom_user_data :
    trimspace(join("\n", compact([
      local.db_default_user_data,
      local.db_custom_user_data
    ])))
  )

  app_effective_user_data = (
    trimspace(local.app_effective_user_data_script) != ""
    ? format("<powershell>\n%s\n</powershell>", trimspace(local.app_effective_user_data_script))
    : ""
  )

  db_effective_user_data = (
    trimspace(local.db_effective_user_data_script) != ""
    ? format("<powershell>\n%s\n</powershell>", trimspace(local.db_effective_user_data_script))
    : ""
  )

  sns_enabled   = var.enable_observability && var.alert_email != ""
  alarm_actions = local.sns_enabled ? [aws_sns_topic.alerts[0].arn] : []

  ############################################
  # CLOUDWATCH CONFIG APP
  ############################################

  cw_agent_config_app = jsonencode({
    agent = {
      metrics_collection_interval = 60
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
          measurement = [
            {
              name   = "Available MBytes"
              rename = "mem_available_mb"
              unit   = "Megabytes"
            },
            {
              name   = "Commit Limit"
              rename = "mem_commit_limit_bytes"
              unit   = "Bytes"
            }
          ]
        }
        TCPv4 = {
          measurement = [
            {
              name   = "Connections Established"
              rename = "tcp_connections_established"
              unit   = "Count"
            }
          ]
        }
      }
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "C:\\inetpub\\logs\\LogFiles\\W3SVC*\\*.log"
              log_group_name  = local.cw_log_group_name
              log_stream_name = "${local.app_instance_label}/iis"
              timezone        = "UTC"
            }
          ]
        }
        windows_events = {
          collect_list = [
            {
              event_name      = "System"
              event_levels    = ["ERROR", "WARNING", "CRITICAL"]
              log_group_name  = local.cw_log_group_name
              log_stream_name = "${local.app_instance_label}/system"
            }
          ]
        }
      }
    }
  })

  ############################################
  # CLOUDWATCH CONFIG DB
  ############################################

  cw_agent_config_db = jsonencode({
    agent = {
      metrics_collection_interval = 60
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
          measurement = [
            {
              name   = "Available MBytes"
              rename = "mem_available_mb"
              unit   = "Megabytes"
            },
            {
              name   = "Commit Limit"
              rename = "mem_commit_limit_bytes"
              unit   = "Bytes"
            }
          ]
        }
      }
    }
    logs = {
      logs_collected = {
        windows_events = {
          collect_list = [
            {
              event_name      = "Application"
              event_levels    = ["ERROR", "WARNING", "CRITICAL"]
              log_group_name  = local.cw_log_group_name
              log_stream_name = "${local.db_instance_label}/application"
            }
          ]
        }
      }
    }
  })

  ############################################
  # USER DATA - APP (SEM WRAPPER)
  ############################################

  cw_user_data_app = <<-EOT
$ErrorActionPreference = "Stop"

$brainctlLogPath = "C:\ProgramData\Amazon\EC2Launch\log\brainctl-userdata.log"

function Write-BrainctlLog([string]$message) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  Add-Content -Path $brainctlLogPath -Value "$ts [APP] $message"
}

Write-BrainctlLog "Starting CloudWatch bootstrap"

New-Item -ItemType Directory -Force -Path "C:\ProgramData\Amazon\AmazonCloudWatchAgent" | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$jsonContent = @'
${local.cw_agent_config_app}
'@

[System.IO.File]::WriteAllText(
  "C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json",
  $jsonContent,
  $utf8NoBom
)

$cwCtl = "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"

if (Test-Path $cwCtl) {
  try {
    & $cwCtl -a fetch-config -m ec2 -s -c file:"C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json"
    Write-BrainctlLog "CloudWatch Agent bootstrap completed"
  }
  catch {
    Write-BrainctlLog "CloudWatch Agent bootstrap failed but provisioning will continue: $($_.Exception.Message)"
  }
}
else {
  Write-BrainctlLog "CloudWatch Agent bootstrap skipped (agent not present in AMI)"
}
EOT

  ############################################
  # USER DATA - DB (SEM WRAPPER)
  ############################################

  cw_user_data_db = <<-EOT
$ErrorActionPreference = "Stop"

$brainctlLogPath = "C:\ProgramData\Amazon\EC2Launch\log\brainctl-userdata.log"

function Write-BrainctlLog([string]$message) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  Add-Content -Path $brainctlLogPath -Value "$ts [DB] $message"
}

Write-BrainctlLog "Starting CloudWatch bootstrap"

New-Item -ItemType Directory -Force -Path "C:\ProgramData\Amazon\AmazonCloudWatchAgent" | Out-Null

@'
${local.cw_agent_config_db}
'@ | Set-Content -Path "C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json" -Encoding UTF8

$cwCtl = "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"

if (Test-Path $cwCtl) {
  try {
    & $cwCtl -a fetch-config -m ec2 -s -c file:"C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json"
    Write-BrainctlLog "CloudWatch Agent bootstrap completed"
  }
  catch {
    Write-BrainctlLog "CloudWatch Agent bootstrap failed but provisioning will continue: $($_.Exception.Message)"
  }
}
else {
  Write-BrainctlLog "CloudWatch Agent bootstrap skipped (agent not present in AMI)"
}
EOT
}
