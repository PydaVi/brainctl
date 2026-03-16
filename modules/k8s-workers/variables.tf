variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string

  validation {
    condition     = trimspace(var.vpc_cidr) != "" && var.vpc_cidr != "0.0.0.0/0"
    error_message = "vpc_cidr must be set and cannot be 0.0.0.0/0"
  }
}

variable "subnet_id" {
  type = string
}

variable "control_plane_ami" {
  type    = string
  default = ""
}

variable "worker_ami" {
  type    = string
  default = ""
}

variable "control_plane_type" {
  type = string
}

variable "worker_type" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "kubernetes_version" {
  type = string
}

variable "pod_cidr" {
  type = string
}

variable "key_name" {
  type    = string
  default = ""
}

variable "admin_cidr" {
  type    = string
  default = ""

  validation {
    condition     = trimspace(var.admin_cidr) == "" || var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr cannot be 0.0.0.0/0"
  }
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "public_subnet_id" {
  type    = string
  default = ""
}

variable "public_subnet_cidr" {
  type    = string
  default = ""
}

variable "internet_gateway_id" {
  type    = string
  default = ""
}

variable "private_route_table_id" {
  type    = string
  default = ""
}

variable "enable_ssm" {
  type    = bool
  default = true
}

variable "enable_detailed_monitoring" {
  type    = bool
  default = false
}

variable "endpoint_subnet_ids" {
  type    = list(string)
  default = []
}

variable "allowed_egress_cidrs" {
  type    = list(string)
  default = []

  validation {
    condition     = alltrue([for cidr in var.allowed_egress_cidrs : cidr != "0.0.0.0/0"])
    error_message = "allowed_egress_cidrs cannot include 0.0.0.0/0"
  }
}

variable "enable_ssm_vpc_endpoints" {
  type    = bool
  default = true
}
