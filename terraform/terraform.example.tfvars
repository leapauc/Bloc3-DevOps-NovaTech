aws_region = "eu-west-3"

vpc_name = "my-project-name"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "eu-west-3a",
  "eu-west-3b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

# ============================================================
# PROJECT
# ============================================================

project_name = "my-project"

# ============================================================
# EC2 / K3S
# ============================================================

instance_type = "t4g.medium"

key_name = "my-key"

ssh_allowed_cidr = "<IP_LOCAL>/32"

# ============================================================
# RDS POSTGRESQL
# ============================================================

database_name     = "novatech"
database_username = "novatech_admin"
database_password = "my_password"

# ============================================================
# GRAFANA + PROMETHEUS
# ============================================================

monitoring_allowed_cidr = "<IP_LOCAL>/32"