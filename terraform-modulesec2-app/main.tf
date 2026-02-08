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
  }
}

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
