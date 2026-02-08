variable "name" {
  description = "Nome da aplicação"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, hml, prod)"
  type        = string
}

variable "region" {
  description = "Região AWS"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância"
  type        = string
}

variable "vpc_id" {
  description = "VPC onde a instância será criada"
  type        = string
}

variable "subnet_id" {
  description = "Subnet da instância"
  type        = string
}

variable "allowed_rdp_cidr" {
  description = "CIDR permitido para RDP"
  type        = string
  default     = "0.0.0.0/0"
}
