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

  dynamic "ingress" {
    for_each = var.app_extra_ingress_rules
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
    Name        = "${var.name}-${var.environment}-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_instance" "app" {
  count         = var.enable_app_asg ? 0 : var.app_instance_count
  ami           = local.resolved_app_ami
  instance_type = var.instance_type
  subnet_id     = var.enable_app_asg ? null : local.app_instance_subnet_ids[count.index % length(local.app_instance_subnet_ids)]

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = var.imds_v2_required ? "required" : "optional"
  }

  iam_instance_profile = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  user_data            = local.app_effective_user_data != "" ? local.app_effective_user_data : null

  volume_tags = {
    Name        = "${var.name}-${var.environment}-app-root"
    Environment = var.environment
    ManagedBy   = "brainctl"
    App         = var.name
    BackupScope = "app"
  }

  tags = {
    Name        = "${var.name}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "brainctl"
    Role        = "app"
  }
}
