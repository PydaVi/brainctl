module "observability" {
  source = "./modules/observability"

  enable_observability = var.enable_observability
  enable_app_asg       = var.enable_app_asg
  enable_db            = var.enable_db
  enable_lb            = var.enable_lb

  name        = var.name
  environment = var.environment
  region      = var.region

  cpu_high_threshold = var.cpu_high_threshold
  app_asg_min_size   = var.app_asg_min_size

  app_instance_id = var.enable_app_asg ? null : aws_instance.app[0].id
  app_asg_name    = var.enable_app_asg ? aws_autoscaling_group.app[0].name : null

  db_instance_id = var.enable_db ? aws_instance.db[0].id : null

  alb_arn_suffix = var.enable_lb ? aws_lb.app_alb[0].arn_suffix : null
  tg_arn_suffix  = var.enable_lb ? aws_lb_target_group.app_tg[0].arn_suffix : null

  alarm_actions = local.alarm_actions
}
