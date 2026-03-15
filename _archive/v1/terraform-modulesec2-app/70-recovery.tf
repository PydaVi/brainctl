# ==========================================================
# Recovery mode (daily snapshots + runbooks + DR drill)
# ==========================================================
module "recovery" {
  source = "./modules/recovery"

  name                     = var.name
  environment              = var.environment
  enable_db                = var.enable_db && var.db_mode == "ec2"
  enable_recovery_mode     = var.enable_recovery_mode
  recovery_snapshot_time_utc = var.recovery_snapshot_time_utc
  recovery_retention_days  = var.recovery_retention_days
  recovery_backup_app      = var.recovery_backup_app
  recovery_backup_db       = var.recovery_backup_db
  recovery_enable_runbooks = var.recovery_enable_runbooks

  recovery_drill_enabled                  = var.recovery_drill_enabled
  recovery_drill_schedule_expression      = var.recovery_drill_schedule_expression
  recovery_drill_register_to_target_group = var.recovery_drill_register_to_target_group

  app_recovery_subnet_id             = var.subnet_id
  app_recovery_security_group_id     = aws_security_group.app_sg.id
  app_recovery_ami_id                = local.resolved_app_ami
  app_recovery_instance_type         = var.instance_type
  app_recovery_instance_profile_name = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : ""
  app_recovery_target_group_arn      = var.enable_lb ? aws_lb_target_group.app_tg[0].arn : ""

  db_recovery_subnet_id             = var.subnet_id
  db_recovery_security_group_id     = var.enable_db && var.db_mode == "ec2" ? aws_security_group.db_sg[0].id : ""
  db_recovery_ami_id                = local.resolved_db_ami
  db_recovery_instance_type         = var.db_instance_type
  db_recovery_instance_profile_name = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : ""
}
