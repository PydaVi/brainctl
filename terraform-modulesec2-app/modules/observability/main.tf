resource "aws_cloudwatch_dashboard" "app" {
  count          = var.enable_observability && !var.enable_app_asg ? 1 : 0
  dashboard_name = "brainctl-${var.name}-${var.environment}-app"

  dashboard_body = jsonencode({
    widgets = concat(
      [
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
            title   = "APP Memory % RAM Used"
            view    = "timeSeries"
            region  = var.region
            stat    = "Average"
            period  = 60
            metrics = [
              [var.cw_agent_namespace, "mem_available_mb", "InstanceId", var.app_instance_id, { id = "mAvail", visible = false }],
              [".", "mem_commit_limit_bytes", ".", ".", { id = "mCommit", visible = false }],
              [{ expression = "mCommit / 1024 / 1024", label = "TotalMB", id = "eTotal", visible = false }],
              [{ expression = "100 - ((mAvail / eTotal) * 100)", label = "APP Memory % RAM Used", id = "eRamUsed" }]
            ]
            yAxis = {
              left = {
                min = 0
                max = 100
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 6
          properties = {
            title   = "APP LogicalDisk % Free"
            view    = "timeSeries"
            region  = var.region
            stat    = "Average"
            period  = 60
            metrics = [[var.cw_agent_namespace, "LogicalDisk % Free Space", "InstanceId", var.app_instance_id, "objectname", "LogicalDisk", "instance", "C:"]]
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "APP Network In/Out"
            view    = "timeSeries"
            region  = var.region
            stat    = "Average"
            period  = 60
            metrics = [
              ["AWS/EC2", "NetworkIn", "InstanceId", var.app_instance_id],
              ["AWS/EC2", "NetworkOut", "InstanceId", var.app_instance_id]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "APP TCP Connections Established"
            view    = "timeSeries"
            region  = var.region
            stat    = "Average"
            period  = 60
            metrics = [[var.cw_agent_namespace, "tcp_connections_established", "InstanceId", var.app_instance_id, "objectname", "TCPv4"]]
          }
        }
      ],
      var.enable_lb ? [
        {
          type   = "metric"
          x      = 0
          y      = 18
          width  = 12
          height = 6
          properties = {
            title   = "ALB RequestCount"
            view    = "timeSeries"
            region  = var.region
            stat    = "Sum"
            period  = 60
            metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 18
          width  = 12
          height = 6
          properties = {
            title   = "APP TG TargetResponseTime"
            view    = "timeSeries"
            region  = var.region
            stat    = "Average"
            period  = 60
            metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]]
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 24
          width  = 12
          height = 6
          properties = {
            title   = "APP TG 4XX/5XX"
            view    = "timeSeries"
            region  = var.region
            stat    = "Sum"
            period  = 60
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 24
          width  = 12
          height = 6
          properties = {
            title   = "APP TG Healthy vs Unhealthy"
            view    = "timeSeries"
            region  = var.region
            stat    = "Maximum"
            period  = 60
            metrics = [
              ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix],
              ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]
            ]
          }
        }
      ] : []
    )
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
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "ALB RequestCount"
          view    = "timeSeries"
          region  = var.region
          stat    = "Sum"
          period  = 60
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "APP TG TargetResponseTime"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title   = "APP TG 4XX"
          view    = "timeSeries"
          region  = var.region
          stat    = "Sum"
          period  = 60
          metrics = [["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title   = "APP TG HealthyHostCount"
          view    = "timeSeries"
          region  = var.region
          stat    = "Maximum"
          period  = 60
          metrics = [["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_arn_suffix]]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "db_ec2" {
  count          = var.enable_observability && var.enable_db && var.db_mode == "ec2" ? 1 : 0
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
          title   = "DB Memory Available (MB)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [[var.cw_agent_namespace, "mem_available_mb", "InstanceId", var.db_instance_id]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "DB Disk Free % (CloudWatch Agent)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [[var.cw_agent_namespace, "LogicalDisk % Free Space", "InstanceId", var.db_instance_id, "objectname", "LogicalDisk", "instance", "C:"]]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "db_rds" {
  count          = var.enable_observability && var.enable_db && var.db_mode == "rds" ? 1 : 0
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
          title   = "RDS CPUUtilization"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_rds_identifier]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS DatabaseConnections"
          view    = "timeSeries"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_rds_identifier]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "RDS FreeStorageSpace (bytes)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Minimum"
          period  = 60
          metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_rds_identifier]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "RDS FreeableMemory (bytes)"
          view    = "timeSeries"
          region  = var.region
          stat    = "Minimum"
          period  = 60
          metrics = [["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.db_rds_identifier]]
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
  namespace           = var.cw_agent_namespace
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


resource "aws_cloudwatch_metric_alarm" "app_alb_request_count_low" {
  count               = var.enable_observability && var.enable_app_asg && var.enable_lb ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-alb-request-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "ALB com baixo volume de tráfego para APP"
  treat_missing_data  = "breaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "app_tg_target_response_time_high" {
  count               = var.enable_observability && var.enable_app_asg && var.enable_lb ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-tg-target-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2
  alarm_description   = "Target group da APP com latência elevada"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "app_tg_4xx_high" {
  count               = var.enable_observability && var.enable_app_asg && var.enable_lb ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-app-tg-4xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 20
  alarm_description   = "Target group da APP com aumento de erros 4XX"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "db_ec2_cpu_high" {
  count               = var.enable_observability && var.enable_db && var.db_mode == "ec2" ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "CPU alta na instância DB (EC2)"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    InstanceId = var.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "db_rds_cpu_high" {
  count               = var.enable_observability && var.enable_db && var.db_mode == "rds" ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-db-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "CPU alta na instância RDS"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    DBInstanceIdentifier = var.db_rds_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "db_rds_free_storage_low" {
  count               = var.enable_observability && var.enable_db && var.db_mode == "rds" ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-db-rds-free-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Minimum"
  threshold           = 2147483648
  alarm_description   = "Espaço livre baixo no RDS (< 2GB)"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    DBInstanceIdentifier = var.db_rds_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "db_rds_connections_high" {
  count               = var.enable_observability && var.enable_db && var.db_mode == "rds" ? 1 : 0
  alarm_name          = "brainctl-${var.name}-${var.environment}-db-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Conexões altas no RDS"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  dimensions = {
    DBInstanceIdentifier = var.db_rds_identifier
  }
}
