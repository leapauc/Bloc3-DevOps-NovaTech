variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "novatech-hrflow"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "service_scaling" {
  description = "Scaling per service"
  type = map(object({
    desired_count = number
    min_capacity  = number
    max_capacity  = number
    cpu           = number
    memory        = number
  }))
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
