output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs des private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs des public subnets"
  value       = aws_subnet.public[*].id
}