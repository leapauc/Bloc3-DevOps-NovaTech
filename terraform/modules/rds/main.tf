# ============================================================
# DB SUBNET GROUP
# ============================================================

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-postgres-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-postgres-subnet-group"
  }
}

# ============================================================
# SECURITY GROUP - POSTGRESQL
# ============================================================

resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-postgres-sg"
  description = "Security Group for PostgreSQL RDS"
  vpc_id      = var.vpc_id

  # ----------------------------------------------------------
  # PostgreSQL - uniquement depuis l'EC2 / K3s
  # ----------------------------------------------------------

  ingress {
    description     = "PostgreSQL from K3s EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id]
  }

  # ----------------------------------------------------------
  # OUTBOUND
  # ----------------------------------------------------------

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-postgres-sg"
  }
}

# ============================================================
# RDS POSTGRESQL
# ============================================================

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  # ----------------------------------------------------------
  # ENGINE
  # ----------------------------------------------------------

  engine         = "postgres"
  engine_version = "17"

  # ----------------------------------------------------------
  # FREE TIER
  # ----------------------------------------------------------

  instance_class = "db.t4g.micro"

  # ----------------------------------------------------------
  # STORAGE
  # ----------------------------------------------------------

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  # ----------------------------------------------------------
  # DATABASE
  # ----------------------------------------------------------

  db_name  = var.database_name
  username = var.database_username
  password = var.database_password
  port     = 5432

  # ----------------------------------------------------------
  # NETWORK
  # ----------------------------------------------------------

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  publicly_accessible = false

  # ----------------------------------------------------------
  # SINGLE-AZ
  # ----------------------------------------------------------

  multi_az = false

  # ----------------------------------------------------------
  # BACKUPS
  # ----------------------------------------------------------

  backup_retention_period = 0

  # ----------------------------------------------------------
  # MONITORING
  # ----------------------------------------------------------

  monitoring_interval = 0

  performance_insights_enabled = false

  # ----------------------------------------------------------
  # MAINTENANCE
  # ----------------------------------------------------------

  auto_minor_version_upgrade = true

  # ----------------------------------------------------------
  # LAB / PROJECT SETTINGS
  # ----------------------------------------------------------

  deletion_protection = false

  skip_final_snapshot = true

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-postgres"
  }
}