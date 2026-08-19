output "dns_name" {
  value = aws_lb.this.dns_name
}

output "zone_id" {
  value = aws_lb.this.zone_id
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "target_group_arns" {
  description = "ARN de la target group par couleur (blue/green)"
  value       = { for color, tg in aws_lb_target_group.this : color => tg.arn }
}
