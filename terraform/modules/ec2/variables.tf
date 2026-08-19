variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "name_tag" {
  description = "Préfixe utilisé UNIQUEMENT pour les tags Name (cosmétique, update in-place). Laisser vide pour retomber sur project_name. Ne pilote jamais les arguments `name` réels (IAM role / instance profile / security group), qui restent sur project_name car ForceNew : les changer recréerait ces ressources."
  type        = string
  default     = ""
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

variable "environment" {
  type    = string
  default = "staging"
}