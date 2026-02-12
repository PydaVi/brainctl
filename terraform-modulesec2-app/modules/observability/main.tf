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
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", var.app_instance_id]]
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
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", var.app_instance_id]]
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
          metrics = [["CWAgent", "Memory % Committed Bytes In Use", "InstanceId", var.app_instance_id, "objectname", "Memory"]]
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
          metrics = [["CWAgent", "LogicalDisk % Free Space", "InstanceId", var.app_instance_id, "objectname", "LogicalDisk", "instance", "C:"]]
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
          metrics = [["AWS/AutoScaling", "GroupAverageCPUUtilization", "AutoScalingGroupName", var.app_asg_name]]
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
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.app_asg_name],
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", var.app_asg_name]
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
          metrics = [["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]]
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
          metrics = [["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]]
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
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", var.db_instance_id]]
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
          metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", var.db_instance_id]]
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
          metrics = [["CWAgent", "Memory % Committed Bytes In Use", "InstanceId", var.db_instance_id, "objectname", "Memory"]]
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
          metrics = [["CWAgent", "LogicalDisk % Free Space", "InstanceId", var.db_instance_id, "objectname", "LogicalDisk", "instance", "C:"]]
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    InstanceId = var.app_instance_id
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    InstanceId = var.app_instance_id
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    InstanceId = var.app_instance_id
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    InstanceId = var.app_instance_id
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    AutoScalingGroupName = var.app_asg_name
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    AutoScalingGroupName = var.app_asg_name
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
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
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    InstanceId = var.db_instance_id
  }
}
