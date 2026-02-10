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

locals {
  alb_internal       = var.lb_scheme == "private" ? true : false
  cw_log_group_name  = "/brainctl/${var.name}/${var.environment}"
  app_instance_label = "${var.name}-${var.environment}-app"
  db_instance_label  = "${var.name}-${var.environment}-db"

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

resource "aws_iam_role" "ec2_cw_role" {
  count = var.enable_observability ? 1 : 0
  name  = "${var.name}-${var.environment}-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cw_agent" {
  count      = var.enable_observability ? 1 : 0
  role       = aws_iam_role.ec2_cw_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_cw_profile" {
  count = var.enable_observability ? 1 : 0
  name  = "${var.name}-${var.environment}-cw-profile"
  role  = aws_iam_role.ec2_cw_role[0].name
}

resource "aws_cloudwatch_log_group" "brainctl" {
  count             = var.enable_observability ? 1 : 0
  name              = local.cw_log_group_name
  retention_in_days = 14

  tags = {
    Name        = local.cw_log_group_name
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_sns_topic" "alerts" {
  count = local.sns_enabled ? 1 : 0
  name  = "${var.name}-${var.environment}-alerts"

  tags = {
    Name        = "${var.name}-${var.environment}-alerts"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = local.sns_enabled ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_security_group" "app_sg" {
  name        = "${var.name}-${var.environment}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_rdp_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-${var.environment}-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.windows_2022.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  iam_instance_profile = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  user_data            = var.enable_observability ? local.cw_user_data_app : null

  tags = {
    Name        = "${var.name}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "brainctl"
    Role        = "app"
  }
}

resource "aws_security_group" "db_sg" {
  count       = var.enable_db ? 1 : 0
  name        = "${var.name}-${var.environment}-db-sg"
  description = "DB security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB from app SG"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-${var.environment}-db-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_instance" "db" {
  count         = var.enable_db ? 1 : 0
  ami           = data.aws_ami.windows_2022.id
  instance_type = var.db_instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.db_sg[0].id]

  iam_instance_profile = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  user_data            = var.enable_observability ? local.cw_user_data_db : null

  tags = {
    Name        = "${var.name}-${var.environment}-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
    Role        = "db"
  }
}

resource "aws_security_group" "alb_sg" {
  count       = var.enable_lb ? 1 : 0
  name        = "${var.name}-${var.environment}-alb-sg"
  description = "ALB SG for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Listener"
    from_port   = var.lb_listener_port
    to_port     = var.lb_listener_port
    protocol    = "tcp"
    cidr_blocks = [var.lb_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-${var.environment}-alb-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_security_group_rule" "app_from_alb" {
  count                    = var.enable_lb ? 1 : 0
  type                     = "ingress"
  security_group_id        = aws_security_group.app_sg.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg[0].id
  description              = "App port from ALB"
}

resource "aws_lb" "app_alb" {
  count              = var.enable_lb ? 1 : 0
  name               = substr("${var.name}-${var.environment}-alb", 0, 32)
  internal           = local.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg[0].id]
  subnets            = var.lb_subnet_ids

  tags = {
    Name        = "${var.name}-${var.environment}-alb"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_lb_target_group" "app_tg" {
  count    = var.enable_lb ? 1 : 0
  name     = substr("${var.name}-${var.environment}-tg", 0, 32)
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.name}-${var.environment}-tg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_lb_listener" "http" {
  count             = var.enable_lb ? 1 : 0
  load_balancer_arn = aws_lb.app_alb[0].arn
  port              = var.lb_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg[0].arn
  }
}

resource "aws_lb_target_group_attachment" "app_attach" {
  count            = var.enable_lb ? 1 : 0
  target_group_arn = aws_lb_target_group.app_tg[0].arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}

resource "aws_cloudwatch_dashboard" "app" {
  count          = var.enable_observability ? 1 : 0
  dashboard_name = "brainctl-${var.name}-${var.environment}-app"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "APP CPUUtilization"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app.id]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "APP StatusCheckFailed"
          view    = "timeSeries"
          region  = var.region
          stat    = "Maximum"
          period  = 60
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.app.id]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "APP Memory % (CWAgent)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["CWAgent", "Memory % Committed Bytes In Use", "InstanceId", aws_instance.app.id, "objectname", "Memory"]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "APP Disk Free % (CWAgent)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["CWAgent", "LogicalDisk % Free Space", "InstanceId", aws_instance.app.id, "objectname", "LogicalDisk", "instance", "C:"]]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "db" {
  count          = var.enable_observability && var.enable_db ? 1 : 0
  dashboard_name = "brainctl-${var.name}-${var.environment}-db"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "DB CPUUtilization"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.db[0].id]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "DB StatusCheckFailed"
          view    = "timeSeries"
          region  = var.region
          stat    = "Maximum"
          period  = 60
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.db[0].id]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "DB Memory % (CWAgent)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["CWAgent", "Memory % Committed Bytes In Use", "InstanceId", aws_instance.db[0].id, "objectname", "Memory"]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "DB Disk Free % (CWAgent)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["CWAgent", "LogicalDisk % Free Space", "InstanceId", aws_instance.db[0].id, "objectname", "LogicalDisk", "instance", "C:"]]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "app_cpu_high" {
  count               = var.enable_observability ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "CPU alta na instância APP"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

resource "aws_cloudwatch_metric_alarm" "app_status_check_failed" {
  count               = var.enable_observability ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Falha de status check na APP"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

resource "aws_cloudwatch_metric_alarm" "app_unreachable" {
  count               = var.enable_observability ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-unreachable"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Instância APP inacessível"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    InstanceId = aws_instance.app.id
  }
}

resource "aws_cloudwatch_metric_alarm" "app_disk_low_free" {
  count               = var.enable_observability ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-disk-low-free"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "LogicalDisk % Free Space"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 15
  alarm_description   = "Disco com pouco espaço livre na APP"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    InstanceId = aws_instance.app.id
    objectname = "LogicalDisk"
    instance   = "C:"
  }
}

resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  count               = var.enable_observability && var.enable_db ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "CPU alta na instância DB"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    InstanceId = aws_instance.db[0].id
  }
}
