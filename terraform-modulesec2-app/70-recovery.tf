# ==========================================================
# Recovery mode (daily snapshots + runbooks)
# ==========================================================
module "recovery" {
  source = "./modules/recovery"

  name                    = var.name
  environment             = var.environment
  enable_db               = var.enable_db
  enable_recovery_mode    = var.enable_recovery_mode
  recovery_snapshot_time_utc = var.recovery_snapshot_time_utc
  recovery_retention_days = var.recovery_retention_days
  recovery_backup_app     = var.recovery_backup_app
  recovery_backup_db      = var.recovery_backup_db
  recovery_enable_runbooks = var.recovery_enable_runbooks
}
