# ============================================================
# DATA - UBUNTU AMI
# ============================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg"
  description = "Security Group for K3s EC2"
  vpc_id      = var.vpc_id

  # ----------------------------------------------------------
  # SSH
  # ----------------------------------------------------------

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # ----------------------------------------------------------
  # KUBERNETES API
  # ----------------------------------------------------------

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------
  # K3S FLANNEL VXLAN
  # ----------------------------------------------------------

  ingress {
    description = "K3s Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------
  # HTTP - GRAFANA / APPLICATION
  # ----------------------------------------------------------

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------
  # GRAFANA
  # ----------------------------------------------------------

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------
  # PROMETHEUS
  # ----------------------------------------------------------

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------
  # ALL OUTBOUND
  # ----------------------------------------------------------

  egress {
    description = "Internet outbound via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-k3s-sg"
  }
}

# ============================================================
# EC2 - K3S SERVER
# ============================================================

resource "aws_instance" "k3s" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  subnet_id = var.private_subnet_id

  key_name = var.key_name

  vpc_security_group_ids = [
    aws_security_group.k3s.id
  ]

  associate_public_ip_address = false

  # ----------------------------------------------------------
  # ROOT DISK
  # ----------------------------------------------------------

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true

    tags = {
      Name = "${var.project_name}-k3s-root"
    }
  }

  # ----------------------------------------------------------
  # USER DATA - INSTALL K3S
  # ----------------------------------------------------------

  user_data = <<-EOF
    #!/bin/bash

    set -eux

    # Update system
    apt-get update -y
    apt-get upgrade -y

    # Install required packages
    apt-get install -y curl

    # Install K3s
    curl -sfL https://get.k3s.io | sh -

    # Wait for K3s
    systemctl enable k3s
    systemctl start k3s

    # Configure kubectl for ubuntu user
    mkdir -p /home/ubuntu/.kube

    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config

    chown -R ubuntu:ubuntu /home/ubuntu/.kube

    chmod 600 /home/ubuntu/.kube/config

    # Allow kubectl to find the K3s configuration
    echo 'export KUBECONFIG=/home/ubuntu/.kube/config' >> /home/ubuntu/.bashrc

    # Useful aliases
    echo 'alias k=kubectl' >> /home/ubuntu/.bashrc

    # Installation marker
    echo "K3s installation completed" > /home/ubuntu/k3s-installed.txt
  EOF

  tags = {
    Name = "${var.project_name}-k3s"
  }
}