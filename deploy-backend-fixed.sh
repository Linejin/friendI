#!/bin/bash
# 환경 변수 강제 로드 및 Backend 배포 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "    🚀 Backend 환경변수 고정 배포"
    echo "    📦 환경 변수 문제 해결 버전"
    echo "=================================================="
    echo -e "${NC}"
}

# 환경 변수 강제 설정
setup_environment() {
    log_info "환경 변수 강제 설정 중..."
    
    # .env 파일이 있으면 로드
    if [ -f ".env" ]; then
        log_info ".env 파일 발견, 변수 로드 중..."
        export $(grep -v '^#' .env | xargs)
    fi
    
    # 핵심 환경 변수 강제 설정
    export COMPOSE_PROJECT_NAME=friendi
    export POSTGRES_PORT=5433
    export POSTGRES_DB=friendlyi
    export POSTGRES_USER=friendlyi_user
    export POSTGRES_PASSWORD=friendlyi_password123
    export REDIS_PORT=6379
    export REDIS_PASSWORD=redis_password123
    export BACKEND_PORT=8080
    export SPRING_PROFILES_ACTIVE=docker
    export FRONTEND_HTTP_PORT=80
    export FRONTEND_HTTPS_PORT=443
    export TZ=Asia/Seoul
    export JAVA_OPTS="-Xmx1g -Xms512m -XX:+UseG1GC -XX:+UseContainerSupport"
    
    log_success "환경 변수 설정 완료"
    
    # 설정된 환경 변수 확인
    echo "📋 설정된 환경 변수:"
    echo "  COMPOSE_PROJECT_NAME: $COMPOSE_PROJECT_NAME"
    echo "  POSTGRES_PORT: $POSTGRES_PORT"
    echo "  POSTGRES_DB: $POSTGRES_DB"
    echo "  POSTGRES_USER: $POSTGRES_USER"
    echo "  REDIS_PASSWORD: $REDIS_PASSWORD"
    echo "  BACKEND_PORT: $BACKEND_PORT"
    echo "  TZ: $TZ"
}

# Docker Compose 환경 변수 파일 생성
create_compose_env() {
    log_info "Docker Compose용 환경 파일 생성 중..."
    
    cat > .env << EOF
# FriendlyI Docker Compose 환경 변수 (자동 생성)
COMPOSE_PROJECT_NAME=friendi
POSTGRES_PORT=5433
POSTGRES_DB=friendlyi
POSTGRES_USER=friendlyi_user
POSTGRES_PASSWORD=friendlyi_password123
REDIS_PORT=6379
REDIS_PASSWORD=redis_password123
BACKEND_PORT=8080
SPRING_PROFILES_ACTIVE=docker
FRONTEND_HTTP_PORT=80
FRONTEND_HTTPS_PORT=443
TZ=Asia/Seoul
JAVA_OPTS=-Xmx1g -Xms512m -XX:+UseG1GC -XX:+UseContainerSupport
EOF
    
    log_success "환경 파일 생성 완료: .env"
}

# Backend만 배포
deploy_backend_only() {
    log_info "Backend 전용 배포 시작..."
    
    # 기존 Backend 컨테이너 정리
    log_info "기존 Backend 컨테이너 정리 중..."
    docker-compose stop backend 2>/dev/null || true
    docker-compose rm -f backend 2>/dev/null || true
    
    # PostgreSQL과 Redis가 실행 중인지 확인
    if ! docker-compose ps postgres | grep -q "Up" || ! docker-compose ps redis | grep -q "Up"; then
        log_info "PostgreSQL 및 Redis 시작 중..."
        docker-compose up -d postgres redis
        
        # 시작 대기
        log_info "데이터베이스 서비스 시작 대기 중... (60초)"
        sleep 60
    fi
    
    # Backend 이미지 빌드 (환경 변수와 함께)
    log_info "Backend Docker 이미지 빌드 중..."
    docker-compose build --no-cache backend
    
    # Backend 컨테이너 시작
    log_info "Backend 컨테이너 시작 중..."
    docker-compose up -d backend
    
    # Backend 시작 대기
    log_info "Backend 시작 대기 중... (120초)"
    sleep 120
    
    # 상태 확인
    log_info "Backend 상태 확인..."
    docker-compose ps backend
    
    # 로그 확인
    log_info "Backend 로그 (최근 30줄):"
    docker-compose logs --tail=30 backend
    
    # 헬스체크
    log_info "Backend 헬스체크 수행 중..."
    for i in {1..15}; do
        if curl -f http://localhost:$BACKEND_PORT/actuator/health 2>/dev/null; then
            log_success "✅ Backend 헬스체크 성공!"
            
            # 접속 정보 표시
            PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
            echo
            echo "🎉 Backend 배포 성공!"
            echo "📋 접속 정보:"
            echo "   🔧 Backend API: http://$PUBLIC_IP:$BACKEND_PORT"
            echo "   💾 헬스체크: http://$PUBLIC_IP:$BACKEND_PORT/actuator/health"
            echo "   📊 API 문서: http://$PUBLIC_IP:$BACKEND_PORT/swagger-ui.html"
            echo
            echo "🛠️ 관리 명령어:"
            echo "   Backend 로그: docker-compose logs -f backend"
            echo "   Backend 재시작: docker-compose restart backend"
            echo "   전체 상태: docker-compose ps"
            
            return 0
        else
            log_info "Backend 헬스체크 재시도... ($i/15)"
            sleep 10
        fi
    done
    
    log_error "❌ Backend 헬스체크 실패"
    
    # 실패 시 진단 정보
    echo
    log_info "실패 진단 정보:"
    echo "컨테이너 상태:"
    docker-compose ps
    
    echo -e "\nBackend 전체 로그:"
    docker-compose logs backend
    
    echo -e "\n환경 변수 확인:"
    docker-compose exec backend env | grep -E "(SPRING|DB_|REDIS_|JAVA_)" || true
    
    echo -e "\n포트 확인:"
    netstat -tlnp | grep $BACKEND_PORT || true
    
    return 1
}

# 메인 실행
main() {
    print_banner
    
    setup_environment
    create_compose_env
    
    if deploy_backend_only; then
        log_success "🚀 Backend 배포 성공!"
    else
        log_error "❌ Backend 배포 실패"
        
        echo
        log_info "문제 해결 방법:"
        echo "1. 메모리 확인: free -h"
        echo "2. 디스크 확인: df -h"
        echo "3. Docker 로그: docker-compose logs backend"
        echo "4. 수동 빌드: cd backend/backend && ./mvnw clean package -DskipTests"
        echo "5. 환경 변수 확인: docker-compose config"
        
        exit 1
    fi
}

# 스크립트 실행
main "$@"