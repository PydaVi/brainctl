output "control_plane_instance_id" {
  value = aws_instance.control_plane.id
}

output "control_plane_private_ip" {
  value = aws_instance.control_plane.private_ip
}

output "control_plane_public_ip" {
  value = aws_instance.control_plane.public_ip
}

output "control_plane_public_dns" {
  value = aws_instance.control_plane.public_dns
}

output "worker_instance_ids" {
  value = aws_instance.workers[*].id
}

output "kubeconfig_retrieve_instructions" {
  value = "scp -o StrictHostKeyChecking=no -i <key.pem> ubuntu@${aws_instance.control_plane.public_dns}:/home/ubuntu/.kube/config ./kubeconfig && KUBECONFIG=./kubeconfig kubectl get nodes"
}

output "validation_command" {
  value = "ssh -o StrictHostKeyChecking=no -i <key.pem> ubuntu@${aws_instance.control_plane.public_dns} 'kubectl get nodes -o wide'"
}
