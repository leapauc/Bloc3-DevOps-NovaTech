variable "service_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "cluster_id" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "novatech-hrflow-dev-cluster"
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "target_group_arn" {
  type    = string
  default = null
}

variable "repository_url" {
  type = string
}

variable "container_port" {
  type = number
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "log_group_name" {
  type = string
}

variable "aws_region" {
  type = string
}
