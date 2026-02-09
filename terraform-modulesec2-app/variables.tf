# ----------------------------
# Core app identification
# ----------------------------
variable "name" {
  description = "Nome da aplicação (usado em tags e naming)"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, hml, prod)"
  type        = string
}

variable "region" {
  description = "Região AWS (ex: us-east-1)"
  type        = string
}

# ----------------------------
# Networking
# ----------------------------
variable "vpc_id" {
  description = "VPC onde os recursos serão criados"
  type        = string
}

variable "subnet_id" {
  description = "Subnet da EC2 da aplicação (e DB, se habilitado)"
  type        = string
}

variable "allowed_rdp_cidr" {
  description = "CIDR permitido para RDP nas EC2 (apenas no SG da APP por enquanto)"
  type        = string
  default     = "0.0.0.0/0"
}

# ----------------------------
# Compute - APP
# ----------------------------
variable "instance_type" {
  description = "Tipo da instância da aplicação (ex: t3.micro)"
  type        = string
}

# ----------------------------
# Compute - DB (opcional)
# ----------------------------
variable "enable_db" {
  description = "Habilita a criação da EC2 de banco (db) + SG de banco"
  type        = bool
  default     = true
}

variable "db_instance_type" {
  description = "Tipo da instância do banco (ex: t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "db_port" {
  description = "Porta do banco permitida do SG da APP para o SG do DB (ex: 1433 SQL Server)"
  type        = number
  default     = 1433
}

# ----------------------------
# Load Balancer - ALB (opcional)
# ----------------------------
variable "enable_lb" {
  description = "Habilita a criação do ALB + Target Group + Listener + SG"
  type        = bool
  default     = false
}

variable "lb_scheme" {
  description = "Define se o ALB será privado ou público. Valores: private|public"
  type        = string
  default     = "private"
}

variable "lb_subnet_ids" {
  description = "Lista de subnets onde o ALB será criado (normalmente 2+ subnets em AZs diferentes)"
  type        = list(string)
  default     = []
}

variable "lb_listener_port" {
  description = "Porta do listener do ALB (HTTP). Ex: 80"
  type        = number
  default     = 80
}

variable "app_port" {
  description = "Porta da aplicação no target group (porta do tráfego ALB -> EC2 APP)"
  type        = number
  default     = 80
}

variable "lb_allowed_cidr" {
  description = "CIDR liberado para acessar o listener do ALB (somente para ALB público faz sentido abrir 0.0.0.0/0)"
  type        = string
  default     = "0.0.0.0/0"
}
