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

# ============================================================
# EC2
# ============================================================

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorisé pour SSH vers l'EC2"
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t4g.small"
}

variable "key_name" {
  description = "Nom de la clé SSH AWS"
  type        = string
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


variable "environment" {
  type    = string
  default = "staging"
}