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
