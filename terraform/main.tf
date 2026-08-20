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

# ============================================================
# MONITORING — ALB & RDS (ressources partagées entre blue/green, donc pas
# dupliquées par couleur comme monitoring_blue/monitoring_green). Rattachées
# au topic SNS de monitoring_blue (déjà abonné à alert_email) plutôt que
# d'en créer un 3e : ça éviterait juste une confirmation d'abonnement email
# supplémentaire pour rien, le topic est un simple canal de diffusion.
# ============================================================

# Une cible en échec de health check sur la couleur ACTIVE = trafic public
# impacté alors que l'EC2 elle-même répond (ec2-down ne le détecterait pas) :
# souci applicatif (pod crashloop, service down, healthcheck qui échoue).
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  for_each = module.alb.target_group_arn_suffixes

  alarm_name        = "${var.project_name}-alb-unhealthy-${each.key}"
  alarm_description = "La target group ${each.key} de l'ALB a au moins une cible en échec de health check. Si '${each.key}' est la couleur active, le trafic public est impacté malgré une EC2 saine (souci applicatif probable : pod down, service qui ne répond plus). Vérifier kubectl get pods -n hrflow-<env> et les logs des services sur l'instance ${each.key}."

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  dimensions = {
    TargetGroup  = each.value
    LoadBalancer = module.alb.arn_suffix
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1

  # Pas de donnée = pas de cible enregistrée sur cette target group à cet
  # instant (ex. couleur idle avant son premier déploiement) : pas une panne.
  treat_missing_data = "notBreaching"

  alarm_actions = [module.monitoring_blue.sns_topic_arn]
  ok_actions    = [module.monitoring_blue.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name        = "${var.project_name}-alb-5xx-high"
  alarm_description = "L'ALB (${var.project_name}) a renvoyé au moins 5 erreurs HTTP 5xx en provenance des services applicatifs sur les 5 dernières minutes. Vérifier les logs des services (gateway/auth/paie/conges/recrutement) pour identifier le service en échec."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
  }

  statistic = "Sum"
  # Fenêtre unique de 5 min (period=300, evaluation_periods=1) plutôt que 5
  # périodes d'1 min à >=5 chacune : sinon le seuil réel serait un cumul de
  # ~25 erreurs sur 5 min au lieu des 5 erreurs/5min visées.
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5

  treat_missing_data = "notBreaching"

  alarm_actions = [module.monitoring_blue.sns_topic_arn]
  ok_actions    = [module.monitoring_blue.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name        = "${var.project_name}-alb-latency-high"
  alarm_description = "Le temps de réponse moyen des cibles derrière l'ALB (${var.project_name}) dépasse 2s depuis 5 minutes. Dégradation de performance perçue par les utilisateurs. Vérifier la charge CPU/mémoire des pods et l'état de la base RDS."

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
  }

  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 5

  comparison_operator = "GreaterThanThreshold"
  threshold           = 2

  treat_missing_data = "notBreaching"

  alarm_actions = [module.monitoring_blue.sns_topic_arn]
  ok_actions    = [module.monitoring_blue.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name        = "${var.project_name}-rds-cpu-high"
  alarm_description = "La base RDS (${module.rds.identifier}) a un CPU moyen > 80% depuis 5 minutes. Vérifier les requêtes lentes/bloquantes (pg_stat_activity) et l'éventuel besoin de scaling."

  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"

  dimensions = {
    DBInstanceIdentifier = module.rds.identifier
  }

  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 5

  comparison_operator = "GreaterThanThreshold"
  threshold           = 80

  treat_missing_data = "notBreaching"

  alarm_actions = [module.monitoring_blue.sns_topic_arn]
  ok_actions    = [module.monitoring_blue.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name        = "${var.project_name}-rds-storage-low"
  alarm_description = "La base RDS (${module.rds.identifier}) a moins de 2 Go d'espace disque libre (< 10% des 20 Go alloués). Risque d'arrêt de la base si non traité. Vérifier la console RDS → Storage et envisager une augmentation de allocated_storage."

  namespace   = "AWS/RDS"
  metric_name = "FreeStorageSpace"

  dimensions = {
    DBInstanceIdentifier = module.rds.identifier
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  comparison_operator = "LessThanThreshold"
  threshold           = 2 * 1024 * 1024 * 1024 # 2 Go, en octets (unité native FreeStorageSpace)

  # Absence de métrique sur une ressource censée toujours en émettre = signal
  # à part entière (instance possiblement indisponible), donc on alerte.
  treat_missing_data = "breaching"

  alarm_actions = [module.monitoring_blue.sns_topic_arn]
  ok_actions    = [module.monitoring_blue.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_memory_low" {
  alarm_name        = "${var.project_name}-rds-memory-low"
  alarm_description = "La base RDS (${module.rds.identifier}, db.t4g.micro) a moins de 150 Mo de mémoire libre depuis 3 minutes. Risque de pression mémoire/OOM sur une instance à faible RAM. Vérifier les connexions actives et les requêtes en cours."

  namespace   = "AWS/RDS"
  metric_name = "FreeableMemory"

  dimensions = {
    DBInstanceIdentifier = module.rds.identifier
  }

  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3

  comparison_operator = "LessThanThreshold"
  threshold           = 150 * 1024 * 1024 # 150 Mo, en octets (unité native FreeableMemory)

  treat_missing_data = "notBreaching"

  alarm_actions = [module.monitoring_blue.sns_topic_arn]
  ok_actions    = [module.monitoring_blue.sns_topic_arn]
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
