# ==========================================================
# APP EC2
# ==========================================================

output "instance_id" {
  description = "ID da instância EC2 da aplicação"
  value       = aws_instance.app.id
}

output "private_ip" {
  description = "Private IP da instância EC2 da aplicação"
  value       = aws_instance.app.private_ip
}

output "public_ip" {
  description = "Public IP da instância EC2 da aplicação (se houver)"
  value       = aws_instance.app.public_ip
}

output "security_group_id" {
  description = "ID do Security Group da aplicação"
  value       = aws_security_group.app_sg.id
}

output "security_group_name" {
  description = "Nome do Security Group da aplicação"
  value       = aws_security_group.app_sg.name
}

# ==========================================================
# DB EC2 (Opcional)
# ==========================================================

output "db_instance_id" {
  description = "ID da instância EC2 do banco"
  value       = var.enable_db ? aws_instance.db[0].id : null
}

output "db_private_ip" {
  description = "Private IP da instância EC2 do banco"
  value       = var.enable_db ? aws_instance.db[0].private_ip : null
}

output "db_security_group_id" {
  description = "ID do Security Group do banco"
  value       = var.enable_db ? aws_security_group.db_sg[0].id : null
}

output "db_security_group_name" {
  description = "Nome do Security Group do banco"
  value       = var.enable_db ? aws_security_group.db_sg[0].name : null
}

# ==========================================================
# ALB (Opcional)
# ==========================================================

output "alb_dns_name" {
  description = "DNS público/privado do Application Load Balancer"
  value       = var.enable_lb ? aws_lb.app_alb[0].dns_name : null
}

output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = var.enable_lb ? aws_lb.app_alb[0].arn : null
}

output "alb_security_group_id" {
  description = "Security Group do ALB"
  value       = var.enable_lb ? aws_security_group.alb_sg[0].id : null
}

output "alb_target_group_arn" {
  description = "ARN do Target Group do ALB"
  value       = var.enable_lb ? aws_lb_target_group.app_tg[0].arn : null
}
