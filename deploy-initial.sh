#!/bin/bash

# FriendlyI Initial Deployment Script for AWS EC2
# Optimized for t3.small instance (2GB RAM)

set -e
trap 'echo "❌ Error occurred on line $LINENO. Exit code: $?" >&2' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_NAME="friendlyi"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

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

# Function to cleanup disk space
cleanup_disk_space() {
    echo_info "디스크 공간 정리 시작..."
    
    # Clean package manager cache
    if command -v yum &> /dev/null; then
        echo_info "YUM 캐시 정리 중..."
        sudo yum clean all 2>/dev/null || true
    elif command -v apt-get &> /dev/null; then
        echo_info "APT 캐시 정리 중..."
        sudo apt-get clean 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
    fi
    
    # Clean Docker system (if Docker is installed)
    if command -v docker &> /dev/null; then
        echo_info "Docker 시스템 정리 중..."
        sudo docker system prune -a -f 2>/dev/null || true
        sudo docker volume prune -f 2>/dev/null || true
    fi
    
    # Clean temporary files
    echo_info "임시 파일 정리 중..."
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
    sudo find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # Clean log files (keep recent ones)
    echo_info "오래된 로그 파일 정리 중..."
    sudo find /var/log -name "*.log" -type f -size +100M -delete 2>/dev/null || true
    sudo find /var/log -name "*.log.*" -type f -mtime +30 -delete 2>/dev/null || true
    
    # Check space after cleanup
    local new_available=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    echo_success "정리 완료. 사용 가능한 공간: ${new_available}GB"
    
    if [ "$new_available" -lt 3 ]; then
        echo_error "정리 후에도 공간이 부족합니다. EC2 볼륨 확장이 필요합니다."
        echo_info "AWS 콘솔에서 EBS 볼륨을 확장하거나 더 큰 인스턴스를 사용해주세요."
        exit 1
    fi
}

# Function to check system requirements
check_system_requirements() {
    echo_info "시스템 요구사항 확인 중..."
    
    # Check available memory
    AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$AVAILABLE_MEMORY" -lt 300 ]; then
        echo_error "메모리가 심각하게 부족합니다: ${AVAILABLE_MEMORY}MB"
        echo_info "최소 300MB의 여유 메모리가 필요합니다."
        exit 1
    elif [ "$AVAILABLE_MEMORY" -lt 800 ]; then
        echo_warning "사용 가능한 메모리가 부족합니다: ${AVAILABLE_MEMORY}MB"
        echo_info "스왑 파일 생성을 권장합니다."
        
        if [ ! -f /swapfile ] && [ ! -f /swap.img ]; then
            echo_info "스왑 파일을 생성하시겠습니까? (y/n)"
            read -r create_swap
            if [ "$create_swap" = "y" ] || [ "$create_swap" = "Y" ]; then
                # Create smaller swap file for limited disk space
                echo_info "1GB 스왑 파일 생성 중..."
                sudo fallocate -l 1G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
                sudo chmod 600 /swapfile
                sudo mkswap /swapfile
                sudo swapon /swapfile
                echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
                echo_success "1GB 스왩 파일이 생성되었습니다."
            fi
        else
            echo_info "기존 스왑 파일이 감지되었습니다."
        fi
    fi
    
    # Check disk space
    AVAILABLE_DISK=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_DISK" -lt 3 ]; then
        echo_error "디스크 공간이 부족합니다: ${AVAILABLE_DISK}GB"
        echo_info "최소 3GB의 여유 공간이 필요합니다."
        echo_info "디스크 정리를 시도하시겠습니까? (y/n)"
        read -r cleanup_disk
        if [ "$cleanup_disk" = "y" ] || [ "$cleanup_disk" = "Y" ]; then
            cleanup_disk_space
        else
            exit 1
        fi
    elif [ "$AVAILABLE_DISK" -lt 5 ]; then
        echo_warning "디스크 공간이 제한적입니다: ${AVAILABLE_DISK}GB"
        echo_info "배포 중 공간 부족이 발생할 수 있습니다. 계속하시겠습니까? (y/n)"
        read -r continue_deploy
        if [ "$continue_deploy" != "y" ] && [ "$continue_deploy" != "Y" ]; then
            exit 1
        fi
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo_error "Docker가 설치되지 않았습니다."
        echo_info "Docker 설치: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo_error "Docker Compose가 설치되지 않았습니다."
        echo_info "Docker Compose 설치: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    echo_success "시스템 요구사항 확인 완료"
}

# Function to create environment file
create_env_file() {
    echo_info "환경 설정 파일 생성 중..."
    
    cat > "$ENV_FILE" << EOF
# FriendlyI Environment Configuration
COMPOSE_PROJECT_NAME=$PROJECT_NAME

# Java/Spring Boot Configuration
JAVA_OPTS=-Xmx768m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport
SPRING_PROFILES_ACTIVE=docker

# Database Configuration (H2 for Docker)
DB_USERNAME=sa
DB_PASSWORD=
H2_CONSOLE_ENABLED=false
H2_CONSOLE_WEB_ALLOW_OTHERS=false

# Security Configuration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=friendlyi2025!
JWT_SECRET=FriendlyI-Production-JWT-Secret-Key-2025-AWS-EC2-Deployment!#$
JWT_EXPIRATION=86400

# Application Configuration
SERVER_PORT=8080
FRONTEND_PORT=80

# Timezone
TZ=Asia/Seoul

# Log Level
LOG_LEVEL=INFO
EOF
    
    echo_success "환경 설정 파일이 생성되었습니다: $ENV_FILE"
}

# Function to create directories
create_directories() {
    echo_info "필요한 디렉터리 생성 중..."
    
    mkdir -p logs
    mkdir -p data
    mkdir -p backups
    
    echo_success "디렉터리 생성 완료"
}

# Function to pull latest changes
pull_latest_code() {
    echo_info "최신 코드 가져오는 중..."
    
    if [ -d ".git" ]; then
        git pull origin master
        echo_success "최신 코드 업데이트 완료"
    else
        echo_warning "Git 저장소가 아닙니다. 코드 업데이트를 건너뜁니다."
    fi
}

# Function to cleanup old containers and images
cleanup_docker() {
    echo_info "기존 Docker 리소스 정리 중..."
    
    # Stop and remove existing containers
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Remove unused images, containers, and volumes
    docker system prune -f
    
    echo_success "Docker 리소스 정리 완료"
}

# Function to build and start services
deploy_services() {
    echo_info "서비스 빌드 및 시작 중..."
    
    # Check available memory before build and select appropriate compose file
    local available_mem=$(free -m | awk 'NR==2{print $7}')
    local total_mem=$(free -m | awk 'NR==2{print $2}')
    local compose_file="docker-compose.yml"
    
    if [ "$total_mem" -lt 1000 ]; then
        echo_warning "극소형 환경 감지 (${total_mem}MB). 최소 설정을 사용합니다."
        compose_file="docker-compose.minimal.yml"
    elif [ "$total_mem" -lt 3000 ]; then
        echo_warning "저사양 환경 감지 (${total_mem}MB). 최적화된 설정을 사용합니다."
        compose_file="docker-compose.lowmem.yml"
    fi
    
    echo_info "선택된 구성: $compose_file"
    
    if [ "$available_mem" -lt 400 ]; then
        echo_warning "매우 제한적인 메모리 환경입니다. 최적화된 순차 빌드를 실행합니다."
        
        # Force garbage collection and clear cache before build
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        
        # Build with minimal memory usage
        echo_info "백엔드 이미지 빌드 중... (메모리 최적화 모드)"
        DOCKER_BUILDKIT=0 docker-compose -f "$compose_file" build --no-cache --memory=512m backend || {
            echo_error "백엔드 빌드 실패"
            return 1
        }
        
        # Clear build cache between builds
        docker builder prune -f 2>/dev/null || true
        
        # Build frontend
        echo_info "프론트엔드 이미지 빌드 중... (메모리 최적화 모드)"
        DOCKER_BUILDKIT=0 docker-compose -f "$compose_file" build --no-cache --memory=256m frontend || {
            echo_error "프론트엔드 빌드 실패"
            return 1
        }
    elif [ "$available_mem" -lt 800 ]; then
        echo_warning "메모리 부족으로 인해 순차 빌드를 실행합니다."
        
        # Build backend first
        echo_info "백엔드 이미지 빌드 중..."
        docker-compose -f "$compose_file" build --no-cache backend || {
            echo_error "백엔드 빌드 실패"
            return 1
        }
        
        # Build frontend
        echo_info "프론트엔드 이미지 빌드 중..."
        docker-compose -f "$compose_file" build --no-cache frontend || {
            echo_error "프론트엔드 빌드 실패"
            return 1
        }
    else
        # Build images with no cache for fresh deployment
        echo_info "Docker 이미지 빌드 중... (시간이 걸릴 수 있습니다)"
        docker-compose -f "$compose_file" build --no-cache --parallel || {
            echo_error "Docker 이미지 빌드 실패"
            return 1
        }
    fi
    
    # Store selected compose file for later use
    echo "$compose_file" > .compose_file_used
    
    # Start services with the selected compose file
    echo_info "서비스 시작 중..."
    local selected_compose_file="${compose_file:-docker-compose.yml}"
    docker-compose -f "$selected_compose_file" up -d || {
        echo_error "서비스 시작 실패"
        return 1
    }
    
    echo_success "서비스 배포 완료"
}

# Function to wait for services to be healthy
wait_for_services() {
    echo_info "서비스 상태 확인 중..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps | grep -q "healthy"; then
            echo_success "서비스가 정상적으로 시작되었습니다!"
            return 0
        fi
        
        echo_info "서비스 시작 대기 중... ($attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    echo_warning "서비스 상태 확인 시간 초과. 수동으로 확인해 주세요."
    docker-compose ps
}

# Function to show deployment info
show_deployment_info() {
    echo_success "=== 배포 완료 ==="
    echo_info "서비스 URL:"
    
    # Get public IP
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/ || echo "확인 불가")
    
    echo "  - Frontend: http://$PUBLIC_IP"
    echo "  - Backend API: http://$PUBLIC_IP:8080"
    echo "  - Health Check: http://$PUBLIC_IP:8080/actuator/health"
    
    if grep -q "spring.h2.console.enabled=true" backend/backend/src/main/resources/application-docker.properties; then
        echo "  - H2 Database Console: http://$PUBLIC_IP:8080/h2-console"
    fi
    
    echo
    echo_info "유용한 명령어:"
    echo "  - 서비스 상태 확인: docker-compose ps"
    echo "  - 로그 확인: docker-compose logs -f"
    echo "  - 서비스 재시작: docker-compose restart"
    echo "  - 서비스 중지: docker-compose down"
    echo
    echo_warning "보안 그룹 설정을 확인해 주세요:"
    echo "  - HTTP (80) 포트 열기"
    echo "  - Custom TCP (8080) 포트 열기"
}

# Main deployment function
main() {
    echo_info "FriendlyI 초기 배포를 시작합니다..."
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    check_system_requirements
    create_env_file
    create_directories
    pull_latest_code
    cleanup_docker
    deploy_services
    wait_for_services
    show_deployment_info
    
    echo_success "🎉 FriendlyI 배포가 완료되었습니다!"
}

# Run main function
main "$@"
