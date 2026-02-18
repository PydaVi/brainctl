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

data "aws_subnet" "private" {
  id = var.subnet_id
}

data "aws_route_table" "private" {
  subnet_id = var.subnet_id
}

data "aws_internet_gateway" "selected" {
  count = local.create_nat_gateway && trimspace(var.internet_gateway_id) == "" ? 1 : 0

  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

locals {
  cluster_name           = "${var.name}-${var.environment}"
  control_plane_ami      = var.control_plane_ami != "" ? var.control_plane_ami : data.aws_ami.ubuntu.id
  worker_ami             = var.worker_ami != "" ? var.worker_ami : data.aws_ami.ubuntu.id
  ssh_enabled            = trimspace(var.admin_cidr) != ""
  endpoint_subnet_ids    = length(var.endpoint_subnet_ids) > 0 ? var.endpoint_subnet_ids : [var.subnet_id]
  create_ssm_endpoints   = var.enable_ssm && var.enable_ssm_vpc_endpoints
  create_nat_gateway     = var.enable_nat_gateway
  nat_public_subnet_cidr = trimspace(var.public_subnet_cidr) != "" ? var.public_subnet_cidr : "10.0.254.0/24"
}

resource "aws_subnet" "nat_public" {
  count = local.create_nat_gateway && trimspace(var.public_subnet_id) == "" ? 1 : 0

  vpc_id                  = var.vpc_id
  cidr_block              = local.nat_public_subnet_cidr
  availability_zone       = data.aws_subnet.private.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.cluster_name}-nat-public"
  }
}

resource "aws_route_table" "nat_public" {
  count  = local.create_nat_gateway ? 1 : 0
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = trimspace(var.internet_gateway_id) != "" ? var.internet_gateway_id : data.aws_internet_gateway.selected[0].id
  }

  tags = {
    Name = "${local.cluster_name}-nat-public-rt"
  }
}

resource "aws_route_table_association" "nat_public" {
  count = local.create_nat_gateway ? 1 : 0

  subnet_id      = trimspace(var.public_subnet_id) != "" ? var.public_subnet_id : aws_subnet.nat_public[0].id
  route_table_id = aws_route_table.nat_public[0].id
}

resource "aws_eip" "nat" {
  count  = local.create_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${local.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "cluster" {
  count = local.create_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = trimspace(var.public_subnet_id) != "" ? var.public_subnet_id : aws_subnet.nat_public[0].id

  tags = {
    Name = "${local.cluster_name}-nat-gateway"
  }

  depends_on = [aws_route_table_association.nat_public]
}

resource "aws_route" "private_internet_via_nat" {
  count = local.create_nat_gateway ? 1 : 0

  route_table_id         = data.aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.cluster[0].id
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


resource "aws_security_group" "ssm_endpoints" {
  count       = local.create_ssm_endpoints ? 1 : 0
  name        = "${local.cluster_name}-ssm-endpoints-sg"
  description = "Security group para VPC Endpoints do SSM"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from cluster nodes"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-ssm-endpoints-sg"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  count               = local.create_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]

  tags = {
    Name = "${local.cluster_name}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = local.create_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]

  tags = {
    Name = "${local.cluster_name}-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = local.create_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]

  tags = {
    Name = "${local.cluster_name}-ec2messages-endpoint"
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

  depends_on = [
    aws_nat_gateway.cluster,
    aws_route.private_internet_via_nat,
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages,
  ]

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
    kubernetes_version       = var.kubernetes_version
    control_plane_private_ip = aws_instance.control_plane.private_ip
  })

  depends_on = [
    aws_nat_gateway.cluster,
    aws_route.private_internet_via_nat,
    aws_instance.control_plane,
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages,
  ]

  tags = {
    Name = "${local.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }
}
