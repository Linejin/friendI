#!/bin/bash
# EC2 FriendlyI Auto Deployment Script
# Usage: ./auto-deploy.sh

set -e  # 오류 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 배너 출력
print_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "    🚀 FriendlyI Auto Deployment Script"
    echo "    📦 EC2 Small Instance Optimized"
    echo "=============================================="
    echo -e "${NC}"
}

# 시스템 정보 확인
check_system() {
    log_info "시스템 정보 확인 중..."
    
    # 메모리 확인
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    log_info "총 메모리: ${TOTAL_MEM}MB"
    
    if [ $TOTAL_MEM -lt 1500 ]; then
        log_warning "메모리가 부족합니다. EC2 Small 최적화 모드로 실행됩니다."
        USE_SMALL_CONFIG=true
    else
        USE_SMALL_CONFIG=false
    fi
    
    # Docker 확인 및 설치
    if ! command -v docker &> /dev/null; then
        log_warning "Docker가 설치되지 않았습니다. 설치를 진행합니다..."
        install_docker
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose가 설치되지 않았습니다. 설치를 진행합니다..."
        install_docker_compose
    fi
    
    log_success "시스템 확인 완료"
}

# Docker 설치
install_docker() {
    log_info "Docker 설치 중..."
    
    # Amazon Linux 2 또는 CentOS/RHEL
    if command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    # Ubuntu/Debian
    elif command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    else
        log_error "지원되지 않는 운영체제입니다."
        exit 1
    fi
    
    log_success "Docker 설치 완료"
    log_warning "Docker 그룹 권한 적용을 위해 다시 로그인하거나 'newgrp docker' 명령을 실행하세요."
}

# Docker Compose 설치
install_docker_compose() {
    log_info "Docker Compose 설치 중..."
    
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # 심볼릭 링크 생성 (PATH에서 찾을 수 있도록)
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose 설치 완료"
}

# Git 저장소 클론 또는 업데이트
setup_repository() {
    log_info "저장소 설정 중..."
    
    REPO_URL="https://github.com/Linejin/friendI.git"
    PROJECT_DIR="friendI"
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log_info "저장소 클론 중..."
        git clone $REPO_URL
        cd $PROJECT_DIR
    else
        log_info "기존 저장소 업데이트 중..."
        cd $PROJECT_DIR
        git fetch origin
        git pull origin master || git pull origin main
    fi
    
    # backend 디렉토리로 이동
    cd backend
    
    log_success "저장소 설정 완료"
}

# Docker 시스템 정리
cleanup_docker() {
    log_info "Docker 시스템 정리 중..."
    
    # 기존 컨테이너 중지 및 제거
    if [ "$USE_SMALL_CONFIG" = true ]; then
        docker-compose -f docker-compose.small.yml down 2>/dev/null || true
    else
        docker-compose down 2>/dev/null || true
    fi
    
    # 사용하지 않는 이미지 정리 (공간 절약)
    docker system prune -f
    
    log_success "Docker 정리 완료"
}

# 환경 설정
setup_environment() {
    log_info "환경 설정 중..."
    
    # 환경 파일 설정
    if [ "$USE_SMALL_CONFIG" = true ]; then
        if [ -f ".env.small" ]; then
            cp .env.small .env
            log_info "EC2 Small 최적화 환경 설정 적용"
        else
            log_warning ".env.small 파일이 없습니다. 기본 설정을 사용합니다."
            cp .env.example .env 2>/dev/null || create_default_env
        fi
    else
        if [ ! -f ".env" ]; then
            cp .env.example .env 2>/dev/null || create_default_env
        fi
    fi
    
    # 보안: 기본 비밀번호 변경 요청
    if grep -q "your_secure_" .env 2>/dev/null; then
        log_warning "⚠️  보안 주의: .env 파일의 기본 비밀번호를 변경하세요!"
        log_info "   - DB_PASSWORD"
        log_info "   - REDIS_PASSWORD"
        log_info "   - JWT_SECRET"
        log_info "   - ADMIN_PASSWORD"
    fi
    
    log_success "환경 설정 완료"
}

# 기본 환경 파일 생성
create_default_env() {
    log_info "기본 환경 파일 생성 중..."
    
    cat > .env << EOF
# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=friendlyi
DB_USERNAME=friendlyi_user
DB_PASSWORD=change_me_$(date +%s)

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=change_me_$(date +%s)

# JWT Configuration
JWT_SECRET=friendly-i-secret-key-$(date +%s)-change-this-in-production
JWT_EXPIRATION=86400000
JWT_REFRESH_EXPIRATION=604800000

# Spring Profile
SPRING_PROFILES_ACTIVE=prod

# Server Configuration
SERVER_PORT=8080

# JVM Configuration (EC2 Small optimized)
JAVA_OPTS=-server -Xms128m -Xmx512m -XX:+UseSerialGC
EOF
    
    log_success "기본 환경 파일 생성 완료"
}

# 애플리케이션 빌드 및 배포
deploy_application() {
    log_info "애플리케이션 배포 중..."
    
    # Docker Compose 파일 선택
    if [ "$USE_SMALL_CONFIG" = true ] && [ -f "docker-compose.small.yml" ]; then
        COMPOSE_FILE="docker-compose.small.yml"
        log_info "EC2 Small 최적화 구성으로 배포"
    else
        COMPOSE_FILE="docker-compose.yml"
        log_info "표준 구성으로 배포"
    fi
    
    # 이미지 빌드 및 컨테이너 시작
    log_info "Docker 이미지 빌드 중..."
    docker-compose -f $COMPOSE_FILE build --no-cache
    
    log_info "컨테이너 시작 중..."
    docker-compose -f $COMPOSE_FILE up -d
    
    log_success "애플리케이션 배포 완료"
}

# 배포 상태 확인
check_deployment() {
    log_info "배포 상태 확인 중..."
    
    # 컨테이너 상태 확인
    if [ "$USE_SMALL_CONFIG" = true ] && [ -f "docker-compose.small.yml" ]; then
        COMPOSE_FILE="docker-compose.small.yml"
    else
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    log_info "서비스 시작 대기 중... (30초)"
    sleep 30  # 서비스 시작 대기
    
    # 컨테이너 상태 출력
    echo
    log_info "컨테이너 상태:"
    docker-compose -f $COMPOSE_FILE ps
    
    # 헬스체크
    echo
    log_info "애플리케이션 헬스체크 중..."
    
    # 최대 60초 동안 헬스체크 시도
    for i in {1..12}; do
        if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
            log_success "✅ 애플리케이션이 정상적으로 실행 중입니다!"
            break
        else
            if [ $i -eq 12 ]; then
                log_warning "⚠️  헬스체크 실패. 로그를 확인해주세요."
                docker-compose -f $COMPOSE_FILE logs --tail=20 backend
            else
                log_info "헬스체크 재시도 중... ($i/12)"
                sleep 5
            fi
        fi
    done
}

# 방화벽 설정 (선택사항)
configure_firewall() {
    log_info "방화벽 설정 확인 중..."
    
    # EC2 보안 그룹 확인 메시지
    echo
    log_warning "🔥 EC2 보안 그룹 설정 확인 필요:"
    log_info "   1. AWS 콘솔 > EC2 > 보안 그룹"
    log_info "   2. 인바운드 규칙에 8080 포트 추가"
    log_info "   3. 소스: 0.0.0.0/0 (또는 특정 IP)"
    echo
}

# 배포 정보 출력
show_deployment_info() {
    echo
    log_success "🎉 배포 완료!"
    echo
    echo "📋 접속 정보:"
    
    # 공개 IP 확인
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "IP확인실패")
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    
    echo "   🌐 공개 접속: http://${PUBLIC_IP}:8080"
    echo "   🏠 내부 접속: http://${PRIVATE_IP}:8080"
    echo "   ❤️  Health Check: http://${PUBLIC_IP}:8080/actuator/health"
    echo "   📚 API 문서: http://${PUBLIC_IP}:8080/swagger-ui.html"
    echo
    echo "🔐 기본 계정 정보:"
    echo "   관리자: admin / admin123"
    echo "   사용자: user1 / 1234"
    echo
    echo "📊 유용한 명령어:"
    echo "   로그 확인: docker-compose -f $COMPOSE_FILE logs -f"
    echo "   상태 확인: docker-compose -f $COMPOSE_FILE ps"
    echo "   리소스 모니터링: docker stats"
    echo "   서비스 재시작: docker-compose -f $COMPOSE_FILE restart"
    echo "   서비스 중지: docker-compose -f $COMPOSE_FILE down"
    echo
}

# 에러 핸들링
handle_error() {
    log_error "❌ 배포 중 오류가 발생했습니다."
    log_info "💡 문제 해결 방법:"
    echo "   1. Docker 서비스 상태: sudo systemctl status docker"
    echo "   2. 메모리 확인: free -h"
    echo "   3. 디스크 공간 확인: df -h"
    echo "   4. 포트 사용 확인: netstat -tlnp | grep :8080"
    
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.small.yml" ]; then
        log_info "최근 로그:"
        if [ "$USE_SMALL_CONFIG" = true ] && [ -f "docker-compose.small.yml" ]; then
            docker-compose -f docker-compose.small.yml logs --tail=30 2>/dev/null || true
        else
            docker-compose logs --tail=30 2>/dev/null || true
        fi
    fi
    
    exit 1
}

# 메인 실행 함수
main() {
    # 에러 트랩 설정
    trap handle_error ERR
    
    print_banner
    
    # 현재 디렉토리 저장
    ORIGINAL_DIR=$(pwd)
    
    # 실행 순서
    check_system
    setup_repository
    cleanup_docker
    setup_environment
    deploy_application
    check_deployment
    configure_firewall
    show_deployment_info
    
    log_success "🚀 자동 배포가 성공적으로 완료되었습니다!"
}

# 도움말 표시
show_help() {
    echo "FriendlyI EC2 자동 배포 스크립트"
    echo
    echo "사용법: $0 [옵션]"
    echo
    echo "옵션:"
    echo "  -h, --help     이 도움말 표시"
    echo "  -s, --small    강제로 EC2 Small 최적화 모드 사용"
    echo "  -f, --full     강제로 표준 모드 사용"
    echo
    echo "예시:"
    echo "  $0                # 자동 감지 모드"
    echo "  $0 --small        # EC2 Small 최적화 모드"
}

# 명령행 인수 처리
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--small)
            USE_SMALL_CONFIG=true
            shift
            ;;
        -f|--full)
            USE_SMALL_CONFIG=false
            shift
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            show_help
            exit 1
            ;;
    esac
done

# 메인 함수 실행
main "$@"