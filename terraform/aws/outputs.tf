output "ecr_repositories" {
  description = "Liste des repositories ECR créés"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.main.id
}

output "rds_endpoint" {
  description = "Endpoint PostgreSQL RDS"
  value       = aws_db_instance.postgres.address
}

output "redis_endpoint" {
  description = "Endpoint Redis ElastiCache"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}
