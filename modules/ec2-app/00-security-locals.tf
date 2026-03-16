locals {
  effective_egress_cidrs = length(var.allowed_egress_cidrs) > 0 ? var.allowed_egress_cidrs : [var.vpc_cidr]
}
