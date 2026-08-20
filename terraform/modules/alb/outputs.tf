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

output "arn_suffix" {
  description = "Suffixe d'ARN de l'ALB (format attendu par les dimensions CloudWatch AWS/ApplicationELB)"
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffixes" {
  description = "Suffixe d'ARN de la target group par couleur (format attendu par la dimension CloudWatch TargetGroup)"
  value       = { for color, tg in aws_lb_target_group.this : color => tg.arn_suffix }
}
