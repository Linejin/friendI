#!/bin/bash

# EC2 Initial Setup Script for FriendlyI
# Run this script first on a fresh EC2 instance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo_error "OS 감지에 실패했습니다."
        exit 1
    fi
    
    echo_info "감지된 OS: $OS $VERSION"
}

# Function to update system
update_system() {
    echo_info "시스템 업데이트 중..."
    
    case $OS in
        "ubuntu"|"debian")
            sudo apt-get update -y
            sudo apt-get upgrade -y
            sudo apt-get install -y curl wget git unzip htop
            ;;
        "amzn"|"rhel"|"centos")
            sudo yum update -y
            sudo yum install -y curl wget git unzip htop
            ;;
        *)
            echo_warning "지원되지 않는 OS입니다. 수동으로 패키지를 설치해 주세요."
            ;;
    esac
    
    echo_success "시스템 업데이트 완료"
}

# Function to install Docker
install_docker() {
    echo_info "Docker 설치 중..."
    
    if command -v docker &> /dev/null; then
        echo_success "Docker가 이미 설치되어 있습니다: $(docker --version)"
        return 0
    fi
    
    case $OS in
        "ubuntu"|"debian")
            # Docker 공식 설치 스크립트 사용
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            rm get-docker.sh
            ;;
        "amzn")
            # Amazon Linux 2
            sudo yum install -y docker
            ;;
        "rhel"|"centos")
            # RHEL/CentOS
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io
            ;;
        *)
            echo_error "지원되지 않는 OS입니다."
            exit 1
            ;;
    esac
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    echo_success "Docker 설치 완료"
}

# Function to install Docker Compose
install_docker_compose() {
    echo_info "Docker Compose 설치 중..."
    
    if command -v docker-compose &> /dev/null; then
        echo_success "Docker Compose가 이미 설치되어 있습니다: $(docker-compose --version)"
        return 0
    fi
    
    # Get latest version
    local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    # Download Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Make executable
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    echo_success "Docker Compose 설치 완료: $(docker-compose --version)"
}

# Function to setup swap (for t3.small instances)
setup_swap() {
    echo_info "스왑 메모리 설정 중..."
    
    # Check if swap already exists
    if swapon --show | grep -q "/swapfile"; then
        echo_success "스왑이 이미 설정되어 있습니다."
        return 0
    fi
    
    # Create 2GB swap file
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # Make swap permanent
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    
    # Optimize swappiness for server environment
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    
    echo_success "2GB 스왑 메모리 설정 완료"
}

# Function to configure firewall
configure_firewall() {
    echo_info "방화벽 설정 중..."
    
    case $OS in
        "ubuntu"|"debian")
            if command -v ufw &> /dev/null; then
                sudo ufw allow ssh
                sudo ufw allow 80/tcp
                sudo ufw allow 8080/tcp
                sudo ufw --force enable
                echo_success "UFW 방화벽 설정 완료"
            fi
            ;;
        "amzn"|"rhel"|"centos")
            if command -v firewall-cmd &> /dev/null; then
                sudo firewall-cmd --permanent --add-service=ssh
                sudo firewall-cmd --permanent --add-service=http
                sudo firewall-cmd --permanent --add-port=8080/tcp
                sudo firewall-cmd --reload
                echo_success "firewalld 방화벽 설정 완료"
            fi
            ;;
    esac
    
    echo_warning "AWS 보안 그룹에서도 다음 포트를 열어야 합니다:"
    echo "  - SSH (22)"
    echo "  - HTTP (80)"
    echo "  - Custom TCP (8080)"
}

# Function to optimize system for containers
optimize_system() {
    echo_info "시스템 최적화 중..."
    
    # Increase file descriptor limits
    echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf
    echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf
    
    # Optimize kernel parameters for containers
    sudo tee -a /etc/sysctl.conf > /dev/null << EOF
# Container optimizations
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
vm.max_map_count = 262144
fs.file-max = 2097152
EOF
    
    # Apply sysctl changes
    sudo sysctl -p
    
    echo_success "시스템 최적화 완료"
}

# Function to setup monitoring tools
setup_monitoring() {
    echo_info "모니터링 도구 설정 중..."
    
    case $OS in
        "ubuntu"|"debian")
            sudo apt-get install -y htop iotop nethogs ncdu
            ;;
        "amzn"|"rhel"|"centos")
            sudo yum install -y htop iotop nethogs ncdu
            ;;
    esac
    
    echo_success "모니터링 도구 설치 완료"
}

# Function to create project directory
setup_project_directory() {
    echo_info "프로젝트 디렉터리 설정 중..."
    
    local project_dir="/home/$USER/friendI"
    
    if [ ! -d "$project_dir" ]; then
        mkdir -p "$project_dir"
        cd "$project_dir"
        
        # Initialize basic structure
        mkdir -p logs data backups
        
        echo_success "프로젝트 디렉터리 생성: $project_dir"
    else
        echo_success "프로젝트 디렉터리가 이미 존재합니다: $project_dir"
    fi
}

# Function to show next steps
show_next_steps() {
    echo_success "=== EC2 초기 설정 완료 ==="
    
    echo_info "다음 단계:"
    echo "1. 터미널을 다시 시작하거나 'newgrp docker'를 실행하세요"
    echo "2. 프로젝트를 클론하세요:"
    echo "   git clone https://github.com/Linejin/friendI.git"
    echo "   cd friendI"
    echo "3. 권한을 설정하세요:"
    echo "   chmod +x *.sh"
    echo "   ./setup-permissions.sh"
    echo "4. 애플리케이션을 배포하세요:"
    echo "   ./deploy-initial.sh"
    
    echo
    echo_info "AWS 보안 그룹 설정을 확인하세요:"
    echo "  - Type: SSH, Port: 22, Source: Your IP"
    echo "  - Type: HTTP, Port: 80, Source: 0.0.0.0/0"
    echo "  - Type: Custom TCP, Port: 8080, Source: 0.0.0.0/0"
    
    echo
    echo_info "유용한 명령어:"
    echo "  - 시스템 상태 확인: htop"
    echo "  - Docker 상태 확인: docker ps"
    echo "  - 로그 확인: journalctl -u docker.service"
    echo "  - 디스크 사용량: df -h"
    echo "  - 메모리 사용량: free -h"
}

# Main function
main() {
    echo_info "FriendlyI EC2 초기 설정을 시작합니다..."
    
    detect_os
    update_system
    install_docker
    install_docker_compose
    setup_swap
    configure_firewall
    optimize_system
    setup_monitoring
    setup_project_directory
    
    show_next_steps
    
    echo_success "🎉 EC2 초기 설정이 완료되었습니다!"
    echo_warning "변경사항을 적용하려면 시스템을 재부팅하는 것을 권장합니다."
}

# Run main function
main "$@"