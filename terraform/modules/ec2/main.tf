# ============================================================
# NOVATECH - EC2 K3S SERVER
# Ubuntu 24.04 ARM64
# ============================================================

# ============================================================
# DATA - UBUNTU 24.04 ARM64
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

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Kubernetes API (VPC only)
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # K3s Flannel VXLAN (VPC only)
  ingress {
    description = "K3s Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTP (VPC only)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Grafana (NodePort)
  ingress {
    description = "Grafana"
    from_port   = 30000
    to_port     = 30000
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_allowed_cidr]
  }

  # Prometheus (NodePort)
  ingress {
    description = "Prometheus"
    from_port   = 30090
    to_port     = 30090
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_allowed_cidr]
  }

  # Node Exporter (VPC only)
  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Kubelet (VPC only)
  ingress {
    description = "Kubelet"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Outbound
  egress {
    description = "Internet outbound"
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
  subnet_id     = var.public_subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.k3s.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
    tags = {
      Name = "${var.project_name}-k3s-root"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOF
#!/bin/bash
set -Eeuo pipefail
LOG_FILE="/var/log/novatech-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "NOVATECH K3S INSTALLATION"
echo "============================================================"
date
export DEBIAN_FRONTEND=noninteractive

# --- ERROR HANDLER ---
trap 'echo "ERROR at line $LINENO"; journalctl -u k3s --no-pager -n 100 || true' ERR

# --- SYSTEM PREP ---
echo "============================================================"
echo "SYSTEM PREPARATION"
echo "============================================================"
apt-get update -y
apt-get install -y curl ca-certificates apt-transport-https jq unzip socat conntrack iptables bash-completion
echo "System dependencies installed."

# --- SWAP (for t4g.small) ---
echo "============================================================"
echo "CONFIGURING SWAP"
echo "============================================================"
if ! swapon --show | grep -q "/swapfile"; then
  if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
  fi
  swapon /swapfile
fi
if ! grep -q "^/swapfile" /etc/fstab; then
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi
echo "Swap configured."
free -h

# --- KERNEL / NETWORK ---
echo "============================================================"
echo "CONFIGURING KUBERNETES NETWORKING"
echo "============================================================"
cat > /etc/modules-load.d/k3s.conf <<'MODULES'
overlay
br_netfilter
MODULES
modprobe overlay || true
modprobe br_netfilter || true

cat > /etc/sysctl.d/99-k3s.conf <<'SYSCTL'
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
SYSCTL
sysctl --system

# --- DISABLE UFW ---
if command -v ufw >/dev/null 2>&1; then
  ufw disable || true
fi

# --- HOSTNAME ---
hostnamectl set-hostname "$(hostname)"

# --- INSTALL K3S ---
echo "============================================================"
echo "INSTALLING K3S"
echo "============================================================"
if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644 --disable=traefik" \
    sh -
else
  echo "K3s already installed."
fi
systemctl enable k3s
systemctl restart k3s

# --- KUBECONFIG ---
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# --- WAIT FOR K3S API ---
echo "============================================================"
echo "WAITING FOR K3S API"
echo "============================================================"
K3S_READY=false
for i in $(seq 1 60); do
  if k3s kubectl get nodes >/dev/null 2>&1; then
    echo "K3s API is ready."
    K3S_READY=true
    break
  fi
  echo "Waiting for K3s... attempt $i/60"
  sleep 5
done
if [ "$K3S_READY" != "true" ]; then
  echo "ERROR: K3s API did not become ready."
  systemctl status k3s --no-pager || true
  journalctl -u k3s --no-pager -n 200 || true
  exit 1
fi
k3s kubectl get nodes -o wide

# --- WAIT FOR NODE READY ---
echo "============================================================"
echo "WAITING FOR KUBERNETES NODE"
echo "============================================================"
NODE_READY=false
for i in $(seq 1 60); do
  if k3s kubectl get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" {found=1} END {exit !found}'; then
    echo "Kubernetes node is Ready."
    NODE_READY=true
    break
  fi
  echo "Node not Ready yet... attempt $i/60"
  sleep 5
done
if [ "$NODE_READY" != "true" ]; then
  echo "WARNING: Kubernetes node is not Ready."
  k3s kubectl get nodes -o wide || true
  k3s kubectl describe node || true
fi

# --- KUBECTL FOR UBUNTU ---
echo "============================================================"
echo "CONFIGURING KUBECTL"
echo "============================================================"
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config
if ! grep -q "KUBECONFIG=/home/ubuntu/.kube/config" /home/ubuntu/.bashrc; then
  echo 'export KUBECONFIG=/home/ubuntu/.kube/config' >> /home/ubuntu/.bashrc
fi
if ! grep -q "alias k=kubectl" /home/ubuntu/.bashrc; then
  echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
fi

# --- INSTALL HELM ---
echo "============================================================"
echo "INSTALLING HELM"
echo "============================================================"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm version

# --- MONITORING NAMESPACE ---
echo "============================================================"
echo "CREATING MONITORING NAMESPACE"
echo "============================================================"
k3s kubectl create namespace monitoring --dry-run=client -o yaml | k3s kubectl apply -f -

# --- PROMETHEUS HELM REPO ---
echo "============================================================"
echo "CONFIGURING PROMETHEUS HELM REPOSITORY"
echo "============================================================"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update

# --- DOWNLOAD DASHBOARD 15757 JSON ---
echo "============================================================"
echo "DOWNLOADING GRAFANA DASHBOARD 15757"
echo "============================================================"
mkdir -p /tmp/dashboards
curl -s https://raw.githubusercontent.com/grafana/helm-charts/main/charts/grafana/dashboards/kubernetes-15757.json -o /tmp/dashboards/15757.json

# --- INSTALL KUBE-PROMETHEUS-STACK ---
echo "============================================================"
echo "INSTALLING KUBE-PROMETHEUS-STACK"
echo "============================================================"
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.enabled=true \
  --set alertmanager.enabled=true \
  --set nodeExporter.enabled=true \
  --set kubeStateMetrics.enabled=true \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30000 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set alertmanager.service.type=ClusterIP \
  --set prometheus.prometheusSpec.retention=6h \
  --set prometheus.prometheusSpec.scrapeInterval=30s \
  --set prometheus.prometheusSpec.evaluationInterval=30s \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.cpu=700m \
  --set prometheus.prometheusSpec.resources.limits.memory=768Mi \
  --set grafana.resources.requests.cpu=100m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.cpu=500m \
  --set grafana.resources.limits.memory=384Mi \
  --set alertmanager.alertmanagerSpec.resources.requests.cpu=25m \
  --set alertmanager.alertmanagerSpec.resources.requests.memory=32Mi \
  --set alertmanager.alertmanagerSpec.resources.limits.cpu=100m \
  --set alertmanager.alertmanagerSpec.resources.limits.memory=128Mi \
  --set kubeStateMetrics.resources.requests.cpu=20m \
  --set kubeStateMetrics.resources.requests.memory=32Mi \
  --set kubeStateMetrics.resources.limits.cpu=100m \
  --set kubeStateMetrics.resources.limits.memory=128Mi \
  --set prometheus-node-exporter.resources.requests.cpu=20m \
  --set prometheus-node-exporter.resources.requests.memory=24Mi \
  --set prometheus-node-exporter.resources.limits.cpu=100m \
  --set prometheus-node-exporter.resources.limits.memory=64Mi \
  --set grafana.dashboards.default.15757.json="$(base64 -w 0 /tmp/dashboards/15757.json)" \
  --wait=false

echo "kube-prometheus-stack installation submitted."

# --- WAIT FOR MONITORING PODS ---
echo "============================================================"
echo "WAITING FOR MONITORING PODS"
echo "============================================================"
sleep 60

# --- MONITORING STATUS ---
echo "============================================================"
echo "MONITORING STATUS"
echo "============================================================"
k3s kubectl get pods -n monitoring -o wide || true
k3s kubectl get svc -n monitoring || true

# --- CREATE MONITORING STATUS SCRIPT ---
echo "============================================================"
echo "CREATING MONITORING STATUS SCRIPT"
echo "============================================================"
cat > /usr/local/bin/novatech-monitoring-status.sh <<'SCRIPT'
#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "============================================================"
echo "NOVATECH MONITORING STATUS"
echo "============================================================"
echo
echo "SYSTEM:"
free -h
echo
echo "LOAD:"
uptime
echo
echo "K3s:"
kubectl get nodes -o wide
echo
echo "K3s system pods:"
kubectl get pods -n kube-system -o wide
echo
echo "Monitoring pods:"
kubectl get pods -n monitoring -o wide
echo
echo "Monitoring services:"
kubectl get svc -n monitoring
echo
echo "Deployments:"
kubectl get deployments -n monitoring
echo
echo "StatefulSets:"
kubectl get statefulsets -n monitoring
echo
echo "DaemonSets:"
kubectl get daemonsets -n monitoring
echo
echo "Resource usage:"
kubectl top nodes 2>/dev/null || true
echo
echo "Monitoring resource usage:"
kubectl top pods -n monitoring 2>/dev/null || true
SCRIPT
chmod +x /usr/local/bin/novatech-monitoring-status.sh

# --- INSTALLATION MARKER ---
cat > /home/ubuntu/k3s-installed.txt <<'MARKER'
NOVATECH K3S INSTALLATION

K3s installed successfully.
Helm installed successfully.
kube-prometheus-stack installation submitted.

Grafana:
NodePort 30000 (http://<PUBLIC_IP>:30000)
Prometheus:
NodePort 30090 (http://<PUBLIC_IP>:30090)

Check status:
sudo /usr/local/bin/novatech-monitoring-status.sh

Useful commands:
kubectl get nodes -o wide
kubectl get pods -A
kubectl top nodes
kubectl top pods -A
kubectl get svc -n monitoring
MARKER
chown ubuntu:ubuntu /home/ubuntu/k3s-installed.txt

# --- FINAL STATUS ---
echo "============================================================"
echo "FINAL K3S STATUS"
echo "============================================================"
k3s kubectl get nodes -o wide || true
echo
echo "============================================================"
echo "KUBE-SYSTEM"
echo "============================================================"
k3s kubectl get pods -n kube-system -o wide || true
echo
echo "============================================================"
echo "MONITORING"
echo "============================================================"
k3s kubectl get pods -n monitoring -o wide || true
echo
echo "============================================================"
echo "SERVICES"
echo "============================================================"
k3s kubectl get svc -n monitoring || true
echo
echo "============================================================"
echo "NOVATECH INSTALLATION COMPLETE"
echo "============================================================"
date
EOF

  tags = {
    Name = "${var.project_name}-k3s"
  }
}