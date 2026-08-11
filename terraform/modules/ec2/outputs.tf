output "instance_id" {
  description = "ID de l'instance K3s"
  value       = aws_instance.k3s.id
}

output "private_ip" {
  description = "Adresse IP privée de l'instance K3s"
  value       = aws_instance.k3s.private_ip
}

output "security_group_id" {
  description = "ID du Security Group K3s"
  value       = aws_security_group.k3s.id
}

output "k3s_ami" {
  description = "AMI Ubuntu utilisée"
  value       = data.aws_ami.ubuntu.id
}