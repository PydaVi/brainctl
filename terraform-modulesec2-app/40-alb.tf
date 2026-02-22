locals {
  alb_ingress_rules_raw = concat(
    [
      {
        description = "Listener"
        from_port   = var.lb_listener_port
        to_port     = var.lb_listener_port
        protocol    = "tcp"
        cidr_blocks = [var.lb_allowed_cidr]
      }
    ],
    var.alb_extra_ingress_rules,
  )

  alb_ingress_rules = {
    for rule in local.alb_ingress_rules_raw :
    format("%s|%d|%d|%s", rule.protocol, rule.from_port, rule.to_port, join(",", sort(distinct(rule.cidr_blocks)))) => {
      description = rule.description
      from_port   = rule.from_port
      to_port     = rule.to_port
      protocol    = rule.protocol
      cidr_blocks = sort(distinct(rule.cidr_blocks))
    }
  }
}

resource "aws_security_group" "alb_sg" {
  count       = var.enable_lb ? 1 : 0
  name        = "${var.name}-${var.environment}-alb-sg"
  description = "ALB SG for ${var.name}"
  vpc_id      = var.vpc_id

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

resource "aws_security_group_rule" "alb_ingress" {
  for_each          = var.enable_lb ? local.alb_ingress_rules : {}
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg[0].id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

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
  count            = var.enable_lb && !var.enable_app_asg ? var.app_instance_count : 0
  target_group_arn = aws_lb_target_group.app_tg[0].arn
  target_id        = aws_instance.app[count.index].id
  port             = var.app_port
}
