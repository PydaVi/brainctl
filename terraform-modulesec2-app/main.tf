provider "aws" {
  region = var.region
}

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

# ----------------------------
# Locals (sempre top-level)
# ----------------------------
locals {
  alb_internal = var.lb_scheme == "private" ? true : false
}

# ----------------------------
# Security Group - APP
# ----------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.name}-${var.environment}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_rdp_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-${var.environment}-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

# ----------------------------
# EC2 - APP
# ----------------------------
resource "aws_instance" "app" {
  ami           = data.aws_ami.windows_2022.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  tags = {
    Name        = "${var.name}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "brainctl"
    Role        = "app"
  }
}

# ----------------------------
# Security Group - DB (opcional)
# ----------------------------
resource "aws_security_group" "db_sg" {
  count       = var.enable_db ? 1 : 0
  name        = "${var.name}-${var.environment}-db-sg"
  description = "DB security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB from app SG"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-${var.environment}-db-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

# ----------------------------
# EC2 - DB (opcional)
# ----------------------------
resource "aws_instance" "db" {
  count         = var.enable_db ? 1 : 0
  ami           = data.aws_ami.windows_2022.id
  instance_type = var.db_instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [
    aws_security_group.db_sg[0].id
  ]

  tags = {
    Name        = "${var.name}-${var.environment}-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
    Role        = "db"
  }
}

# ==========================================================
# ALB (opcional)
# ==========================================================

# SG do ALB
resource "aws_security_group" "alb_sg" {
  count       = var.enable_lb ? 1 : 0
  name        = "${var.name}-${var.environment}-alb-sg"
  description = "ALB SG for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Listener"
    from_port   = var.lb_listener_port
    to_port     = var.lb_listener_port
    protocol    = "tcp"
    cidr_blocks = [var.lb_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-${var.environment}-alb-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

# Libera tráfego do ALB -> APP na porta da aplicação
resource "aws_security_group_rule" "app_from_alb" {
  count                    = var.enable_lb ? 1 : 0
  type                     = "ingress"
  security_group_id        = aws_security_group.app_sg.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg[0].id
  description              = "App port from ALB"
}

resource "aws_lb" "app_alb" {
  count              = var.enable_lb ? 1 : 0
  name               = substr("${var.name}-${var.environment}-alb", 0, 32)
  internal           = local.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg[0].id]
  subnets            = var.lb_subnet_ids

  tags = {
    Name        = "${var.name}-${var.environment}-alb"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_lb_target_group" "app_tg" {
  count    = var.enable_lb ? 1 : 0
  name     = substr("${var.name}-${var.environment}-tg", 0, 32)
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.name}-${var.environment}-tg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_lb_listener" "http" {
  count             = var.enable_lb ? 1 : 0
  load_balancer_arn = aws_lb.app_alb[0].arn
  port              = var.lb_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg[0].arn
  }
}

resource "aws_lb_target_group_attachment" "app_attach" {
  count            = var.enable_lb ? 1 : 0
  target_group_arn = aws_lb_target_group.app_tg[0].arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}
