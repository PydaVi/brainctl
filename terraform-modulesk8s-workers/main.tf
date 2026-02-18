terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  cluster_name      = "${var.name}-${var.environment}"
  control_plane_ami = var.control_plane_ami != "" ? var.control_plane_ami : data.aws_ami.ubuntu.id
  worker_ami        = var.worker_ami != "" ? var.worker_ami : data.aws_ami.ubuntu.id
  ssh_enabled       = trimspace(var.admin_cidr) != ""
}

resource "aws_security_group" "cluster" {
  name        = "${local.cluster_name}-k8s-sg"
  description = "Security group do cluster kubeadm"
  vpc_id      = var.vpc_id

  ingress {
    description = "node-to-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "kube-apiserver"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
  }

  dynamic "ingress" {
    for_each = local.ssh_enabled ? [1] : []
    content {
      description = "ssh admin"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.admin_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-k8s-sg"
  }
}

resource "aws_iam_role" "instance" {
  name = "${local.cluster_name}-k8s-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.cluster_name}-k8s-profile"
  role = aws_iam_role.instance.name
}

resource "aws_instance" "control_plane" {
  ami                    = local.control_plane_ami
  instance_type          = var.control_plane_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name
  key_name               = trimspace(var.key_name) == "" ? null : var.key_name
  monitoring             = var.enable_detailed_monitoring

  user_data = templatefile("${path.module}/templates/control-plane.sh.tftpl", {
    kubernetes_version = var.kubernetes_version
    pod_cidr           = var.pod_cidr
  })

  tags = {
    Name = "${local.cluster_name}-cp"
    Role = "control-plane"
  }
}

resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = local.worker_ami
  instance_type          = var.worker_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name
  key_name               = trimspace(var.key_name) == "" ? null : var.key_name
  monitoring             = var.enable_detailed_monitoring

  user_data = templatefile("${path.module}/templates/worker.sh.tftpl", {
    kubernetes_version         = var.kubernetes_version
    control_plane_private_ip   = aws_instance.control_plane.private_ip
  })

  depends_on = [aws_instance.control_plane]

  tags = {
    Name = "${local.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }
}
