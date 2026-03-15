resource "aws_launch_template" "app" {
  count = var.enable_app_asg ? 1 : 0

  name_prefix   = "${var.name}-${var.environment}-lt-"
  image_id      = local.resolved_app_ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  iam_instance_profile {
    name = var.enable_observability ? aws_iam_instance_profile.ec2_cw_profile[0].name : null
  }

  user_data = local.app_effective_user_data != "" ? base64encode(local.app_effective_user_data) : null

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = var.imds_v2_required ? "required" : "optional"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.name}-${var.environment}"
      Environment = var.environment
      ManagedBy   = "brainctl"
      Role        = "app"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.name}-${var.environment}-app-root"
      Environment = var.environment
      ManagedBy   = "brainctl"
      App         = var.name
      BackupScope = "app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  count = var.enable_app_asg ? 1 : 0

  name                      = "${var.name}-${var.environment}-asg"
  min_size                  = var.app_asg_min_size
  max_size                  = var.app_asg_max_size
  desired_capacity          = var.app_asg_desired_capacity
  health_check_type         = var.enable_lb ? "ELB" : "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = var.app_asg_subnet_ids
  target_group_arns         = var.enable_lb ? [aws_lb_target_group.app_tg[0].arn] : []

  launch_template {
    id      = aws_launch_template.app[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "brainctl"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "app_cpu_target" {
  count = var.enable_app_asg ? 1 : 0

  name                   = "${var.name}-${var.environment}-asg-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.app_asg_cpu_target
  }
}
