variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "public_subnet_id" {
  description = "ID du public subnet dans lequel déployer l'EC2"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorisé pour SSH"
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

variable "monitoring_allowed_cidr" {
  description = "CIDR allowed to access Grafana and Prometheus"
  type        = string
}