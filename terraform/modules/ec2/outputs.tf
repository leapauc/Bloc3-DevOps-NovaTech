output "instance_id" {
  description = "ID de l'instance EC2 K3s"
  value       = aws_instance.k3s.id
}

output "private_ip" {
  description = "Adresse IP privée de l'EC2 K3s"
  value       = aws_instance.k3s.private_ip
}

output "security_group_id" {
  description = "Security Group de l'EC2 K3s"
  value       = aws_security_group.k3s.id
}

output "k3s_ami" {
  description = "AMI Ubuntu utilisée"
  value       = data.aws_ami.ubuntu.id
}