output "recovery_app_policy_id" {
  value = var.enable_recovery_mode && var.recovery_backup_app ? aws_dlm_lifecycle_policy.app_daily[0].id : null
}

output "recovery_db_policy_id" {
  value = var.enable_recovery_mode && var.recovery_backup_db && var.enable_db ? aws_dlm_lifecycle_policy.db_daily[0].id : null
}

output "recovery_app_runbook_name" {
  value = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_app ? aws_ssm_document.recovery_app_runbook[0].name : null
}

output "recovery_db_runbook_name" {
  value = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_db && var.enable_db ? aws_ssm_document.recovery_db_runbook[0].name : null
}
