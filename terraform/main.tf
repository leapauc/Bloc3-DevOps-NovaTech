data "aws_caller_identity" "current" {}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

module "network" {
  source = "./modules/network"

  vpc_name = var.vpc_name
  vpc_cidr = var.vpc_cidr

  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}