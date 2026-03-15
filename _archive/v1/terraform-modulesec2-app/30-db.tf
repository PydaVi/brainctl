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
  count         = var.enable_db && var.db_mode == "ec2" ? 1 : 0
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

resource "aws_db_subnet_group" "db" {
  count      = var.enable_db && var.db_mode == "rds" ? 1 : 0
  name       = "${var.name}-${var.environment}-db-subnet-group"
  subnet_ids = local.db_subnet_group_subnet_ids

  tags = {
    Name        = "${var.name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_db_instance" "db" {
  count                     = var.enable_db && var.db_mode == "rds" ? 1 : 0
  identifier                = "${var.name}-${var.environment}-db"
  engine                    = var.db_rds_engine
  engine_version            = var.db_rds_engine_version
  instance_class            = var.db_rds_instance_class
  allocated_storage         = var.db_rds_allocated_storage
  storage_type              = var.db_rds_storage_type
  db_name                   = var.db_rds_db_name
  username                  = var.db_rds_username
  password                  = var.db_rds_password
  port                      = var.db_port
  db_subnet_group_name      = aws_db_subnet_group.db[0].name
  vpc_security_group_ids    = [aws_security_group.db_sg[0].id]
  backup_retention_period   = var.db_rds_backup_retention_days
  multi_az                  = var.db_rds_multi_az
  publicly_accessible       = var.db_rds_publicly_accessible
  skip_final_snapshot       = true
  deletion_protection       = false
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.name}-${var.environment}-db-rds"
    Environment = var.environment
    ManagedBy   = "brainctl"
    Role        = "db"
  }
}
