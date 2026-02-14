variable "enable_observability" {
  type = bool
}

variable "enable_app_asg" {
  type = bool
}

variable "enable_db" {
  type = bool
}

variable "enable_lb" {
  type = bool
}

variable "db_mode" {
  type = string
}

variable "db_rds_identifier" {
  type    = string
  default = null
}

variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "cpu_high_threshold" {
  type = number
}

variable "app_asg_min_size" {
  type = number
}

variable "app_instance_id" {
  type    = string
  default = null
}

variable "app_asg_name" {
  type    = string
  default = null
}

variable "db_instance_id" {
  type    = string
  default = null
}

variable "alb_arn_suffix" {
  type    = string
  default = null
}

variable "tg_arn_suffix" {
  type    = string
  default = null
}

variable "alarm_actions" {
  type    = list(string)
  default = []
}
