locals {
  name_prefix = "${var.project_name}-${var.environment}"
  service_names = ["frontend", "gateway", "auth", "paie", "conges", "recrutement"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnets[count.index]
  availability_zone       = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB"
    from_port       = 3000
    to_port         = 3007
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "postgres" {
  identifier             = "${local.name_prefix}-postgres"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.ecs_tasks.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${local.name_prefix}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.ecs_tasks.id]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.service_names)

  name                 = "${local.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 7
}

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-frontend-tg"
  port        = 3005
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "gateway" {
  name        = "${local.name_prefix}-gateway-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

module "frontend" {
  source = "./modules/ecs_service"

  service_name       = "frontend"
  cluster_id         = aws_ecs_cluster.main.id
  cluster_name       = aws_ecs_cluster.main.name
  subnet_ids         = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]
  target_group_arn   = aws_lb_target_group.frontend.arn
  repository_url     = aws_ecr_repository.services["frontend"].repository_url
  container_port     = 3005
  cpu                = var.service_scaling["frontend"].cpu
  memory             = var.service_scaling["frontend"].memory
  desired_count      = var.service_scaling["frontend"].desired_count
  min_capacity       = var.service_scaling["frontend"].min_capacity
  max_capacity       = var.service_scaling["frontend"].max_capacity
  log_group_name     = aws_cloudwatch_log_group.main.name
  aws_region         = var.aws_region
}

module "gateway" {
  source = "./modules/ecs_service"

  service_name       = "gateway"
  cluster_id         = aws_ecs_cluster.main.id
  cluster_name       = aws_ecs_cluster.main.name
  subnet_ids         = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]
  target_group_arn   = aws_lb_target_group.gateway.arn
  repository_url     = aws_ecr_repository.services["gateway"].repository_url
  container_port     = 3000
  cpu                = var.service_scaling["gateway"].cpu
  memory             = var.service_scaling["gateway"].memory
  desired_count      = var.service_scaling["gateway"].desired_count
  min_capacity       = var.service_scaling["gateway"].min_capacity
  max_capacity       = var.service_scaling["gateway"].max_capacity
  log_group_name     = aws_cloudwatch_log_group.main.name
  aws_region         = var.aws_region
}

module "auth" {
  source = "./modules/ecs_service"

  service_name       = "auth"
  cluster_id         = aws_ecs_cluster.main.id
  cluster_name       = aws_ecs_cluster.main.name
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]
  target_group_arn   = null
  repository_url     = aws_ecr_repository.services["auth"].repository_url
  container_port     = 3001
  cpu                = var.service_scaling["auth"].cpu
  memory             = var.service_scaling["auth"].memory
  desired_count      = var.service_scaling["auth"].desired_count
  min_capacity       = var.service_scaling["auth"].min_capacity
  max_capacity       = var.service_scaling["auth"].max_capacity
  log_group_name     = aws_cloudwatch_log_group.main.name
  aws_region         = var.aws_region
}

module "paie" {
  source = "./modules/ecs_service"

  service_name       = "paie"
  cluster_id         = aws_ecs_cluster.main.id
  cluster_name       = aws_ecs_cluster.main.name
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]
  target_group_arn   = null
  repository_url     = aws_ecr_repository.services["paie"].repository_url
  container_port     = 3002
  cpu                = var.service_scaling["paie"].cpu
  memory             = var.service_scaling["paie"].memory
  desired_count      = var.service_scaling["paie"].desired_count
  min_capacity       = var.service_scaling["paie"].min_capacity
  max_capacity       = var.service_scaling["paie"].max_capacity
  log_group_name     = aws_cloudwatch_log_group.main.name
  aws_region         = var.aws_region
}

module "conges" {
  source = "./modules/ecs_service"

  service_name       = "conges"
  cluster_id         = aws_ecs_cluster.main.id
  cluster_name       = aws_ecs_cluster.main.name
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]
  target_group_arn   = null
  repository_url     = aws_ecr_repository.services["conges"].repository_url
  container_port     = 3003
  cpu                = var.service_scaling["conges"].cpu
  memory             = var.service_scaling["conges"].memory
  desired_count      = var.service_scaling["conges"].desired_count
  min_capacity       = var.service_scaling["conges"].min_capacity
  max_capacity       = var.service_scaling["conges"].max_capacity
  log_group_name     = aws_cloudwatch_log_group.main.name
  aws_region         = var.aws_region
}

module "recrutement" {
  source = "./modules/ecs_service"

  service_name       = "recrutement"
  cluster_id         = aws_ecs_cluster.main.id
  cluster_name       = aws_ecs_cluster.main.name
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]
  target_group_arn   = null
  repository_url     = aws_ecr_repository.services["recrutement"].repository_url
  container_port     = 3004
  cpu                = var.service_scaling["recrutement"].cpu
  memory             = var.service_scaling["recrutement"].memory
  desired_count      = var.service_scaling["recrutement"].desired_count
  min_capacity       = var.service_scaling["recrutement"].min_capacity
  max_capacity       = var.service_scaling["recrutement"].max_capacity
  log_group_name     = aws_cloudwatch_log_group.main.name
  aws_region         = var.aws_region
}
