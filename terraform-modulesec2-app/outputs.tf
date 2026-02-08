output "instance_id" {
  description = "ID da EC2 da aplicação"
  value       = aws_instance.app.id
}

output "private_ip" {
  description = "Private IP da EC2"
  value       = aws_instance.app.private_ip
}

output "public_ip" {
  description = "Public IP da EC2 (se houver)"
  value       = aws_instance.app.public_ip
}

output "security_group_id" {
  description = "ID do Security Group da app"
  value       = aws_security_group.app_sg.id
}

output "security_group_name" {
  description = "Nome do Security Group da app"
  value       = aws_security_group.app_sg.name
}

output "db_instance_id" {
  value       = var.enable_db ? aws_instance.db[0].id : null
  description = "DB EC2 instance id"
}

output "db_private_ip" {
  value       = var.enable_db ? aws_instance.db[0].private_ip : null
  description = "DB EC2 private ip"
}

output "db_security_group_id" {
  value       = var.enable_db ? aws_security_group.db_sg[0].id : null
  description = "DB SG id"
}

output "db_security_group_name" {
  value       = var.enable_db ? aws_security_group.db_sg[0].name : null
  description = "DB SG name"
}
