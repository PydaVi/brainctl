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

variable "enable_db" {
  description = "Cria EC2 de banco (db)"
  type        = bool
  default     = true
}

variable "db_instance_type" {
  description = "Tipo da instância do banco"
  type        = string
  default     = "t3.micro"
}

variable "db_port" {
  description = "Porta do banco (ex: 1433 SQL Server)"
  type        = number
  default     = 1433
}
