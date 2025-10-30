#!/bin/bash
# EC2 디스크 용량 부족 긴급 해결 스크립트

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
    echo -e "${RED}"
    echo "=================================================="
    echo "    🆘 EC2 디스크 용량 부족 긴급 해결"
    echo "    💾 디스크 정리 및 공간 확보"
    echo "=================================================="
    echo -e "${NC}"
}

# 현재 디스크 사용량 확인
check_disk_usage() {
    log_info "현재 디스크 사용량 확인 중..."
    
    echo "📊 디스크 사용량:"
    df -h
    
    echo -e "\n📊 메모리 사용량:"
    free -h
    
    echo -e "\n📊 큰 디렉토리 확인 (상위 10개):"
    du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10 || true
    
    # 루트 파티션 사용량 확인
    ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$ROOT_USAGE" -gt 90 ]; then
        log_error "⚠️ 루트 파티션 사용률: ${ROOT_USAGE}% (위험 수준)"
        CRITICAL_DISK=true
    elif [ "$ROOT_USAGE" -gt 80 ]; then
        log_warning "⚠️ 루트 파티션 사용률: ${ROOT_USAGE}% (주의 필요)"
        CRITICAL_DISK=false
    else
        log_info "✅ 루트 파티션 사용률: ${ROOT_USAGE}% (양호)"
        CRITICAL_DISK=false
    fi
}

# Docker 관련 정리
cleanup_docker() {
    log_info "Docker 리소스 정리 중..."
    
    # 사용하지 않는 Docker 리소스 정리
    log_info "사용하지 않는 Docker 컨테이너 정리..."
    docker container prune -f 2>/dev/null || true
    
    log_info "사용하지 않는 Docker 이미지 정리..."
    docker image prune -f 2>/dev/null || true
    
    log_info "사용하지 않는 Docker 볼륨 정리..."
    docker volume prune -f 2>/dev/null || true
    
    log_info "사용하지 않는 Docker 네트워크 정리..."
    docker network prune -f 2>/dev/null || true
    
    # Build cache 정리
    log_info "Docker build cache 정리..."
    docker builder prune -f 2>/dev/null || true
    
    # 모든 Docker 시스템 정리
    log_info "Docker 시스템 전체 정리..."
    docker system prune -a -f 2>/dev/null || true
    
    log_success "Docker 리소스 정리 완료"
}

# 시스템 캐시 및 로그 정리
cleanup_system() {
    log_info "시스템 캐시 및 로그 정리 중..."
    
    # APT 캐시 정리
    log_info "APT 캐시 정리..."
    sudo apt-get clean 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    
    # 시스템 로그 정리
    log_info "시스템 로그 정리..."
    sudo journalctl --vacuum-time=3d 2>/dev/null || true
    sudo journalctl --vacuum-size=100M 2>/dev/null || true
    
    # tmp 디렉토리 정리
    log_info "임시 파일 정리..."
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null || true
    sudo find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # Core dumps 정리
    log_info "Core dump 파일 정리..."
    sudo find /var/crash -name "*.crash" -delete 2>/dev/null || true
    
    log_success "시스템 정리 완료"
}

# Maven 캐시 정리
cleanup_maven() {
    log_info "Maven 캐시 정리 중..."
    
    # Maven 로컬 저장소 정리
    if [ -d "/root/.m2/repository" ]; then
        log_info "Maven 로컬 저장소 크기 확인..."
        du -sh /root/.m2/repository 2>/dev/null || true
        
        # 오래된 아티팩트 정리
        log_info "7일 이상 된 Maven 아티팩트 정리..."
        find /root/.m2/repository -name "*.jar" -atime +7 -delete 2>/dev/null || true
        find /root/.m2/repository -name "*.pom" -atime +7 -delete 2>/dev/null || true
        find /root/.m2/repository -name "*lastUpdated*" -delete 2>/dev/null || true
        
        # 빈 디렉토리 정리
        find /root/.m2/repository -type d -empty -delete 2>/dev/null || true
        
        log_info "정리 후 Maven 저장소 크기:"
        du -sh /root/.m2/repository 2>/dev/null || true
    fi
    
    # 사용자별 Maven 캐시도 정리
    for user_home in /home/*/; do
        if [ -d "${user_home}.m2/repository" ]; then
            log_info "사용자 Maven 캐시 정리: $user_home"
            find "${user_home}.m2/repository" -name "*lastUpdated*" -delete 2>/dev/null || true
        fi
    done
    
    log_success "Maven 캐시 정리 완료"
}

# 백업 및 로그 파일 정리
cleanup_logs() {
    log_info "로그 파일 및 백업 정리 중..."
    
    # 오래된 백업 파일 정리
    if [ -d "./backups" ]; then
        log_info "7일 이상 된 백업 파일 정리..."
        find ./backups -type f -mtime +7 -delete 2>/dev/null || true
        find ./backups -type d -empty -delete 2>/dev/null || true
    fi
    
    # 애플리케이션 로그 정리
    if [ -d "./logs" ]; then
        log_info "애플리케이션 로그 정리..."
        find ./logs -name "*.log*" -mtime +3 -delete 2>/dev/null || true
    fi
    
    # 시스템 로그 파일 정리
    log_info "대용량 시스템 로그 파일 정리..."
    sudo find /var/log -name "*.log" -size +100M -delete 2>/dev/null || true
    sudo find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
    
    log_success "로그 파일 정리 완료"
}

# Swap 파일 생성 (메모리 부족 시)
create_swap() {
    log_info "Swap 파일 확인 및 생성..."
    
    # 현재 Swap 상태 확인
    CURRENT_SWAP=$(swapon -s | wc -l)
    
    if [ "$CURRENT_SWAP" -eq 1 ]; then  # 헤더만 있으면 Swap 없음
        log_warning "Swap 파일이 없습니다. 1GB Swap 파일 생성 중..."
        
        # 1GB Swap 파일 생성
        sudo fallocate -l 1G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1024 count=1048576
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        
        # 영구 적용
        if ! grep -q "/swapfile" /etc/fstab; then
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        fi
        
        log_success "✅ 1GB Swap 파일 생성 완료"
    else
        log_info "✅ Swap 이미 활성화됨"
        swapon -s
    fi
}

# 디스크 공간 재확인
final_check() {
    log_info "정리 후 디스크 공간 재확인..."
    
    echo "📊 정리 후 디스크 사용량:"
    df -h
    
    echo -e "\n📊 정리 후 메모리 사용량:"
    free -h
    
    # 개선 정도 계산
    NEW_ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    IMPROVEMENT=$((ROOT_USAGE - NEW_ROOT_USAGE))
    
    if [ "$IMPROVEMENT" -gt 0 ]; then
        log_success "✅ 디스크 공간 ${IMPROVEMENT}% 확보 성공!"
    else
        log_warning "⚠️ 추가 정리가 필요할 수 있습니다"
    fi
    
    # 권장사항
    echo
    log_info "💡 추가 권장사항:"
    if [ "$NEW_ROOT_USAGE" -gt 85 ]; then
        echo "   - EBS 볼륨 크기 증가 고려"
        echo "   - 더 큰 EC2 인스턴스 타입으로 업그레이드"
        echo "   - 외부 스토리지 사용 (S3, EFS 등)"
    else
        echo "   - 정기적인 디스크 정리 스케줄링"
        echo "   - 모니터링 도구 설정"
    fi
}

# 메인 실행
main() {
    print_banner
    
    check_disk_usage
    
    if [ "$CRITICAL_DISK" = "true" ]; then
        log_error "🚨 긴급상황! 즉시 디스크 정리를 시작합니다..."
    fi
    
    cleanup_docker
    cleanup_maven
    cleanup_system
    cleanup_logs
    create_swap
    
    final_check
    
    log_success "🎉 디스크 정리 완료!"
    
    echo
    log_info "다음 단계:"
    echo "1. ./simple-backend-deploy.sh 실행"
    echo "2. 디스크 사용량 정기 모니터링"
    echo "3. 필요시 EBS 볼륨 확장"
}

# 스크립트 실행
main "$@"