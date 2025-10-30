#!/bin/bash

# EC2 Small Instance Setup and Optimization Script
# For t3.small (2GB RAM, 2 vCPU)

echo "🚀 Setting up Friendly-I on EC2 Small Instance..."

# System requirements check
echo "📊 Checking system resources..."
echo "Total Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "Available Memory: $(free -h | grep '^Mem:' | awk '{print $7}')"
echo "CPU Cores: $(nproc)"
echo "Disk Space: $(df -h / | tail -1 | awk '{print $4}') available"

# Docker system optimization
echo "🐳 Optimizing Docker for small instance..."

# Set Docker daemon configuration for resource constraints
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "memlock": {
      "Hard": -1,
      "Name": "memlock",
      "Soft": -1
    },
    "nofile": {
      "Hard": 65536,
      "Name": "nofile",
      "Soft": 65536
    }
  }
}
EOF

# Restart Docker service
sudo systemctl restart docker

# System optimization
echo "⚙️ Applying system optimizations..."

# Increase swap if needed (for 2GB instance)
if [ $(free | grep Swap | awk '{print $2}') -eq 0 ]; then
    echo "Creating swap file (1GB)..."
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Optimize kernel parameters for containers
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
# Container optimization for small instance
vm.swappiness=10
vm.overcommit_memory=1
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.ip_local_port_range=1024 65535
EOF

sudo sysctl -p

# Set up environment
echo "📁 Setting up project environment..."
cp .env.small .env

# Create required directories
mkdir -p logs uploads

# Set proper permissions
chmod +x scripts/*.sh

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create systemd service for auto-start
echo "🔄 Creating systemd service..."
sudo tee /etc/systemd/system/friendly-i.service > /dev/null <<EOF
[Unit]
Description=Friendly-I Backend Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/local/bin/docker-compose -f docker-compose.small.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.small.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable friendly-i.service

echo "✅ EC2 Small instance setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env file with your actual values"
echo "2. Run: make small-up"
echo "3. Monitor with: make small-monitor"
echo ""
echo "🔗 Access your application:"
echo "   Health Check: http://your-ec2-ip:8080/actuator/health"
echo "   API Docs: http://your-ec2-ip:8080/swagger-ui/index.html"
echo ""
echo "📊 Monitor resources:"
echo "   make small-monitor"
echo "   docker stats"