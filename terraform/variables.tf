variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# ============================================================
# RDS
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