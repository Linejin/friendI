#!/bin/bash
# EC2 t3.small 리소스 모니터링 및 관리 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "📊 EC2 t3.small 리소스 모니터링"
echo "==============================="

# 1. 시스템 리소스 현황
log_info "시스템 리소스 현황"
echo ""
echo "💾 메모리 사용량:"
free -h
echo ""

MEMORY_USAGE=$(free | grep '^Mem:' | awk '{printf("%.1f", ($3/$2) * 100.0)}')
if (( $(echo "$MEMORY_USAGE > 85" | bc -l) )); then
    log_error "메모리 사용량이 ${MEMORY_USAGE}%로 높습니다!"
elif (( $(echo "$MEMORY_USAGE > 70" | bc -l) )); then
    log_warning "메모리 사용량: ${MEMORY_USAGE}%"
else
    log_success "메모리 사용량: ${MEMORY_USAGE}%"
fi

echo ""
echo "💿 디스크 사용량:"
df -h / | tail -1

DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    log_error "디스크 사용량이 ${DISK_USAGE}%로 높습니다!"
elif [ "$DISK_USAGE" -gt 70 ]; then
    log_warning "디스크 사용량: ${DISK_USAGE}%"
else
    log_success "디스크 사용량: ${DISK_USAGE}%"
fi

echo ""
echo "🔄 CPU 로드:"
uptime

# 2. Docker 컨테이너 상태
log_info "Docker 컨테이너 상태"
echo ""
if docker ps >/dev/null 2>&1; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep friendi || echo "FriendI 컨테이너가 실행 중이지 않습니다"
else
    log_error "Docker가 실행 중이지 않습니다"
fi

# 3. Docker 리소스 사용량
log_info "Docker 컨테이너별 리소스 사용량"
echo ""
if docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null | grep friendi; then
    echo ""
else
    log_warning "실행 중인 FriendI 컨테이너가 없습니다"
fi

# 4. 서비스 헬스체크
log_info "서비스 헬스체크"
echo ""

# Backend 헬스체크
if curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
    HEALTH_STATUS=$(curl -s http://localhost:8080/actuator/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$HEALTH_STATUS" = "UP" ]; then
        log_success "Backend: $HEALTH_STATUS"
    else
        log_warning "Backend: $HEALTH_STATUS"
    fi
else
    log_error "Backend: DOWN (연결 불가)"
fi

# Frontend 헬스체크
if curl -s -f http://localhost:3000 >/dev/null 2>&1; then
    log_success "Frontend: UP"
else
    log_error "Frontend: DOWN (연결 불가)"
fi

# PostgreSQL 헬스체크
if docker exec friendi-postgres pg_isready -U friendlyi_user -d friendlyi >/dev/null 2>&1; then
    log_success "PostgreSQL: UP"
else
    log_error "PostgreSQL: DOWN"
fi

# Redis 헬스체크
if docker exec friendi-redis redis-cli ping 2>/dev/null | grep -q PONG; then
    log_success "Redis: UP"
else
    log_error "Redis: DOWN"
fi

# 5. 성능 최적화 제안
echo ""
log_info "성능 최적화 제안"
echo ""

# 메모리 기반 제안
if (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
    echo "🔧 메모리 사용량이 높습니다. 다음 조치를 고려하세요:"
    echo "   1. docker-compose -f docker-compose.ec2-optimized.yml restart"
    echo "   2. ./cleanup-resources.sh"
    echo "   3. 불필요한 프로세스 종료"
fi

# 디스크 기반 제안
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "🔧 디스크 사용량이 높습니다. 다음 조치를 고려하세요:"
    echo "   1. docker system prune -f"
    echo "   2. 로그 파일 정리"
    echo "   3. 오래된 백업 파일 삭제"
fi

# 6. 빠른 명령어 모음
echo ""
log_info "빠른 관리 명령어"
echo "=================="
echo ""
echo "🔄 서비스 관리:"
echo "   전체 재시작: docker-compose -f docker-compose.ec2-optimized.yml restart"
echo "   개별 재시작: docker-compose -f docker-compose.ec2-optimized.yml restart [service]"
echo "   전체 중지:   docker-compose -f docker-compose.ec2-optimized.yml down"
echo "   전체 시작:   docker-compose -f docker-compose.ec2-optimized.yml up -d"
echo ""
echo "📋 로그 확인:"
echo "   전체 로그:   docker-compose -f docker-compose.ec2-optimized.yml logs -f"
echo "   Backend:     docker logs friendi-backend -f"
echo "   Frontend:    docker logs friendi-frontend -f"
echo ""
echo "🧹 정리 작업:"
echo "   Docker 정리: docker system prune -f"
echo "   이미지 정리: docker image prune -f"
echo "   볼륨 정리:   docker volume prune -f"
echo ""
echo "📊 모니터링:"
echo "   리소스 실시간: docker stats"
echo "   시스템 정보:   htop 또는 top"
echo "   디스크 사용량: du -sh /var/lib/docker"