# ==========================================================
# APP EC2 / ASG
# ==========================================================

output "instance_id" {
  description = "ID da instância EC2 da aplicação (quando ASG estiver desabilitado)"
  value       = var.enable_app_asg ? null : aws_instance.app[0].id
}

output "private_ip" {
  description = "Private IP da instância EC2 da aplicação (quando ASG estiver desabilitado)"
  value       = var.enable_app_asg ? null : aws_instance.app[0].private_ip
}

output "public_ip" {
  description = "Public IP da instância EC2 da aplicação (quando ASG estiver desabilitado)"
  value       = var.enable_app_asg ? null : aws_instance.app[0].public_ip
}
output "app_instance_ids" {
  description = "IDs das instâncias EC2 da aplicação quando ASG estiver desabilitado"
  value       = var.enable_app_asg ? [] : aws_instance.app[*].id
}

output "app_private_ips" {
  description = "Private IPs das instâncias EC2 da aplicação quando ASG estiver desabilitado"
  value       = var.enable_app_asg ? [] : aws_instance.app[*].private_ip
}


output "app_asg_name" {
  description = "Nome do Auto Scaling Group da aplicação"
  value       = var.enable_app_asg ? aws_autoscaling_group.app[0].name : null
}

output "app_asg_min_size" {
  description = "Min size do ASG da aplicação"
  value       = var.enable_app_asg ? aws_autoscaling_group.app[0].min_size : null
}

output "app_asg_max_size" {
  description = "Max size do ASG da aplicação"
  value       = var.enable_app_asg ? aws_autoscaling_group.app[0].max_size : null
}

output "app_asg_desired_capacity" {
  description = "Desired capacity do ASG da aplicação"
  value       = var.enable_app_asg ? aws_autoscaling_group.app[0].desired_capacity : null
}

output "security_group_id" {
  description = "ID do Security Group da aplicação"
  value       = aws_security_group.app_sg.id
}

output "security_group_name" {
  description = "Nome do Security Group da aplicação"
  value       = aws_security_group.app_sg.name
}

# ==========================================================
# DB EC2 (Opcional)
# ==========================================================

output "db_instance_id" {
  description = "ID da instância EC2 do banco"
  value       = var.enable_db && var.db_mode == "ec2" ? aws_instance.db[0].id : null
}

output "db_private_ip" {
  description = "Private IP da instância EC2 do banco"
  value       = var.enable_db && var.db_mode == "ec2" ? aws_instance.db[0].private_ip : null
}

output "db_security_group_id" {
  description = "ID do Security Group do banco"
  value       = var.enable_db ? aws_security_group.db_sg[0].id : null
}

output "db_security_group_name" {
  description = "Nome do Security Group do banco"
  value       = var.enable_db ? aws_security_group.db_sg[0].name : null
}
output "db_rds_instance_id" {
  description = "ID da instância RDS do banco"
  value       = var.enable_db && var.db_mode == "rds" ? aws_db_instance.db[0].id : null
}

output "db_rds_endpoint" {
  description = "Endpoint da instância RDS"
  value       = var.enable_db && var.db_mode == "rds" ? aws_db_instance.db[0].address : null
}

output "db_rds_port" {
  description = "Porta do endpoint RDS"
  value       = var.enable_db && var.db_mode == "rds" ? aws_db_instance.db[0].port : null
}


# ==========================================================
# ALB (Opcional)
# ==========================================================

output "alb_dns_name" {
  description = "DNS público/privado do Application Load Balancer"
  value       = var.enable_lb ? aws_lb.app_alb[0].dns_name : null
}

output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = var.enable_lb ? aws_lb.app_alb[0].arn : null
}

output "alb_security_group_id" {
  description = "Security Group do ALB"
  value       = var.enable_lb ? aws_security_group.alb_sg[0].id : null
}

output "alb_target_group_arn" {
  description = "ARN do Target Group do ALB"
  value       = var.enable_lb ? aws_lb_target_group.app_tg[0].arn : null
}

# ==========================================================
# Observability (Opcional)
# ==========================================================

output "observability_app_dashboard_name" {
  description = "Nome do dashboard de observabilidade da APP"
  value       = module.observability.app_dashboard_name
}

output "observability_app_dashboard_url" {
  description = "URL do dashboard de observabilidade da APP"
  value       = module.observability.app_dashboard_url
}

output "observability_db_dashboard_name" {
  description = "Nome do dashboard de observabilidade do DB"
  value       = module.observability.db_dashboard_name
}

output "observability_db_dashboard_url" {
  description = "URL do dashboard de observabilidade do DB"
  value       = module.observability.db_dashboard_url
}

output "observability_sre_dashboard_name" {
  description = "Nome do dashboard SRE"
  value       = module.observability.sre_dashboard_name
}

output "observability_sre_dashboard_url" {
  description = "URL do dashboard SRE"
  value       = module.observability.sre_dashboard_url
}

output "observability_slo_dashboard_name" {
  description = "Nome do dashboard SLO"
  value       = module.observability.slo_dashboard_name
}

output "observability_slo_dashboard_url" {
  description = "URL do dashboard SLO"
  value       = module.observability.slo_dashboard_url
}

output "observability_alarm_names" {
  description = "Lista com nomes dos alarmes criados"
  value       = module.observability.alarm_names
}

output "observability_sns_topic_arn" {
  description = "ARN do tópico SNS de alertas (quando email for informado)"
  value       = var.enable_observability && var.alert_email != "" ? aws_sns_topic.alerts[0].arn : null
}

output "observability_alert_email" {
  description = "E-mail configurado para receber alertas"
  value       = var.enable_observability && var.alert_email != "" ? var.alert_email : null
}

output "observability_log_group_name" {
  description = "CloudWatch Log Group coletando logs das instâncias"
  value       = var.enable_observability ? aws_cloudwatch_log_group.brainctl[0].name : null
}

output "observability_ssm_profile_name" {
  description = "Instance Profile com permissões de CloudWatch Agent + SSM"
  value       = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
}


# ==========================================================
# Recovery mode (Opcional)
# ==========================================================

output "recovery_enabled" {
  description = "Indica se modo de recuperação está habilitado"
  value       = var.enable_recovery_mode
}

output "recovery_snapshot_time_utc" {
  description = "Horário diário UTC configurado para snapshots"
  value       = var.enable_recovery_mode ? var.recovery_snapshot_time_utc : null
}

output "recovery_retention_days" {
  description = "Retenção (dias) dos snapshots"
  value       = var.enable_recovery_mode ? var.recovery_retention_days : null
}

output "recovery_app_policy_id" {
  description = "ID da política DLM de snapshots da APP"
  value       = var.enable_recovery_mode && var.recovery_backup_app ? module.recovery.recovery_app_policy_id : null
}

output "recovery_db_policy_id" {
  description = "ID da política DLM de snapshots da DB"
  value       = var.enable_recovery_mode && var.recovery_backup_db && var.enable_db && var.db_mode == "ec2" ? module.recovery.recovery_db_policy_id : null
}

output "recovery_app_runbook_name" {
  description = "Nome do runbook de recuperação da APP"
  value       = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_app ? module.recovery.recovery_app_runbook_name : null
}

output "recovery_db_runbook_name" {
  description = "Nome do runbook de recuperação da DB"
  value       = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_db && var.enable_db && var.db_mode == "ec2" ? module.recovery.recovery_db_runbook_name : null
}

output "recovery_drill_schedule_name" {
  description = "Nome do schedule mensal de DR drill"
  value       = var.enable_recovery_mode && var.recovery_drill_enabled ? module.recovery.recovery_drill_schedule_name : null
}
