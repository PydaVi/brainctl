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

variable "enable_ssm_vpc_endpoints" {
  type    = bool
  default = true
}
