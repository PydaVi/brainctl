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

  dynamic "ingress" {
    for_each = var.app_extra_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
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
  count         = var.enable_app_asg ? 0 : 1
  ami           = local.resolved_app_ami
  instance_type = var.instance_type
  subnet_id     = var.enable_app_asg ? null : var.subnet_id

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = var.imds_v2_required ? "required" : "optional"
  }

  iam_instance_profile = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  user_data            = local.app_effective_user_data != "" ? local.app_effective_user_data : null

  volume_tags = {
    Name        = "${var.name}-${var.environment}-app-root"
    Environment = var.environment
    ManagedBy   = "brainctl"
    App         = var.name
    BackupScope = "app"
  }

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

  dynamic "ingress" {
    for_each = var.db_extra_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
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
  ami           = local.resolved_db_ami
  instance_type = var.db_instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.db_sg[0].id]

  iam_instance_profile = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  user_data            = local.db_effective_user_data != "" ? local.db_effective_user_data : null

  volume_tags = {
    Name        = "${var.name}-${var.environment}-db-root"
    Environment = var.environment
    ManagedBy   = "brainctl"
    App         = var.name
    BackupScope = "db"
  }

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

  dynamic "ingress" {
    for_each = var.alb_extra_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
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
  count            = var.enable_lb && !var.enable_app_asg ? 1 : 0
  target_group_arn = aws_lb_target_group.app_tg[0].arn
  target_id        = aws_instance.app[0].id
  port             = var.app_port
}

resource "aws_launch_template" "app" {
  count = var.enable_app_asg ? 1 : 0

  name_prefix   = "${var.name}-${var.environment}-lt-"
  image_id      = local.resolved_app_ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  iam_instance_profile {
    name = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  }

  user_data = local.app_effective_user_data != "" ? base64encode(local.app_effective_user_data) : null

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = var.imds_v2_required ? "required" : "optional"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.name}-${var.environment}"
      Environment = var.environment
      ManagedBy   = "brainctl"
      Role        = "app"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.name}-${var.environment}-app-root"
      Environment = var.environment
      ManagedBy   = "brainctl"
      App         = var.name
      BackupScope = "app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  count = var.enable_app_asg ? 1 : 0

  name                      = "${var.name}-${var.environment}-asg"
  min_size                  = var.app_asg_min_size
  max_size                  = var.app_asg_max_size
  desired_capacity          = var.app_asg_desired_capacity
  health_check_type         = var.enable_lb ? "ELB" : "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = var.app_asg_subnet_ids
  target_group_arns         = var.enable_lb ? [aws_lb_target_group.app_tg[0].arn] : []

  launch_template {
    id      = aws_launch_template.app[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "brainctl"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "app_cpu_target" {
  count = var.enable_app_asg ? 1 : 0

  name                   = "${var.name}-${var.environment}-asg-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.app_asg_cpu_target
  }
}

resource "aws_cloudwatch_dashboard" "app" {
  count          = var.enable_observability && !var.enable_app_asg ? 1 : 0
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
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app[0].id]]
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
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.app[0].id]]
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
          metrics = [["CWAgent", "Memory % Committed Bytes In Use", "InstanceId", aws_instance.app[0].id, "objectname", "Memory"]]
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
          metrics = [["CWAgent", "LogicalDisk % Free Space", "InstanceId", aws_instance.app[0].id, "objectname", "LogicalDisk", "instance", "C:"]]
        }
      }
    ]
  })
}


resource "aws_cloudwatch_dashboard" "app_asg" {
  count          = var.enable_observability && var.enable_app_asg ? 1 : 0
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
          title   = "APP ASG Average CPU"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["AWS/AutoScaling", "GroupAverageCPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app[0].name]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "APP InService vs Desired"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.app[0].name],
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.app[0].name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "APP TG UnHealthyHostCount"
          view    = "timeSeries"
          region  = var.region
          stat    = "Maximum"
          period  = 60
          metrics = [["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.app_alb[0].arn_suffix, "TargetGroup", aws_lb_target_group.app_tg[0].arn_suffix]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "APP TG 5XX"
          view    = "timeSeries"
          region  = var.region
          stat    = "Sum"
          period  = 60
          metrics = [["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.app_alb[0].arn_suffix, "TargetGroup", aws_lb_target_group.app_tg[0].arn_suffix]]
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
  count               = var.enable_observability && !var.enable_app_asg ? 1 : 0
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
    InstanceId = aws_instance.app[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "app_status_check_failed" {
  count               = var.enable_observability && !var.enable_app_asg ? 1 : 0
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
    InstanceId = aws_instance.app[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "app_unreachable" {
  count               = var.enable_observability && !var.enable_app_asg ? 1 : 0
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
    InstanceId = aws_instance.app[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "app_disk_low_free" {
  count               = var.enable_observability && !var.enable_app_asg ? 1 : 0
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
    InstanceId = aws_instance.app[0].id
    objectname = "LogicalDisk"
    instance   = "C:"
  }
}


resource "aws_cloudwatch_metric_alarm" "app_asg_cpu_high" {
  count               = var.enable_observability && var.enable_app_asg ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-asg-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupAverageCPUUtilization"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "CPU média alta no ASG da APP"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app[0].name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_asg_inservice_low" {
  count               = var.enable_observability && var.enable_app_asg ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-asg-inservice-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = var.app_asg_min_size
  alarm_description   = "InServiceInstances abaixo do mínimo esperado no ASG da APP"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app[0].name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_tg_unhealthy_hosts" {
  count               = var.enable_observability && var.enable_app_asg && var.enable_lb ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-tg-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Target group da APP com hosts unhealthy"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    LoadBalancer = aws_lb.app_alb[0].arn_suffix
    TargetGroup  = aws_lb_target_group.app_tg[0].arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "app_tg_5xx_high" {
  count               = var.enable_observability && var.enable_app_asg && var.enable_lb ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-tg-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Target group da APP com aumento de erros 5XX"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  dimensions = {
    LoadBalancer = aws_lb.app_alb[0].arn_suffix
    TargetGroup  = aws_lb_target_group.app_tg[0].arn_suffix
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


# ==========================================================
# Recovery mode (daily snapshots + runbooks)
# ==========================================================
resource "aws_iam_role" "dlm" {
  count = var.enable_recovery_mode ? 1 : 0
  name  = "${var.name}-${var.environment}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "dlm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-dlm-role"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_iam_role_policy_attachment" "dlm" {
  count      = var.enable_recovery_mode ? 1 : 0
  role       = aws_iam_role.dlm[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "app_daily" {
  count              = var.enable_recovery_mode && var.recovery_backup_app ? 1 : 0
  description        = "Daily APP snapshots for ${var.name}-${var.environment}"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      App         = var.name
      Environment = var.environment
      BackupScope = "app"
    }

    schedules {
      name = "daily-app-snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.recovery_snapshot_time_utc]
      }

      retain_rule {
        count = var.recovery_retention_days
      }

      copy_tags = true
      tags_to_add = {
        ManagedBy   = "brainctl"
        App         = var.name
        Environment = var.environment
        BackupScope = "app"
      }
    }
  }

  tags = {
    Name        = "${var.name}-${var.environment}-dlm-app"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]
}

resource "aws_dlm_lifecycle_policy" "db_daily" {
  count              = var.enable_recovery_mode && var.recovery_backup_db && var.enable_db ? 1 : 0
  description        = "Daily DB snapshots for ${var.name}-${var.environment}"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      App         = var.name
      Environment = var.environment
      BackupScope = "db"
    }

    schedules {
      name = "daily-db-snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.recovery_snapshot_time_utc]
      }

      retain_rule {
        count = var.recovery_retention_days
      }

      copy_tags = true
      tags_to_add = {
        ManagedBy   = "brainctl"
        App         = var.name
        Environment = var.environment
        BackupScope = "db"
      }
    }
  }

  tags = {
    Name        = "${var.name}-${var.environment}-dlm-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]
}

resource "aws_ssm_document" "recovery_app_runbook" {
  count           = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_app ? 1 : 0
  name            = "${var.name}-${var.environment}-recovery-app"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Runbook APP recovery: encontra snapshot mais recente e cria volume EBS"
    assumeRole    = "{{AutomationAssumeRole}}"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        default     = ""
        description = "(Opcional) IAM role ARN para executar automação"
      }
      AvailabilityZone = {
        type        = "String"
        description = "Availability Zone para criação do volume (ex: us-east-1a)"
      }
      VolumeType = {
        type        = "String"
        default     = "gp3"
        description = "Tipo do volume EBS de recuperação"
      }
    }
    mainSteps = [
      {
        name   = "FindAppSnapshots"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "DescribeSnapshots"
          Filters = [
            { Name = "tag:App", Values = [var.name] },
            { Name = "tag:Environment", Values = [var.environment] },
            { Name = "tag:BackupScope", Values = ["app"] }
          ]
          OwnerIds = [data.aws_caller_identity.current.account_id]
        }
        outputs = [{ Name = "Snapshots", Selector = "$.Snapshots", Type = "MapList" }]
      },
      {
        name   = "SelectLatestAppSnapshot"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.11"
          Handler = "handler"
          Script  = "def handler(events, context):\n    snaps = events.get('Snapshots', [])\n    if not snaps:\n        raise Exception('No APP snapshots found')\n    snaps.sort(key=lambda x: x.get('StartTime', ''), reverse=True)\n    return {'SnapshotId': snaps[0]['SnapshotId']}"
          InputPayload = {
            Snapshots = "{{FindAppSnapshots.Snapshots}}"
          }
        }
        outputs = [{ Name = "SnapshotId", Selector = "$.Payload.SnapshotId", Type = "String" }]
      },
      {
        name   = "CreateAppRecoveryVolume"
        action = "aws:executeAwsApi"
        inputs = {
          Service          = "ec2"
          Api              = "CreateVolume"
          SnapshotId       = "{{SelectLatestAppSnapshot.SnapshotId}}"
          AvailabilityZone = "{{AvailabilityZone}}"
          VolumeType       = "{{VolumeType}}"
          TagSpecifications = [{
            ResourceType = "volume"
            Tags = [
              { Key = "Name", Value = "${var.name}-${var.environment}-app-recovery" },
              { Key = "ManagedBy", Value = "brainctl" },
              { Key = "App", Value = var.name },
              { Key = "Environment", Value = var.environment },
              { Key = "BackupScope", Value = "app" }
            ]
          }]
        }
        outputs = [{ Name = "VolumeId", Selector = "$.VolumeId", Type = "String" }]
      }
    ]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-recovery-app"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_ssm_document" "recovery_db_runbook" {
  count           = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_db && var.enable_db ? 1 : 0
  name            = "${var.name}-${var.environment}-recovery-db"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Runbook DB recovery: encontra snapshot mais recente e cria volume EBS"
    assumeRole    = "{{AutomationAssumeRole}}"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        default     = ""
        description = "(Opcional) IAM role ARN para executar automação"
      }
      AvailabilityZone = {
        type        = "String"
        description = "Availability Zone para criação do volume (ex: us-east-1a)"
      }
      VolumeType = {
        type        = "String"
        default     = "gp3"
        description = "Tipo do volume EBS de recuperação"
      }
    }
    mainSteps = [
      {
        name   = "FindDBSnapshots"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "DescribeSnapshots"
          Filters = [
            { Name = "tag:App", Values = [var.name] },
            { Name = "tag:Environment", Values = [var.environment] },
            { Name = "tag:BackupScope", Values = ["db"] }
          ]
          OwnerIds = [data.aws_caller_identity.current.account_id]
        }
        outputs = [{ Name = "Snapshots", Selector = "$.Snapshots", Type = "MapList" }]
      },
      {
        name   = "SelectLatestDBSnapshot"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.11"
          Handler = "handler"
          Script  = "def handler(events, context):\n    snaps = events.get('Snapshots', [])\n    if not snaps:\n        raise Exception('No DB snapshots found')\n    snaps.sort(key=lambda x: x.get('StartTime', ''), reverse=True)\n    return {'SnapshotId': snaps[0]['SnapshotId']}"
          InputPayload = {
            Snapshots = "{{FindDBSnapshots.Snapshots}}"
          }
        }
        outputs = [{ Name = "SnapshotId", Selector = "$.Payload.SnapshotId", Type = "String" }]
      },
      {
        name   = "CreateDBRecoveryVolume"
        action = "aws:executeAwsApi"
        inputs = {
          Service          = "ec2"
          Api              = "CreateVolume"
          SnapshotId       = "{{SelectLatestDBSnapshot.SnapshotId}}"
          AvailabilityZone = "{{AvailabilityZone}}"
          VolumeType       = "{{VolumeType}}"
          TagSpecifications = [{
            ResourceType = "volume"
            Tags = [
              { Key = "Name", Value = "${var.name}-${var.environment}-db-recovery" },
              { Key = "ManagedBy", Value = "brainctl" },
              { Key = "App", Value = var.name },
              { Key = "Environment", Value = var.environment },
              { Key = "BackupScope", Value = "db" }
            ]
          }]
        }
        outputs = [{ Name = "VolumeId", Selector = "$.VolumeId", Type = "String" }]
      }
    ]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-recovery-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}
