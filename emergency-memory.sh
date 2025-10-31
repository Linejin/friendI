#!/bin/bash
# EC2 t3.small 메모리 부족 시 자동 복구 스크립트

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

# 메모리 상태 확인
check_memory() {
    local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    local memory_usage=$(free | grep '^Mem:' | awk '{printf("%.1f", ($3/$2) * 100.0)}')
    
    echo "$available_mem:$memory_usage"
}

# 긴급 메모리 정리
emergency_cleanup() {
    log_warning "긴급 메모리 정리 실행..."
    
    # 1. 페이지 캐시 정리
    sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
    
    # 2. Docker 리소스 정리
    docker system prune -f >/dev/null 2>&1 || true
    docker builder prune -af >/dev/null 2>&1 || true
    
    # 3. 임시 파일 정리
    find /tmp -type f -atime +0 -size +10M -delete 2>/dev/null || true
    
    # 4. 로그 파일 정리
    find /var/log -name "*.log" -size +50M -exec truncate -s 10M {} \; 2>/dev/null || true
    
    log_success "긴급 정리 완료"
}

# OOM 킬러 방지를 위한 서비스 우선순위 조정
adjust_oom_score() {
    local service_name=$1
    local score=$2
    
    local pid=$(docker inspect -f '{{.State.Pid}}' "$service_name" 2>/dev/null || echo "")
    if [ -n "$pid" ] && [ "$pid" != "0" ]; then
        echo "$score" | sudo tee "/proc/$pid/oom_score_adj" >/dev/null 2>&1 || true
    fi
}

# 메인 실행
main() {
    local mem_info=$(check_memory)
    local available_mem=$(echo "$mem_info" | cut -d: -f1)
    local memory_usage=$(echo "$mem_info" | cut -d: -f2)
    
    log_info "현재 메모리 상태: ${memory_usage}% 사용, ${available_mem}MB 사용 가능"
    
    # 메모리 사용량이 90% 이상이거나 사용 가능한 메모리가 200MB 미만인 경우
    if (( $(echo "$memory_usage > 90" | bc -l) )) || [ "$available_mem" -lt 200 ]; then
        log_error "심각한 메모리 부족 상태"
        emergency_cleanup
        
        # 서비스 우선순위 조정 (낮은 값 = 높은 우선순위, 먼저 종료되지 않음)
        adjust_oom_score "friendi-postgres" -900   # 데이터베이스는 가장 보호
        adjust_oom_score "friendi-redis" -800      # Redis도 높은 우선순위
        adjust_oom_score "friendi-backend" -500    # Backend 보호
        adjust_oom_score "friendi-frontend" 100    # Frontend는 상대적으로 낮은 우선순위
        
        # 재확인
        local mem_info_after=$(check_memory)
        local available_mem_after=$(echo "$mem_info_after" | cut -d: -f1)
        
        if [ "$available_mem_after" -lt 150 ]; then
            log_error "정리 후에도 메모리 부족. 서비스 재시작 필요"
            return 1
        else
            log_success "메모리 정리 성공: ${available_mem_after}MB 확보"
        fi
    elif (( $(echo "$memory_usage > 80" | bc -l) )) || [ "$available_mem" -lt 400 ]; then
        log_warning "메모리 사용량 높음. 예방적 정리 실행"
        
        # 가벼운 정리
        sync && echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
        docker system prune -f >/dev/null 2>&1 || true
        
        log_success "예방적 정리 완료"
    else
        log_success "메모리 상태 양호"
    fi
    
    return 0
}

# 스크립트 실행
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi