output "app_dashboard_name" {
  value = var.enable_observability ? (var.enable_app_asg ? aws_cloudwatch_dashboard.app_asg[0].dashboard_name : aws_cloudwatch_dashboard.app[0].dashboard_name) : null
}

output "app_dashboard_url" {
  value = var.enable_observability ? (var.enable_app_asg ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.app_asg[0].dashboard_name}" : "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.app[0].dashboard_name}") : null
}

output "db_dashboard_name" {
  value = var.enable_observability && var.enable_db ? (var.db_mode == "rds" ? aws_cloudwatch_dashboard.db_rds[0].dashboard_name : aws_cloudwatch_dashboard.db_ec2[0].dashboard_name) : null
}

output "sre_dashboard_name" {
  value = var.enable_observability && var.enable_lb ? aws_cloudwatch_dashboard.sre[0].dashboard_name : null
}

output "executive_dashboard_name" {
  value = var.enable_observability && var.enable_lb ? aws_cloudwatch_dashboard.executive[0].dashboard_name : null
}

output "infra_dashboard_name" {
  value = var.enable_observability ? aws_cloudwatch_dashboard.infra[0].dashboard_name : null
}

output "slo_dashboard_name" {
  value = var.enable_observability && var.enable_lb ? aws_cloudwatch_dashboard.slo[0].dashboard_name : null
}

output "db_dashboard_url" {
  value = var.enable_observability && var.enable_db ? (var.db_mode == "rds" ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.db_rds[0].dashboard_name}" : "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.db_ec2[0].dashboard_name}") : null
}

output "sre_dashboard_url" {
  value = var.enable_observability && var.enable_lb ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.sre[0].dashboard_name}" : null
}

output "executive_dashboard_url" {
  value = var.enable_observability && var.enable_lb ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.executive[0].dashboard_name}" : null
}

output "infra_dashboard_url" {
  value = var.enable_observability ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.infra[0].dashboard_name}" : null
}

output "slo_dashboard_url" {
  value = var.enable_observability && var.enable_lb ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.slo[0].dashboard_name}" : null
}

output "alarm_names" {
  value = var.enable_observability ? compact([
    var.enable_lb ? aws_cloudwatch_metric_alarm.app_slo_availability_low[0].alarm_name : null,
    var.enable_app_asg ? aws_cloudwatch_metric_alarm.app_asg_cpu_high[0].alarm_name : aws_cloudwatch_metric_alarm.app_cpu_high[0].alarm_name,
    var.enable_app_asg ? aws_cloudwatch_metric_alarm.app_asg_inservice_low[0].alarm_name : aws_cloudwatch_metric_alarm.app_status_check_failed[0].alarm_name,
    var.enable_app_asg ? (var.enable_lb ? aws_cloudwatch_metric_alarm.app_tg_unhealthy_hosts[0].alarm_name : null) : aws_cloudwatch_metric_alarm.app_unreachable[0].alarm_name,
    var.enable_app_asg ? (var.enable_lb ? aws_cloudwatch_metric_alarm.app_tg_5xx_high[0].alarm_name : null) : aws_cloudwatch_metric_alarm.app_disk_low_free[0].alarm_name,
    var.enable_app_asg ? (var.enable_lb ? aws_cloudwatch_metric_alarm.app_alb_request_count_low[0].alarm_name : null) : null,
    var.enable_app_asg ? (var.enable_lb ? aws_cloudwatch_metric_alarm.app_tg_target_response_time_high[0].alarm_name : null) : null,
    var.enable_app_asg ? (var.enable_lb ? aws_cloudwatch_metric_alarm.app_tg_4xx_high[0].alarm_name : null) : null,
    var.enable_db && var.db_mode == "ec2" ? aws_cloudwatch_metric_alarm.db_ec2_cpu_high[0].alarm_name : null,
    var.enable_db && var.db_mode == "rds" ? aws_cloudwatch_metric_alarm.db_rds_cpu_high[0].alarm_name : null,
    var.enable_db && var.db_mode == "rds" ? aws_cloudwatch_metric_alarm.db_rds_free_storage_low[0].alarm_name : null,
    var.enable_db && var.db_mode == "rds" ? aws_cloudwatch_metric_alarm.db_rds_connections_high[0].alarm_name : null,
  ]) : []
}
