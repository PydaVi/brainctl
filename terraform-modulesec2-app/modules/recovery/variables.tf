variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_db" {
  type = bool
}

variable "enable_recovery_mode" {
  type = bool
}

variable "recovery_snapshot_time_utc" {
  type = string
}

variable "recovery_retention_days" {
  type = number
}

variable "recovery_backup_app" {
  type = bool
}

variable "recovery_backup_db" {
  type = bool
}

variable "recovery_enable_runbooks" {
  type = bool
}
