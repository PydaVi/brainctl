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

variable "imds_v2_required" {
  description = "Exige IMDSv2 (http_tokens=required) nas instâncias da aplicação"
  type        = bool
  default     = false
}

variable "app_extra_ingress_rules" {
  description = "Regras extras de ingress no SG da APP (via overrides)"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}


variable "app_ami_id" {
  description = "AMI custom para APP (opcional). Quando vazio, usa Windows Server 2022 padrão"
  type        = string
  default     = ""
}

variable "app_user_data_mode" {
  description = "Modo de user data da APP: default|custom|merge"
  type        = string
  default     = "default"

  validation {
    condition     = contains(["default", "custom", "merge"], var.app_user_data_mode)
    error_message = "app_user_data_mode must be one of: default, custom, merge"
  }
}

variable "app_user_data_base64" {
  description = "User data custom da APP em base64 (opcional)"
  type        = string
  default     = ""
}

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

variable "db_extra_ingress_rules" {
  description = "Regras extras de ingress no SG do DB (via overrides)"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}


variable "db_ami_id" {
  description = "AMI custom para DB (opcional). Quando vazio, usa Windows Server 2022 padrão"
  type        = string
  default     = ""
}

variable "db_user_data_mode" {
  description = "Modo de user data da DB: default|custom|merge"
  type        = string
  default     = "default"

  validation {
    condition     = contains(["default", "custom", "merge"], var.db_user_data_mode)
    error_message = "db_user_data_mode must be one of: default, custom, merge"
  }
}

variable "db_user_data_base64" {
  description = "User data custom da DB em base64 (opcional)"
  type        = string
  default     = ""
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

variable "alb_extra_ingress_rules" {
  description = "Regras extras de ingress no SG do ALB (via overrides)"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "lb_allowed_cidr" {
  description = "CIDR liberado para acessar o listener do ALB (somente para ALB público faz sentido abrir 0.0.0.0/0)"
  type        = string
  default     = "0.0.0.0/0"
}


# Auto Scaling da APP (Sprint de resiliência/escala)
variable "enable_app_asg" {
  description = "Habilita Auto Scaling Group para a camada de aplicação"
  type        = bool
  default     = false
}

variable "app_asg_subnet_ids" {
  description = "Subnets onde as instâncias da APP em ASG serão distribuídas"
  type        = list(string)
  default     = []
}

variable "app_asg_min_size" {
  description = "Quantidade mínima de instâncias no ASG"
  type        = number
  default     = 2
}

variable "app_asg_max_size" {
  description = "Quantidade máxima de instâncias no ASG"
  type        = number
  default     = 4
}

variable "app_asg_desired_capacity" {
  description = "Capacidade desejada inicial do ASG"
  type        = number
  default     = 2
}

variable "app_asg_cpu_target" {
  description = "Target de CPU para política de scaling da APP"
  type        = number
  default     = 60
}

# ----------------------------
# Observability (Sprint 1)
# ----------------------------
variable "enable_observability" {
  description = "Habilita recursos base de observabilidade (CloudWatch Agent, dashboards e alarmes)"
  type        = bool
  default     = true
}

variable "cpu_high_threshold" {
  description = "Threshold de CPU alta para alarmes"
  type        = number
  default     = 80
}

variable "alert_email" {
  description = "E-mail para inscrição no tópico SNS que recebe os alertas (opcional)"
  type        = string
  default     = ""
}

variable "enable_ssm_endpoints" {
  description = "Cria endpoints privados de SSM (ssm, ssmmessages, ec2messages) para VPC sem saída de internet"
  type        = bool
  default     = false
}

variable "enable_ssm_private_dns" {
  description = "Habilita private DNS nos endpoints de SSM (requer enableDnsSupport + enableDnsHostnames na VPC)"
  type        = bool
  default     = false
}


# ----------------------------
# Recovery (Snapshot + Runbooks)
# ----------------------------
variable "enable_recovery_mode" {
  description = "Habilita modo de recuperação com snapshots automáticos"
  type        = bool
  default     = false
}

variable "recovery_snapshot_time_utc" {
  description = "Horário diário UTC para snapshots (HH:MM)"
  type        = string
  default     = "03:00"
}

variable "recovery_retention_days" {
  description = "Dias de retenção dos snapshots diários"
  type        = number
  default     = 7
}

variable "recovery_backup_app" {
  description = "Habilita backup da camada APP"
  type        = bool
  default     = true
}

variable "recovery_backup_db" {
  description = "Habilita backup da camada DB"
  type        = bool
  default     = true
}

variable "recovery_enable_runbooks" {
  description = "Cria runbooks de automação SSM para recuperação"
  type        = bool
  default     = true
}
