#!/bin/bash
# Backend 전용 배포 스크립트 (디버그 모드)

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
    echo "    🔧 Backend 전용 배포 (디버그 모드)"
    echo "    📦 상세 로그와 함께 문제 진단"
    echo "=================================================="
    echo -e "${NC}"
}

# 시스템 상태 확인
check_system() {
    log_info "시스템 상태 확인 중..."
    
    # 메모리 확인
    echo "메모리 사용률:"
    free -h
    
    # 디스크 확인
    echo -e "\n디스크 사용률:"
    df -h
    
    # Docker 상태 확인
    echo -e "\n실행 중인 컨테이너:"
    docker ps
    
    # 포트 사용 확인
    echo -e "\n포트 사용 상태:"
    netstat -tlnp 2>/dev/null | grep -E "(8080|5432|5433|6379)" || echo "관련 포트 사용 없음"
}

# Backend 빌드 테스트
test_backend_build() {
    log_info "Backend 빌드 테스트 중..."
    
    cd backend/backend
    
    # Maven 래퍼 권한 확인
    chmod +x mvnw
    
    # 의존성 다운로드 테스트
    log_info "Maven 의존성 확인 중..."
    ./mvnw dependency:resolve -B || {
        log_error "Maven 의존성 해결 실패"
        return 1
    }
    
    # 컴파일 테스트
    log_info "소스 컴파일 테스트 중..."
    ./mvnw compile -B || {
        log_error "소스 컴파일 실패"
        return 1
    }
    
    # 패키지 생성 테스트
    log_info "JAR 패키지 생성 테스트 중..."
    ./mvnw package -DskipTests -B || {
        log_error "JAR 패키지 생성 실패"
        return 1
    }
    
    # JAR 파일 확인
    if [ -f "target/backend-0.0.1-SNAPSHOT.jar" ]; then
        log_success "JAR 파일 생성 완료: $(ls -lh target/backend-0.0.1-SNAPSHOT.jar)"
    else
        log_error "JAR 파일을 찾을 수 없습니다"
        return 1
    fi
    
    cd ../../
    log_success "Backend 빌드 테스트 성공"
}

# Docker 이미지 빌드
build_backend_image() {
    log_info "Backend Docker 이미지 빌드 중..."
    
    # 기존 이미지 제거 (캐시 문제 방지)
    docker rmi $(docker images | grep friendlyi-backend | awk '{print $3}') 2>/dev/null || true
    
    # 빌드 컨텍스트 확인
    log_info "빌드 컨텍스트: $(pwd)/backend/backend"
    ls -la backend/backend/
    
    # Docker 빌드 (상세 로그)
    log_info "Docker 빌드 시작 (시간이 소요될 수 있습니다)..."
    docker build \
        --no-cache \
        --progress=plain \
        -t friendlyi-backend:latest \
        ./backend/backend || {
        log_error "Docker 이미지 빌드 실패"
        
        # 빌드 로그 확인
        log_info "빌드 로그 확인을 위해 Docker 시스템 정보:"
        docker system df
        docker system events --since=5m &
        sleep 2
        kill %1 2>/dev/null || true
        
        return 1
    }
    
    log_success "Backend Docker 이미지 빌드 완료"
    docker images | grep friendlyi-backend
}

# Backend 컨테이너 배포
deploy_backend() {
    log_info "Backend 컨테이너 배포 중..."
    
    # 기존 Backend 컨테이너 정리
    log_info "기존 Backend 컨테이너 정리 중..."
    docker-compose stop backend 2>/dev/null || true
    docker-compose rm -f backend 2>/dev/null || true
    
    # PostgreSQL이 실행 중인지 확인
    if ! docker-compose ps postgres | grep -q "Up"; then
        log_warning "PostgreSQL이 실행되지 않았습니다. 먼저 시작합니다..."
        docker-compose up -d postgres redis
        
        log_info "PostgreSQL 시작 대기 중... (60초)"
        sleep 60
        
        # PostgreSQL 헬스체크
        if docker-compose ps postgres | grep -q "healthy"; then
            log_success "PostgreSQL 준비 완료"
        else
            log_error "PostgreSQL 시작 실패"
            docker-compose logs postgres
            return 1
        fi
    fi
    
    # Backend 컨테이너 시작
    log_info "Backend 컨테이너 시작 중..."
    docker-compose up -d backend || {
        log_error "Backend 컨테이너 시작 실패"
        
        # 상세 로그 확인
        log_info "Backend 컨테이너 로그:"
        docker-compose logs backend
        
        return 1
    }
    
    # Backend 시작 대기
    log_info "Backend 시작 대기 중... (90초)"
    sleep 90
    
    # Backend 상태 확인
    log_info "Backend 컨테이너 상태 확인..."
    docker-compose ps backend
    
    # Backend 로그 확인
    log_info "Backend 로그 (최근 20줄):"
    docker-compose logs --tail=20 backend
    
    # 헬스체크
    log_info "Backend 헬스체크 수행 중..."
    for i in {1..12}; do
        if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
            log_success "✅ Backend 헬스체크 성공"
            return 0
        else
            log_info "Backend 헬스체크 재시도... ($i/12)"
            sleep 10
        fi
    done
    
    log_error "❌ Backend 헬스체크 실패"
    
    # 실패 시 상세 정보
    log_info "실패 시 진단 정보:"
    echo "컨테이너 상태:"
    docker-compose ps
    echo -e "\nBackend 상세 로그:"
    docker-compose logs backend
    echo -e "\n포트 확인:"
    netstat -tlnp | grep 8080
    
    return 1
}

# 메인 실행
main() {
    print_banner
    
    check_system
    
    if test_backend_build; then
        log_success "✅ Backend 빌드 테스트 통과"
    else
        log_error "❌ Backend 빌드 테스트 실패"
        exit 1
    fi
    
    if build_backend_image; then
        log_success "✅ Docker 이미지 빌드 성공"
    else
        log_error "❌ Docker 이미지 빌드 실패"
        exit 1
    fi
    
    if deploy_backend; then
        log_success "🎉 Backend 배포 성공!"
        
        echo
        echo "📋 접속 정보:"
        echo "   🔧 Backend API: http://$(curl -s ifconfig.me):8080"
        echo "   💾 헬스체크: http://$(curl -s ifconfig.me):8080/actuator/health"
        echo "   📊 API 문서: http://$(curl -s ifconfig.me):8080/swagger-ui.html"
        echo
        echo "🛠️ 관리 명령어:"
        echo "   Backend 로그: docker-compose logs -f backend"
        echo "   Backend 재시작: docker-compose restart backend"
        echo "   전체 상태: docker-compose ps"
        
    else
        log_error "❌ Backend 배포 실패"
        
        echo
        log_info "문제 해결 방법:"
        echo "1. 메모리 부족: sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
        echo "2. 포트 충돌: ./fix-port-conflicts.sh"
        echo "3. Docker 재시작: sudo systemctl restart docker"
        echo "4. 수동 빌드: cd backend/backend && ./mvnw clean package -DskipTests"
        
        exit 1
    fi
}

# 스크립트 실행
main "$@"