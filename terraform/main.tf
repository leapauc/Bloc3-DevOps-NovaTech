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

  vpc_name            = var.vpc_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
}

# ============================================================
# EC2 UBUNTU 24.04 ARM64 + K3S — BLUE / GREEN
# Deux clusters k3s complets et indépendants, un par couleur, chacun dans
# une AZ différente (isolation réelle). Le module ec2 n'est pas modifié :
# on le distingue par project_name (les noms de rôle IAM / security group
# doivent être uniques par compte/VPC) et par subnet.
#
# "blue" garde project_name INCHANGÉ (pas de suffixe) : c'est l'EC2 qui
# existait déjà avant le Blue-Green (migrée via `terraform state mv module.ec2
# module.ec2_blue`). Les noms de rôle IAM / security group / instance sont
# ForceNew : un suffixe ici recréerait tout (et l'instance en cours de
# service) au lieu d'un simple renommage d'adresse de state. Seul "green"
# (vraiment nouveau) a besoin d'un nom distinct pour éviter la collision.
# ============================================================
module "ec2_blue" {
  source = "./modules/ec2"

  project_name     = var.project_name
  name_tag         = "${var.project_name}-blue" # cosmétique only (cf. modules/ec2/variables.tf) : distingue "my-project-blue-k3s" de green sans toucher aux noms ForceNew
  vpc_id           = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_ids[0]
  ssh_allowed_cidr = var.ssh_allowed_cidr
  instance_type    = var.instance_type
  key_name         = var.key_name
}

module "ec2_green" {
  source = "./modules/ec2"

  project_name     = "${var.project_name}-green"
  vpc_id           = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_ids[1]
  ssh_allowed_cidr = var.ssh_allowed_cidr
  instance_type    = var.instance_type
  key_name         = var.key_name
}

# ============================================================
# MONITORING (alerte email si une EC2 k3s ne répond plus) — une alarme par couleur
# ============================================================
module "monitoring_blue" {
  source = "./modules/monitoring"

  # Pas de suffixe "-blue" ici (contrairement à ec2_blue) : le nom du topic
  # SNS et de l'alarme CloudWatch sont des attributs immuables (forcent un
  # replace, donc la destruction de l'abonnement email déjà confirmé) et
  # n'ont pas besoin d'être uniques entre blue/green comme le sont le rôle
  # IAM/security group de l'EC2. En gardant project_name inchangé, ce module
  # garde l'identité EXACTE de l'alerte déjà en place (my-project-alerts,
  # my-project-ec2-down) — pur renommage d'adresse de state, zéro diff AWS.
  project_name = var.project_name
  instance_id  = module.ec2_blue.instance_id
  alert_email  = var.alert_email
}

module "monitoring_green" {
  source = "./modules/monitoring"

  project_name = "${var.project_name}-green"
  instance_id  = module.ec2_green.instance_id
  alert_email  = var.alert_email
}

# ============================================================
# RDS POSTGRESQL (partagée entre blue et green — cf. discipline de
# migration additive-only documentée dans k8s/postgres-init-configmap.yaml)
# ============================================================
module "rds" {
  source = "./modules/rds"

  project_name = var.project_name

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids # mêmes subnets que les EC2, publicly_accessible=false donc pas exposée

  ec2_security_group_ids = [module.ec2_blue.security_group_id, module.ec2_green.security_group_id]

  database_name     = var.database_name
  database_username = var.database_username
  database_password = var.database_password
  instance_class    = var.rds_instance_class
}

# ============================================================
# APPLICATION LOAD BALANCER (une target group par couleur, bascule via
# active_color sur le listener)
# ============================================================
module "alb" {
  source = "./modules/alb"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.public_subnet_ids # >= 2 AZ requis par l'ALB

  instance_ids = {
    blue  = module.ec2_blue.instance_id
    green = module.ec2_green.instance_id
  }
  active_color    = var.active_color
  target_port     = 80
  certificate_arn = var.certificate_arn
}

# Chaque EC2 n'accepte le port 80 QUE depuis l'ALB (plus de 0.0.0.0/0 direct
# sur l'instance). Toujours autorisée même si idle : c'est le listener ALB
# (module.alb, active_color) qui décide qui reçoit vraiment le trafic.
resource "aws_security_group_rule" "alb_to_ec2_http_blue" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.ec2_blue.security_group_id
  source_security_group_id = module.alb.security_group_id
  description              = "HTTP depuis le load balancer uniquement"
}

resource "aws_security_group_rule" "alb_to_ec2_http_green" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.ec2_green.security_group_id
  source_security_group_id = module.alb.security_group_id
  description              = "HTTP depuis le load balancer uniquement"
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_address" {
  value = module.rds.address
}

output "db_name" {
  value = module.rds.db_name
}

output "db_username" {
  value = var.database_username
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "active_color" {
  description = "Couleur actuellement servie par l'ALB — lu par le workflow CD pour déterminer la couleur idle avant déploiement"
  value       = var.active_color
}

output "instance_id_blue" {
  value = module.ec2_blue.instance_id
}

output "instance_id_green" {
  value = module.ec2_green.instance_id
}
