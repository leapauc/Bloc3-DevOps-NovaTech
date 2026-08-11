# ============================================================
# PROJECT
# ============================================================

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

# ============================================================
# VPC
# ============================================================

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

# ============================================================
# SUBNETS
# ============================================================

variable "subnet_ids" {
  description = "IDs des subnets du VPC utilisés par le groupe RDS"
  type        = list(string)
}

# ============================================================
# EC2 SECURITY GROUP
# ============================================================

variable "ec2_security_group_id" {
  description = "Security Group de l'EC2/K3s autorisé à accéder à PostgreSQL"
  type        = string
}

# ============================================================
# DATABASE
# ============================================================

variable "database_name" {
  description = "Nom de la base PostgreSQL"
  type        = string
  default     = "novatech"
}

variable "database_username" {
  description = "Utilisateur administrateur PostgreSQL"
  type        = string
  default     = "novatech_admin"
}

variable "database_password" {
  description = "Mot de passe administrateur PostgreSQL"
  type        = string
  sensitive   = true
}