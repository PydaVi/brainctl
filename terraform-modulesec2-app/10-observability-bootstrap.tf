resource "aws_iam_role" "ec2_cw_role" {
  count = var.enable_observability ? 1 : 0
  name  = "${var.name}-${var.environment}-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cw_agent" {
  count      = var.enable_observability ? 1 : 0
  role       = aws_iam_role.ec2_cw_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_managed" {
  count      = var.enable_observability ? 1 : 0
  role       = aws_iam_role.ec2_cw_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_cw_profile" {
  count = var.enable_observability ? 1 : 0
  name  = "${var.name}-${var.environment}-cw-profile"
  role  = aws_iam_role.ec2_cw_role[0].name
}

resource "aws_cloudwatch_log_group" "brainctl" {
  count             = var.enable_observability ? 1 : 0
  name              = local.cw_log_group_name
  retention_in_days = 14

  tags = {
    Name        = local.cw_log_group_name
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_sns_topic" "alerts" {
  count = local.sns_enabled ? 1 : 0
  name  = "${var.name}-${var.environment}-alerts"

  tags = {
    Name        = "${var.name}-${var.environment}-alerts"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = local.sns_enabled ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_security_group" "ssm_endpoints" {
  count       = var.enable_observability && var.enable_ssm_endpoints ? 1 : 0
  name        = "${var.name}-${var.environment}-ssm-endpoints-sg"
  description = "Security group for private SSM VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from APP"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  dynamic "ingress" {
    for_each = var.enable_db ? [1] : []
    content {
      description     = "HTTPS from DB"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      security_groups = [aws_security_group.db_sg[0].id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name}-${var.environment}-ssm-endpoints-sg"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  count               = var.enable_observability && var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = var.enable_ssm_private_dns

  tags = {
    Name        = "${var.name}-${var.environment}-vpce-ssm"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.enable_observability && var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = var.enable_ssm_private_dns

  tags = {
    Name        = "${var.name}-${var.environment}-vpce-ssmmessages"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.enable_observability && var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = var.enable_ssm_private_dns

  tags = {
    Name        = "${var.name}-${var.environment}-vpce-ec2messages"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_vpc_endpoint" "logs" {
  count               = var.enable_observability && var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = var.enable_ssm_private_dns

  tags = {
    Name        = "${var.name}-${var.environment}-vpce-logs"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_vpc_endpoint" "monitoring" {
  count               = var.enable_observability && var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = var.enable_ssm_private_dns

  tags = {
    Name        = "${var.name}-${var.environment}-vpce-monitoring"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}


resource "aws_vpc_endpoint" "sts" {
  count               = var.enable_observability && var.enable_ssm_endpoints ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = var.enable_ssm_private_dns

  tags = {
    Name        = "${var.name}-${var.environment}-vpce-sts"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}


resource "aws_ssm_document" "cwagent_apply_config" {
  count           = var.enable_observability ? 1 : 0
  name            = "${var.name}-${var.environment}-cwagent-apply-config"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Apply CloudWatch Agent config and restart service"
    parameters = {
      ConfigContent = {
        type        = "String"
        description = "CloudWatch Agent config JSON payload"
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "ApplyCloudWatchAgentConfig"
        inputs = {
          runCommand = [
            "$ErrorActionPreference = 'Stop'",
            "$configPath = 'C:\ProgramData\Amazon\AmazonCloudWatchAgent\config.json'",
            "$agentCtl = 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1'",
            "New-Item -ItemType Directory -Force -Path 'C:\ProgramData\Amazon\AmazonCloudWatchAgent' | Out-Null",
            "$utf8NoBom = New-Object System.Text.UTF8Encoding($false)",
            "$json = @'",
            "{{ ConfigContent }}",
            "'@",
            "[System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)",
            "if (Test-Path $agentCtl) {",
            "  & $agentCtl -a fetch-config -m ec2 -s -c file:$configPath",
            "} else {",
            "  throw 'CloudWatch Agent control script not found'",
            "}"
          ]
        }
      }
    ]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-cwagent-apply-config"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_ssm_association" "cwagent_apply_app" {
  count = var.enable_observability ? 1 : 0

  name                        = aws_ssm_document.cwagent_apply_config[0].name
  association_name            = "${var.name}-${var.environment}-cwagent-app"
  apply_only_at_cron_interval = false

  targets {
    key    = "tag:ManagedBy"
    values = ["brainctl"]
  }

  targets {
    key    = "tag:Environment"
    values = [var.environment]
  }

  targets {
    key    = "tag:Role"
    values = ["app"]
  }

  parameters = {
    ConfigContent = [local.cw_agent_config_app]
  }

  max_concurrency = "100%"
  max_errors      = "100%"
}

resource "aws_ssm_association" "cwagent_apply_db" {
  count = var.enable_observability && var.enable_db && var.db_mode == "ec2" ? 1 : 0

  name                        = aws_ssm_document.cwagent_apply_config[0].name
  association_name            = "${var.name}-${var.environment}-cwagent-db"
  apply_only_at_cron_interval = false

  targets {
    key    = "tag:ManagedBy"
    values = ["brainctl"]
  }

  targets {
    key    = "tag:Environment"
    values = [var.environment]
  }

  targets {
    key    = "tag:Role"
    values = ["db"]
  }

  parameters = {
    ConfigContent = [local.cw_agent_config_db]
  }

  max_concurrency = "100%"
  max_errors      = "100%"
}
