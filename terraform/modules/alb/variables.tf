variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

# L'ALB a besoin d'au moins 2 subnets dans 2 AZ différentes
variable "subnet_ids" {
  type = list(string)
}

variable "instance_ids" {
  description = "Instances EC2 k3s blue/green (Traefik écoute en hostNetwork sur le port 80 sur chacune) : une target group par couleur"
  type        = map(string)

  validation {
    condition     = length(setsubtract(keys(var.instance_ids), ["blue", "green"])) == 0
    error_message = "instance_ids doit avoir pour clés uniquement \"blue\" et/ou \"green\"."
  }
}

variable "active_color" {
  description = "Couleur actuellement servie par le listener ALB (bascule = changer cette valeur puis apply)"
  type        = string

  validation {
    condition     = contains(["blue", "green"], var.active_color)
    error_message = "active_color doit être \"blue\" ou \"green\"."
  }
}

variable "target_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "certificate_arn" {
  description = "ARN d'un certificat ACM. Laisser vide tant qu'il n'y a pas de nom de domaine : l'ALB reste en HTTP seul."
  type        = string
  default     = ""
}
