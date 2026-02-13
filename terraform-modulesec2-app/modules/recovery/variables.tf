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

variable "recovery_drill_enabled" {
  type = bool
}

variable "recovery_drill_schedule_expression" {
  type = string
}

variable "recovery_drill_register_to_target_group" {
  type = bool
}

variable "app_recovery_subnet_id" {
  type = string
}

variable "app_recovery_security_group_id" {
  type = string
}

variable "app_recovery_ami_id" {
  type = string
}

variable "app_recovery_instance_type" {
  type = string
}

variable "app_recovery_instance_profile_name" {
  type    = string
  default = ""
}

variable "app_recovery_target_group_arn" {
  type    = string
  default = ""
}
