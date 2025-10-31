#!/bin/bash
# EC2 t3.small 리소스 정리 및 최적화 스크립트

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

echo "🧹 EC2 t3.small 리소스 정리 및 최적화"
echo "===================================="

# 현재 리소스 상태 확인
log_info "현재 리소스 상태 확인"
echo ""
echo "정리 전 상태:"
free -h | head -2
df -h / | tail -1

# 1. Docker 리소스 정리
log_info "Docker 리소스 정리 중..."

# 중지된 컨테이너 제거
STOPPED_CONTAINERS=$(docker ps -aq -f status=exited 2>/dev/null | wc -l)
if [ "$STOPPED_CONTAINERS" -gt 0 ]; then
    docker rm $(docker ps -aq -f status=exited) 2>/dev/null || true
    log_success "중지된 컨테이너 ${STOPPED_CONTAINERS}개 제거"
fi

# 사용하지 않는 이미지 제거
UNUSED_IMAGES=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
if [ "$UNUSED_IMAGES" -gt 0 ]; then
    docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
    log_success "사용하지 않는 이미지 ${UNUSED_IMAGES}개 제거"
fi

# Docker 시스템 정리
docker system prune -f 2>/dev/null || true
docker builder prune -f 2>/dev/null || true
log_success "Docker 시스템 정리 완료"

# 2. 로그 파일 정리
log_info "로그 파일 정리 중..."

# Docker 로그 정리 (1주일 이상 된 로그)
if [ -d "/var/lib/docker/containers" ]; then
    find /var/lib/docker/containers -name "*.log" -mtime +7 -exec truncate -s 0 {} \; 2>/dev/null || true
    log_success "Docker 로그 파일 정리 완료"
fi

# 시스템 로그 정리
sudo journalctl --vacuum-time=7d 2>/dev/null || true
log_success "시스템 로그 정리 완료"

# 3. 임시 파일 정리
log_info "임시 파일 정리 중..."

# /tmp 디렉토리 정리 (1일 이상 된 파일)
find /tmp -type f -atime +1 -user "$(whoami)" -delete 2>/dev/null || true

# Maven 임시 파일 정리
rm -rf /tmp/m2-repo-* 2>/dev/null || true
rm -rf ~/.m2/repository/.cache 2>/dev/null || true

# Node.js 캐시 정리
npm cache clean --force 2>/dev/null || true
rm -rf ~/.npm/_cacache 2>/dev/null || true

log_success "임시 파일 정리 완료"

# 4. 프로젝트 빌드 아티팩트 정리
log_info "프로젝트 빌드 아티팩트 정리 중..."

# Backend 빌드 아티팩트
if [ -d "backend/backend/target" ]; then
    # JAR 파일 제외하고 나머지 정리
    find backend/backend/target -type f ! -name "*.jar" -delete 2>/dev/null || true
    find backend/backend/target -type d -empty -delete 2>/dev/null || true
fi

# Frontend 빌드 캐시 정리
rm -rf frontend/node_modules/.cache 2>/dev/null || true
rm -rf frontend/.next 2>/dev/null || true

log_success "빌드 아티팩트 정리 완료"

# 5. 메모리 최적화
log_info "메모리 최적화 실행 중..."

# 페이지 캐시 정리 (안전한 방법)
sync
echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

# Swap 사용량 확인 및 최적화
SWAP_USAGE=$(free | grep '^Swap:' | awk '{if($2>0) printf("%.1f", ($3/$2) * 100.0); else print "0"}')
if (( $(echo "$SWAP_USAGE > 50" | bc -l 2>/dev/null || echo "0") )); then
    log_warning "Swap 사용량이 ${SWAP_USAGE}%로 높습니다"
    echo "메모리 부족 시 서비스 재시작을 고려하세요"
fi

log_success "메모리 최적화 완료"

# 6. 서비스별 메모리 최적화
log_info "서비스별 메모리 최적화..."

# Java 애플리케이션 가비지 컬렉션 실행 (Backend가 실행 중인 경우)
if docker ps --format '{{.Names}}' | grep -q friendi-backend; then
    # JVM 힙 덤프 정리 (있다면)
    docker exec friendi-backend find /app -name "*.hprof" -delete 2>/dev/null || true
    log_success "Backend JVM 최적화 완료"
fi

# PostgreSQL 통계 정보 업데이트
if docker ps --format '{{.Names}}' | grep -q friendi-postgres; then
    docker exec friendi-postgres psql -U friendlyi_user -d friendlyi -c "VACUUM ANALYZE;" 2>/dev/null || true
    log_success "PostgreSQL 최적화 완료"
fi

# Redis 메모리 최적화
if docker ps --format '{{.Names}}' | grep -q friendi-redis; then
    docker exec friendi-redis redis-cli FLUSHALL 2>/dev/null || log_warning "Redis 정리 실패 (데이터가 삭제될 수 있음)"
fi

# 7. 정리 후 상태 확인
log_info "정리 후 상태 확인"
echo ""
echo "정리 후 상태:"
free -h | head -2
df -h / | tail -1

# 사용 가능한 메모리 확인
AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$AVAILABLE_MEM" -gt 500 ]; then
    log_success "사용 가능한 메모리: ${AVAILABLE_MEM}MB (충분함)"
elif [ "$AVAILABLE_MEM" -gt 200 ]; then
    log_warning "사용 가능한 메모리: ${AVAILABLE_MEM}MB (보통)"
else
    log_error "사용 가능한 메모리: ${AVAILABLE_MEM}MB (부족함)"
    echo "서비스 재시작 또는 인스턴스 재부팅을 고려하세요"
fi

# 8. 자동 정리 설정 제안
echo ""
log_info "자동 정리 설정 제안"
echo "==================="
echo ""
echo "정기적인 정리를 위해 cron 작업 설정을 고려하세요:"
echo ""
echo "# 매일 새벽 2시에 정리 실행"
echo "0 2 * * * /path/to/cleanup-resources.sh >/dev/null 2>&1"
echo ""
echo "# 매주 일요일에 전체 정리"
echo "0 3 * * 0 docker system prune -af && docker volume prune -f"
echo ""
echo "설정 방법: crontab -e"

echo ""
log_success "리소스 정리 및 최적화 완료!"
echo ""
echo "📊 정리 효과를 확인하려면 다음 명령어를 실행하세요:"
echo "   ./monitor-ec2.sh"