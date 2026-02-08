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
