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

  dynamic "ingress" {
    for_each = var.db_extra_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
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
  ami           = local.resolved_db_ami
  instance_type = var.db_instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.db_sg[0].id]

  iam_instance_profile = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  user_data            = local.db_effective_user_data != "" ? local.db_effective_user_data : null

  volume_tags = {
    Name        = "${var.name}-${var.environment}-db-root"
    Environment = var.environment
    ManagedBy   = "brainctl"
    App         = var.name
    BackupScope = "db"
  }

  tags = {
    Name        = "${var.name}-${var.environment}-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
    Role        = "db"
  }
}
