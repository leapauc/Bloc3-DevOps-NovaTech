# ============================================================
# RDS ENDPOINT
# ============================================================

output "database_endpoint" {
  description = "Endpoint PostgreSQL RDS"
  value       = aws_db_instance.postgres.address
}

# ============================================================
# RDS PORT
# ============================================================

output "database_port" {
  description = "Port PostgreSQL"
  value       = aws_db_instance.postgres.port
}

# ============================================================
# DATABASE NAME
# ============================================================

output "database_name" {
  description = "Nom de la base PostgreSQL"
  value       = aws_db_instance.postgres.db_name
}

# ============================================================
# DATABASE USERNAME
# ============================================================

output "database_username" {
  description = "Utilisateur PostgreSQL"
  value       = aws_db_instance.postgres.username
}

# ============================================================
# SECURITY GROUP
# ============================================================

output "security_group_id" {
  description = "Security Group du RDS PostgreSQL"
  value       = aws_security_group.postgres.id
}

# ============================================================
# DB SUBNET GROUP
# ============================================================

output "db_subnet_group_name" {
  description = "Nom du DB subnet group"
  value       = aws_db_subnet_group.postgres.name
}