data "aws_caller_identity" "current" {}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

# ============================================================
# BACKEND
# ============================================================

terraform {
  backend "s3" {
    bucket       = "hrflow-terraform-state-079716036671"
    key          = "hrflow/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}

# ============================================================
# NETWORK
# ============================================================

module "network" {
  source = "./modules/network"

  vpc_name = var.vpc_name
  vpc_cidr = var.vpc_cidr

  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
}

# ============================================================
# EC2 UBUNTU 24.04 ARM64 + K3S
# ============================================================

module "ec2" {
  source = "./modules/ec2"

  project_name = var.project_name

  vpc_id = module.network.vpc_id

  public_subnet_id = module.network.public_subnet_ids[0]

  ssh_allowed_cidr = var.ssh_allowed_cidr

  instance_type = var.instance_type

  key_name = var.key_name
}

# ============================================================
# RDS POSTGRESQL - DISABLED FOR STUDY COST CONTROL
# ============================================================
#
# module "rds" {
#   source = "./modules/rds"
#
#   project_name = var.project_name
#
#   vpc_id = module.network.vpc_id
#
#   subnet_ids = module.network.public_subnet_ids
#
#   ec2_security_group_id = module.ec2.security_group_id
#
#   database_name     = var.database_name
#   database_username = var.database_username
#   database_password = var.database_password
# }
