#!/bin/bash
# 전체 스택 (Frontend + Backend) 자동 배포 스크립트

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
    echo "    🚀 FriendlyI Full Stack Deployment"
    echo "    📦 Frontend + Backend + Database"
    echo "=================================================="
    echo -e "${NC}"
}

# 시스템 확인
check_system() {
    log_info "시스템 확인 중..."
    
    # 메모리 확인
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    log_info "총 메모리: ${TOTAL_MEM}MB"
    
    if [ $TOTAL_MEM -lt 2000 ]; then
        log_warning "메모리 부족! 최소 2GB 권장 (현재: ${TOTAL_MEM}MB)"
        USE_SMALL_CONFIG=true
    else
        USE_SMALL_CONFIG=false
    fi
    
    # Docker 확인
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되지 않았습니다."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose가 설치되지 않았습니다."
        exit 1
    fi
    
    log_success "시스템 확인 완료"
}

# 저장소 업데이트
update_repository() {
    log_info "저장소 업데이트 중..."
    
    if [ -d ".git" ]; then
        git fetch origin
        git pull origin master || git pull origin main
        log_success "저장소 업데이트 완료"
    else
        log_warning "Git 저장소가 아닙니다."
    fi
}

# 환경 설정
setup_environment() {
    log_info "환경 설정 중..."
    
    # Frontend 환경 설정
    if [ ! -f "frontend/.env" ]; then
        if [ -f "frontend/.env.production" ]; then
            cp frontend/.env.production frontend/.env
            log_info "Frontend 프로덕션 환경 설정 적용"
        elif [ -f "frontend/.env.example" ]; then
            cp frontend/.env.example frontend/.env
            log_info "Frontend 기본 환경 설정 적용"
        fi
    fi
    
    # Backend 환경 설정
    if [ ! -f "backend/.env" ]; then
        if [ -f "backend/.env.small" ] && [ "$USE_SMALL_CONFIG" = true ]; then
            cp backend/.env.small backend/.env
            log_info "Backend EC2 Small 환경 설정 적용"
        elif [ -f "backend/.env.example" ]; then
            cp backend/.env.example backend/.env
            log_info "Backend 기본 환경 설정 적용"
        fi
    fi
    
    log_success "환경 설정 완료"
}

# 포트 충돌 확인 및 해결
check_ports() {
    log_info "포트 충돌 확인 중..."
    
    # 5432 포트 확인 (PostgreSQL)
    if netstat -tlnp 2>/dev/null | grep -q ":5432"; then
        log_warning "5432 포트가 사용 중입니다. Docker Compose에서 5433 포트를 사용합니다."
        # docker-compose.yml에서 포트 변경
        if [ -f "docker-compose.yml" ]; then
            sed -i 's/5432:5432/5433:5432/g' docker-compose.yml 2>/dev/null || true
        fi
    fi
    
    # 80 포트 확인 (Frontend)
    if netstat -tlnp 2>/dev/null | grep -q ":80"; then
        log_warning "80 포트가 사용 중입니다. Frontend를 3000 포트로 변경합니다."
        if [ -f "docker-compose.yml" ]; then
            sed -i 's/"80:80"/"3000:80"/g' docker-compose.yml 2>/dev/null || true
        fi
        FRONTEND_PORT=3000
    else
        FRONTEND_PORT=80
    fi
    
    # 8080 포트 확인 (Backend)
    if netstat -tlnp 2>/dev/null | grep -q ":8080"; then
        log_warning "8080 포트가 사용 중입니다. 기존 프로세스를 확인하세요."
        netstat -tlnp 2>/dev/null | grep ":8080" || true
    fi
    
    log_success "포트 확인 완료"
}

# Docker 정리
cleanup_docker() {
    log_info "기존 컨테이너 정리 중..."
    
    # 기존 컨테이너 중지
    docker-compose down 2>/dev/null || true
    cd backend && docker-compose down 2>/dev/null && cd .. || true
    
    # 사용하지 않는 리소스 정리
    docker system prune -f
    
    log_success "Docker 정리 완료"
}

# 전체 스택 빌드 및 배포
deploy_fullstack() {
    log_info "전체 스택 빌드 및 배포 중..."
    
    # Docker Compose로 전체 스택 빌드
    log_info "이미지 빌드 중... (시간이 소요될 수 있습니다)"
    docker-compose build --no-cache
    
    # 컨테이너 시작
    log_info "서비스 시작 중..."
    docker-compose up -d
    
    log_success "전체 스택 배포 완료"
}

# 배포 상태 확인
check_deployment() {
    log_info "배포 상태 확인 중..."
    
    # 서비스 시작 대기
    log_info "서비스 시작 대기 중... (60초)"
    sleep 60
    
    # 컨테이너 상태
    echo
    log_info "컨테이너 상태:"
    docker-compose ps
    
    # Backend 헬스체크
    echo
    log_info "Backend 헬스체크 중..."
    for i in {1..12}; do
        if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
            log_success "✅ Backend 정상 동작 중"
            break
        else
            if [ $i -eq 12 ]; then
                log_warning "⚠️ Backend 헬스체크 실패"
            else
                log_info "Backend 헬스체크 재시도... ($i/12)"
                sleep 5
            fi
        fi
    done
    
    # Frontend 헬스체크
    log_info "Frontend 헬스체크 중..."
    for i in {1..6}; do
        if curl -f http://localhost:${FRONTEND_PORT:-80} >/dev/null 2>&1; then
            log_success "✅ Frontend 정상 동작 중"
            break
        else
            if [ $i -eq 6 ]; then
                log_warning "⚠️ Frontend 헬스체크 실패"
            else
                log_info "Frontend 헬스체크 재시도... ($i/6)"
                sleep 5
            fi
        fi
    done
}

# 배포 정보 출력
show_deployment_info() {
    echo
    log_success "🎉 전체 스택 배포 완료!"
    echo
    
    # IP 주소 확인
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "IP확인실패")
    PRIVATE_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "📋 접속 정보:"
    echo "   🌐 Frontend (웹사이트):"
    echo "      외부: http://${PUBLIC_IP}:${FRONTEND_PORT:-80}"
    echo "      내부: http://${PRIVATE_IP}:${FRONTEND_PORT:-80}"
    echo
    echo "   🔧 Backend API:"
    echo "      외부: http://${PUBLIC_IP}:8080"
    echo "      내부: http://${PRIVATE_IP}:8080"
    echo "      헬스체크: http://${PUBLIC_IP}:8080/actuator/health"
    echo "      API 문서: http://${PUBLIC_IP}:8080/swagger-ui.html"
    echo
    
    echo "🔐 기본 계정 정보:"
    echo "   관리자: admin / admin123"
    echo "   사용자: user1 / 1234"
    echo
    
    echo "📊 관리 명령어:"
    echo "   전체 로그: docker-compose logs -f"
    echo "   Backend 로그: docker-compose logs -f backend"
    echo "   Frontend 로그: docker-compose logs -f frontend"
    echo "   상태 확인: docker-compose ps"
    echo "   서비스 재시작: docker-compose restart"
    echo "   서비스 중지: docker-compose down"
    echo
    
    echo "⚠️ 보안 그룹 설정 확인:"
    echo "   - 80 포트 (Frontend) 인바운드 규칙 추가"
    echo "   - 8080 포트 (Backend) 인바운드 규칙 추가"
    echo
}

# 에러 처리
handle_error() {
    log_error "❌ 배포 중 오류가 발생했습니다."
    
    echo "📋 문제 해결:"
    echo "   1. 포트 확인: netstat -tlnp | grep -E ':(80|8080|5432)'"
    echo "   2. Docker 로그: docker-compose logs"
    echo "   3. 메모리 확인: free -h"
    echo "   4. 디스크 확인: df -h"
    
    echo
    log_info "최근 로그 (Backend):"
    docker-compose logs --tail=20 backend 2>/dev/null || true
    
    echo
    log_info "최근 로그 (Frontend):"
    docker-compose logs --tail=20 frontend 2>/dev/null || true
    
    exit 1
}

# 메인 실행 함수
main() {
    trap handle_error ERR
    
    print_banner
    
    check_system
    update_repository
    setup_environment
    check_ports
    cleanup_docker
    deploy_fullstack
    check_deployment
    show_deployment_info
    
    log_success "🚀 전체 스택 자동 배포 완료!"
}

# 도움말
show_help() {
    echo "FriendlyI 전체 스택 배포 스크립트"
    echo
    echo "사용법: $0 [옵션]"
    echo
    echo "옵션:"
    echo "  -h, --help     도움말 표시"
    echo "  --backend-only Backend만 배포"
    echo "  --frontend-only Frontend만 배포"
    echo
}

# 명령행 인수 처리
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --backend-only)
            echo "Backend만 배포하는 중..."
            cd backend && ./auto-deploy.sh
            exit 0
            ;;
        --frontend-only)
            echo "Frontend만 배포하는 중..."
            docker-compose up -d frontend
            exit 0
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