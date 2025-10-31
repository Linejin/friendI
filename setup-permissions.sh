#!/bin/bash

# Permission Setup Script for FriendlyI EC2 Deployment
# Fixes common permission issues in Docker and file system

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

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo_warning "이 스크립트를 root로 실행하고 있습니다."
        echo_warning "일반 사용자로 실행하는 것이 권장됩니다."
        read -p "계속하시겠습니까? (y/n): " continue_root
        if [ "$continue_root" != "y" ] && [ "$continue_root" != "Y" ]; then
            echo_info "스크립트를 종료합니다."
            exit 0
        fi
    fi
}

# Function to setup Docker permissions
setup_docker_permissions() {
    echo_info "Docker 권한 설정 중..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo_error "Docker가 설치되지 않았습니다."
        return 1
    fi
    
    # Check if docker group exists
    if ! getent group docker > /dev/null 2>&1; then
        echo_info "docker 그룹을 생성합니다..."
        sudo groupadd docker
    fi
    
    # Add current user to docker group
    if ! groups $USER | grep -q docker; then
        echo_info "현재 사용자($USER)를 docker 그룹에 추가합니다..."
        sudo usermod -aG docker $USER
        echo_success "docker 그룹에 추가되었습니다."
        echo_warning "변경사항을 적용하려면 로그아웃 후 다시 로그인하거나 'newgrp docker'를 실행하세요."
    else
        echo_success "이미 docker 그룹에 속해 있습니다."
    fi
    
    # Check Docker daemon permissions
    if [ -S /var/run/docker.sock ]; then
        echo_info "Docker 소켓 권한을 확인합니다..."
        sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
        echo_success "Docker 소켓 권한 설정 완료"
    fi
}

# Function to setup file permissions
setup_file_permissions() {
    echo_info "파일 시스템 권한 설정 중..."
    
    # Create necessary directories
    mkdir -p logs data backups
    
    # Set permissions for project directories
    chmod -R 755 .
    
    # Set executable permissions for shell scripts
    find . -name "*.sh" -type f -exec chmod +x {} \;
    echo_success "쉘 스크립트에 실행 권한을 부여했습니다."
    
    # Set permissions for log directory
    chmod -R 755 logs
    touch logs/application.log logs/monitoring.log 2>/dev/null || true
    
    # Set permissions for data directory
    chmod -R 755 data
    
    # Set permissions for backup directory
    chmod -R 755 backups
    
    echo_success "디렉터리 권한 설정 완료"
}

# Function to setup Docker Compose permissions
setup_docker_compose_permissions() {
    echo_info "Docker Compose 권한 확인 중..."
    
    if command -v docker-compose &> /dev/null; then
        echo_success "Docker Compose가 설치되어 있습니다: $(docker-compose --version)"
    elif docker compose version &> /dev/null; then
        echo_success "Docker Compose (V2)가 설치되어 있습니다: $(docker compose version)"
    else
        echo_warning "Docker Compose가 설치되지 않았습니다."
        echo_info "Docker Compose 설치를 권장합니다."
        
        read -p "Docker Compose를 설치하시겠습니까? (y/n): " install_compose
        if [ "$install_compose" = "y" ] || [ "$install_compose" = "Y" ]; then
            install_docker_compose
        fi
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    echo_info "Docker Compose 설치 중..."
    
    # Check architecture
    local arch=$(uname -m)
    case $arch in
        x86_64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            ;;
        *)
            echo_error "지원되지 않는 아키텍처: $arch"
            return 1
            ;;
    esac
    
    # Download and install Docker Compose
    local compose_url="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$arch"
    
    sudo curl -L "$compose_url" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink if needed
    if [ ! -L /usr/bin/docker-compose ]; then
        sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    
    echo_success "Docker Compose 설치 완료: $(docker-compose --version)"
}

# Function to setup log rotation
setup_log_rotation() {
    echo_info "로그 로테이션 설정 중..."
    
    # Create logrotate configuration
    local logrotate_config="/etc/logrotate.d/friendlyi"
    
    sudo tee "$logrotate_config" > /dev/null << EOF
/home/*/friendI/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 $USER $USER
}
EOF
    
    echo_success "로그 로테이션 설정 완료"
}

# Function to setup systemd service (optional)
setup_systemd_service() {
    echo_info "systemd 서비스 설정을 하시겠습니까? (y/n)"
    read -r setup_service
    
    if [ "$setup_service" != "y" ] && [ "$setup_service" != "Y" ]; then
        echo_info "systemd 서비스 설정을 건너뜁니다."
        return 0
    fi
    
    echo_info "FriendlyI systemd 서비스 설정 중..."
    
    local service_file="/etc/systemd/system/friendlyi.service"
    local project_dir=$(pwd)
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=FriendlyI Application
Requires=docker.service
After=docker.service

[Service]
Type=forking
RemainAfterExit=yes
WorkingDirectory=$project_dir
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
User=$USER
Group=docker

# Restart policy
Restart=on-failure
RestartSec=10

# Environment
Environment=COMPOSE_PROJECT_NAME=friendlyi

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable friendlyi.service
    
    echo_success "systemd 서비스가 설정되었습니다."
    echo_info "서비스 관리 명령어:"
    echo "  - 시작: sudo systemctl start friendlyi"
    echo "  - 중지: sudo systemctl stop friendlyi"
    echo "  - 재시작: sudo systemctl restart friendlyi"
    echo "  - 상태 확인: sudo systemctl status friendlyi"
}

# Function to setup firewall rules
setup_firewall_rules() {
    echo_info "방화벽 설정을 하시겠습니까? (y/n)"
    read -r setup_firewall
    
    if [ "$setup_firewall" != "y" ] && [ "$setup_firewall" != "Y" ]; then
        echo_info "방화벽 설정을 건너뜁니다."
        return 0
    fi
    
    echo_info "방화벽 규칙 설정 중..."
    
    # Check which firewall is available
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian UFW
        echo_info "UFW 방화벽 설정 중..."
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 8080/tcp
        sudo ufw --force enable
        echo_success "UFW 방화벽 규칙이 설정되었습니다."
        
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewalld
        echo_info "firewalld 방화벽 설정 중..."
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-port=8080/tcp
        sudo firewall-cmd --reload
        echo_success "firewalld 방화벽 규칙이 설정되었습니다."
        
    else
        echo_warning "지원되는 방화벽을 찾을 수 없습니다."
        echo_info "수동으로 다음 포트를 열어주세요:"
        echo "  - SSH: 22"
        echo "  - HTTP: 80"
        echo "  - Backend API: 8080"
    fi
}

# Function to verify permissions
verify_permissions() {
    echo_info "권한 설정 확인 중..."
    
    local issues=0
    
    # Check Docker permissions
    if docker ps &> /dev/null; then
        echo_success "Docker 권한이 정상적으로 설정되었습니다."
    else
        echo_error "Docker 권한에 문제가 있습니다."
        ((issues++))
    fi
    
    # Check Docker Compose permissions
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo_success "Docker Compose가 사용 가능합니다."
    else
        echo_error "Docker Compose를 사용할 수 없습니다."
        ((issues++))
    fi
    
    # Check file permissions
    if [ -r "docker-compose.yml" ] && [ -x "." ]; then
        echo_success "파일 시스템 권한이 정상적으로 설정되었습니다."
    else
        echo_error "파일 시스템 권한에 문제가 있습니다."
        ((issues++))
    fi
    
    # Check script permissions
    local script_count=0
    local executable_count=0
    for script in *.sh; do
        if [ -f "$script" ]; then
            ((script_count++))
            if [ -x "$script" ]; then
                ((executable_count++))
            fi
        fi
    done
    
    if [ "$script_count" -eq "$executable_count" ]; then
        echo_success "모든 쉘 스크립트에 실행 권한이 설정되었습니다."
    else
        echo_warning "일부 쉘 스크립트에 실행 권한이 없습니다."
    fi
    
    return $issues
}

# Function to show summary
show_summary() {
    echo_info "=== 권한 설정 요약 ==="
    
    echo_info "설정된 권한:"
    echo "  - Docker 그룹 멤버십: $(groups $USER | grep -q docker && echo "✅" || echo "❌")"
    echo "  - Docker 소켓 권한: $([ -w /var/run/docker.sock ] && echo "✅" || echo "❌")"
    echo "  - 프로젝트 디렉터리: $([ -w . ] && echo "✅" || echo "❌")"
    echo "  - 로그 디렉터리: $([ -w logs ] && echo "✅" || echo "❌")"
    echo "  - 데이터 디렉터리: $([ -w data ] && echo "✅" || echo "❌")"
    
    echo
    echo_info "중요 알림:"
    echo "  - Docker 그룹 변경 사항을 적용하려면 로그아웃 후 다시 로그인하세요."
    echo "  - 또는 'newgrp docker' 명령을 실행하세요."
    echo "  - AWS EC2 보안 그룹에서 포트 80, 8080을 열어야 합니다."
    
    echo
    echo_info "테스트 명령어:"
    echo "  - Docker 테스트: docker ps"
    echo "  - Docker Compose 테스트: docker-compose --version"
    echo "  - 배포 테스트: ./deploy-initial.sh"
}

# Main function
main() {
    echo_info "FriendlyI 권한 설정을 시작합니다..."
    
    check_root
    setup_docker_permissions
    setup_file_permissions
    setup_docker_compose_permissions
    setup_log_rotation
    
    # Optional services
    setup_systemd_service
    setup_firewall_rules
    
    echo
    echo_info "권한 설정 확인 중..."
    if verify_permissions; then
        echo_success "모든 권한이 올바르게 설정되었습니다!"
    else
        echo_warning "일부 권한에 문제가 있습니다. 수동으로 확인해 주세요."
    fi
    
    show_summary
    
    echo
    echo_success "🎉 권한 설정이 완료되었습니다!"
    echo_info "이제 './deploy-initial.sh'를 실행하여 애플리케이션을 배포할 수 있습니다."
}

# Handle script arguments
case "${1:-}" in
    "--docker-only")
        setup_docker_permissions
        ;;
    "--files-only")
        setup_file_permissions
        ;;
    "--verify")
        verify_permissions
        ;;
    "--help"|"-h")
        echo "사용법: $0 [옵션]"
        echo "옵션:"
        echo "  --docker-only   Docker 권한만 설정"
        echo "  --files-only    파일 권한만 설정"
        echo "  --verify        권한 설정 확인만 실행"
        echo "  --help, -h      이 도움말 표시"
        ;;
    *)
        main "$@"
        ;;
esac
