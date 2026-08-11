aws_region = "eu-west-3"

vpc_name = "my-project-vpc"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "eu-west-3a",
  "eu-west-3b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

project_name = "my-project"

database_name     = "novatech"
database_username = "novatech_admin"
database_password = "CHANGE-MOI-AVEC-UN-MOT-DE-PASSE-FORT"