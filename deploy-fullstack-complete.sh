#!/bin/bash
# 전체 스택 (Frontend + Backend + Database) 배포 스크립트

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
    echo "    🚀 FriendlyI 전체 스택 배포"
    echo "    📦 Frontend + Backend + Database + Redis"
    echo "=================================================="
    echo -e "${NC}"
}

# 시스템 상태 확인
check_system() {
    log_info "시스템 상태 확인 중..."
    
    # 디스크 사용량 확인
    ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$ROOT_USAGE" -gt 90 ]; then
        log_warning "⚠️ 디스크 사용률 높음: ${ROOT_USAGE}%"
        log_info "디스크 정리를 권장합니다: ./cleanup-disk-emergency.sh"
    else
        log_info "✅ 디스크 사용률: ${ROOT_USAGE}% (양호)"
    fi
    
    # 메모리 확인
    echo "📊 현재 시스템 상태:"
    echo "디스크 사용량:"
    df -h / | grep -v Filesystem
    echo -e "\n메모리 사용량:"
    free -h
}

# 기존 서비스 정리
cleanup_existing() {
    log_info "기존 서비스 정리 중..."
    
    # 모든 컨테이너 정리
    docker-compose down 2>/dev/null || true
    
    # 사용하지 않는 이미지 정리 (공간 절약)
    log_info "사용하지 않는 Docker 이미지 정리..."
    docker image prune -f 2>/dev/null || true
    
    log_success "기존 서비스 정리 완료"
}

# 데이터베이스 서비스 배포
deploy_databases() {
    log_info "데이터베이스 서비스 배포 중..."
    
    # PostgreSQL과 Redis 먼저 시작
    log_info "PostgreSQL 및 Redis 시작..."
    docker-compose up -d postgres redis
    
    # 데이터베이스 시작 대기
    log_info "데이터베이스 시작 대기... (45초)"
    sleep 45
    
    # 데이터베이스 상태 확인
    log_info "데이터베이스 상태 확인:"
    docker-compose ps postgres redis
    
    # PostgreSQL 헬스체크
    for i in {1..6}; do
        if docker-compose ps postgres | grep -q "healthy"; then
            log_success "✅ PostgreSQL 준비 완료"
            break
        else
            if [ $i -eq 6 ]; then
                log_error "❌ PostgreSQL 시작 실패"
                docker-compose logs postgres
                return 1
            fi
            log_info "PostgreSQL 헬스체크 재시도... ($i/6)"
            sleep 10
        fi
    done
    
    # Redis 헬스체크
    if docker-compose ps redis | grep -q "healthy"; then
        log_success "✅ Redis 준비 완료"
    else
        log_warning "⚠️ Redis 상태 확인 필요"
    fi
}

# Backend 배포
deploy_backend() {
    log_info "Backend 서비스 배포 중..."
    
    # Backend 빌드 및 시작
    log_info "Backend 빌드 중... (시간이 소요될 수 있습니다)"
    docker-compose build --no-cache backend
    
    log_info "Backend 컨테이너 시작..."
    docker-compose up -d backend
    
    # Backend 시작 대기
    log_info "Backend 시작 대기... (90초)"
    sleep 90
    
    # Backend 헬스체크
    log_info "Backend 헬스체크 수행 중..."
    for i in {1..12}; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            log_success "✅ Backend 헬스체크 성공"
            return 0
        else
            if [ $i -eq 12 ]; then
                log_error "❌ Backend 헬스체크 실패"
                log_info "Backend 로그 (최근 20줄):"
                docker-compose logs --tail=20 backend
                return 1
            fi
            log_info "Backend 헬스체크 재시도... ($i/12) [HTTP: $HTTP_CODE]"
            sleep 10
        fi
    done
}

# Frontend 배포
deploy_frontend() {
    log_info "Frontend 서비스 배포 중..."
    
    # Frontend 빌드 및 시작
    log_info "Frontend 빌드 중... (시간이 소요될 수 있습니다)"
    
    # 포트 충돌 확인
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        log_warning "80 포트가 사용 중입니다. 3000 포트로 변경합니다."
        # Docker Compose에서 포트 변경
        sed -i 's/"80:80"/"3000:80"/g' docker-compose.yml 2>/dev/null || true
        FRONTEND_PORT=3000
    else
        FRONTEND_PORT=80
    fi
    
    # Frontend 빌드
    if ! docker-compose build frontend; then
        log_error "❌ Frontend 빌드 실패"
        log_info "Frontend 빌드 로그 확인 중..."
        
        # Frontend 빌드 문제 해결 시도
        log_info "Frontend 설정 문제 해결 시도 중..."
        
        # package-lock.json 문제 해결
        if [ -f "frontend/package-lock.json" ]; then
            log_info "package-lock.json 재생성..."
            rm -f frontend/package-lock.json
        fi
        
        # 다시 빌드 시도
        log_info "Frontend 재빌드 시도..."
        docker-compose build --no-cache frontend || {
            log_error "❌ Frontend 빌드 최종 실패"
            return 1
        }
    fi
    
    log_info "Frontend 컨테이너 시작..."
    docker-compose up -d frontend
    
    # Frontend 시작 대기
    log_info "Frontend 시작 대기... (60초)"
    sleep 60
    
    # Frontend 헬스체크
    log_info "Frontend 헬스체크 수행 중..."
    for i in {1..8}; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$FRONTEND_PORT 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            log_success "✅ Frontend 헬스체크 성공"
            return 0
        else
            if [ $i -eq 8 ]; then
                log_error "❌ Frontend 헬스체크 실패"
                log_info "Frontend 로그 (최근 20줄):"
                docker-compose logs --tail=20 frontend
                return 1
            fi
            log_info "Frontend 헬스체크 재시도... ($i/8) [HTTP: $HTTP_CODE]"
            sleep 10
        fi
    done
}

# 전체 상태 확인
verify_full_stack() {
    log_info "전체 스택 상태 검증 중..."
    
    echo "📊 전체 서비스 상태:"
    docker-compose ps
    
    echo -e "\n🔍 서비스별 헬스체크:"
    
    # PostgreSQL 체크
    if docker-compose ps postgres | grep -q "healthy"; then
        echo "   ✅ PostgreSQL: 정상 (포트 5433)"
    else
        echo "   ❌ PostgreSQL: 비정상"
        DEPLOYMENT_FAILED=true
    fi
    
    # Redis 체크
    if docker-compose ps redis | grep -q "healthy"; then
        echo "   ✅ Redis: 정상 (포트 6379)"
    else
        echo "   ❌ Redis: 비정상"
        DEPLOYMENT_FAILED=true
    fi
    
    # Backend 체크
    if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        echo "   ✅ Backend: 정상 (포트 8080)"
        BACKEND_HEALTH=$(curl -s http://localhost:8080/actuator/health | grep -o '"status":"[^"]*"' || echo "상태 확인 중")
        echo "      상태: $BACKEND_HEALTH"
    else
        echo "   ❌ Backend: 비정상 (포트 8080)"
        DEPLOYMENT_FAILED=true
    fi
    
    # Frontend 체크
    if curl -f http://localhost:$FRONTEND_PORT >/dev/null 2>&1; then
        echo "   ✅ Frontend: 정상 (포트 $FRONTEND_PORT)"
    else
        echo "   ❌ Frontend: 비정상 (포트 $FRONTEND_PORT)"
        DEPLOYMENT_FAILED=true
    fi
    
    if [ "$DEPLOYMENT_FAILED" = "true" ]; then
        return 1
    else
        return 0
    fi
}

# 배포 정보 표시
show_deployment_info() {
    echo
    log_success "🎉 전체 스택 배포 완료!"
    
    # 공인 IP 확인
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "IP확인실패")
    PRIVATE_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo
    echo "📋 FriendlyI 서비스 접속 정보:"
    echo "════════════════════════════════════════"
    echo "🌐 Frontend (웹사이트):"
    echo "   외부 접속: http://$PUBLIC_IP:$FRONTEND_PORT"
    echo "   내부 접속: http://$PRIVATE_IP:$FRONTEND_PORT"
    echo
    echo "🔧 Backend API:"
    echo "   외부 접속: http://$PUBLIC_IP:8080"
    echo "   내부 접속: http://$PRIVATE_IP:8080"
    echo "   헬스체크: http://$PUBLIC_IP:8080/actuator/health"
    echo "   API 문서: http://$PUBLIC_IP:8080/swagger-ui/index.html"
    echo
    echo "💾 데이터베이스:"
    echo "   PostgreSQL: $PUBLIC_IP:5433"
    echo "   Redis: $PUBLIC_IP:6379"
    echo
    echo "🔐 기본 계정 (변경 권장):"
    echo "   관리자: admin / admin123"
    echo "   테스트 사용자: user1 / 1234"
    echo
    echo "🛠️ 관리 명령어:"
    echo "════════════════════════════════════════"
    echo "   전체 로그: docker-compose logs -f"
    echo "   Backend 로그: docker-compose logs -f backend"
    echo "   Frontend 로그: docker-compose logs -f frontend"
    echo "   상태 확인: docker-compose ps"
    echo "   서비스 재시작: docker-compose restart [service-name]"
    echo "   서비스 중지: docker-compose down"
    echo
    echo "⚠️ AWS EC2 보안 그룹 설정 확인:"
    echo "════════════════════════════════════════"
    echo "   - $FRONTEND_PORT 포트 (Frontend) 인바운드 규칙 추가"
    echo "   - 8080 포트 (Backend) 인바운드 규칙 추가"
    echo "   - 5433 포트 (PostgreSQL) - 필요시에만"
    echo "   - 6379 포트 (Redis) - 필요시에만"
    echo
    
    # 추가 정보
    echo "📊 현재 리소스 사용량:"
    echo "디스크: $(df / | awk 'NR==2 {print $5}') 사용 중"
    echo "메모리: $(free | awk '/^Mem:/ {printf("%.1f%%", $3/$2 * 100.0)}') 사용 중"
    echo
}

# 에러 처리
handle_error() {
    log_error "❌ 배포 중 오류가 발생했습니다."
    
    echo
    echo "📋 문제 해결 단계:"
    echo "1. 전체 로그 확인: docker-compose logs"
    echo "2. 개별 서비스 로그: docker-compose logs [backend|frontend|postgres|redis]"
    echo "3. 컨테이너 상태: docker-compose ps"
    echo "4. 디스크 공간: df -h"
    echo "5. 메모리 상태: free -h"
    echo
    echo "🔧 일반적인 해결 방법:"
    echo "- 디스크 부족: ./cleanup-disk-emergency.sh"
    echo "- 메모리 부족: sudo swapon -a"
    echo "- 포트 충돌: ./fix-port-conflicts.sh"
    echo "- Docker 문제: sudo systemctl restart docker"
}

# 메인 실행 함수
main() {
    print_banner
    
    check_system
    cleanup_existing
    
    # 단계별 배포
    if deploy_databases; then
        log_success "✅ 데이터베이스 배포 완료"
    else
        log_error "❌ 데이터베이스 배포 실패"
        handle_error
        exit 1
    fi
    
    if deploy_backend; then
        log_success "✅ Backend 배포 완료"
    else
        log_error "❌ Backend 배포 실패"
        handle_error
        exit 1
    fi
    
    if deploy_frontend; then
        log_success "✅ Frontend 배포 완료"
    else
        log_error "❌ Frontend 배포 실패"
        handle_error
        exit 1
    fi
    
    # 전체 검증
    if verify_full_stack; then
        show_deployment_info
        log_success "🚀 전체 스택 배포 성공!"
    else
        log_error "❌ 일부 서비스에 문제가 있습니다."
        handle_error
        exit 1
    fi
}

# 스크립트 실행
main "$@"