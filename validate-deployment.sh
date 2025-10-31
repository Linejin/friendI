#!/bin/bash

# Pre-deployment Validation Script
# AWS EC2 t3.small 환경 배포 전 최종 검증

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Check Docker Compose files
check_docker_compose() {
    echo_info "Docker Compose 파일 검증 중..."
    
    if ! command -v docker-compose &> /dev/null; then
        echo_warning "docker-compose 명령어를 찾을 수 없습니다. Docker가 설치되어 있는지 확인하세요."
        return 0  # Skip this check in non-Docker environments
    fi
    
    # Check standard compose file
    if docker-compose -f docker-compose.yml config >/dev/null 2>&1; then
        echo_success "docker-compose.yml 검증 완료"
    else
        echo_error "docker-compose.yml 설정 오류"
        return 1
    fi
    
    # Check low memory compose file
    if docker-compose -f docker-compose.lowmem.yml config >/dev/null 2>&1; then
        echo_success "docker-compose.lowmem.yml 검증 완료"
    else
        echo_error "docker-compose.lowmem.yml 설정 오류"
        return 1
    fi
}

# Check required files
check_required_files() {
    echo_info "필수 파일 존재 여부 확인 중..."
    
    local required_files=(
        "backend/backend/Dockerfile"
        "backend/backend/pom.xml"
        "frontend/Dockerfile"
        "frontend/package.json"
        "docker-compose.yml"
        "docker-compose.lowmem.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo_success "$file 존재 확인"
        else
            echo_error "$file 파일이 존재하지 않습니다"
            return 1
        fi
    done
}

# Check script permissions
check_script_permissions() {
    echo_info "스크립트 실행 권한 확인 중..."
    
    local scripts=(
        "deploy-initial.sh"
        "redeploy-zero-downtime.sh"
        "monitor-ec2.sh"
        "setup-permissions.sh"
        "setup-ec2-initial.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            echo_success "$script 실행 권한 확인"
        else
            echo_warning "$script 실행 권한 없음 - chmod +x로 설정하세요"
        fi
    done
}

# Memory calculation for t3.small
check_memory_allocation() {
    echo_info "메모리 할당 검증 중..."
    
    # t3.small has 2GB (2048MB) RAM
    local total_ram=2048
    local backend_limit=768  # from lowmem config
    local frontend_limit=128 # from lowmem config
    local system_reserved=512 # for OS and other processes
    local swap_size=2048     # 2GB swap
    
    local total_allocated=$((backend_limit + frontend_limit + system_reserved))
    local available_ram=$((total_ram - total_allocated))
    
    echo_info "메모리 할당 분석:"
    echo "  - 총 RAM: ${total_ram}MB"
    echo "  - 백엔드: ${backend_limit}MB"
    echo "  - 프론트엔드: ${frontend_limit}MB"
    echo "  - 시스템 예약: ${system_reserved}MB"
    echo "  - 여유 메모리: ${available_ram}MB"
    echo "  - 스왑 메모리: ${swap_size}MB"
    
    if [ $available_ram -ge 0 ]; then
        echo_success "메모리 할당이 안전한 범위 내에 있습니다"
    else
        echo_warning "메모리 할당이 타이트합니다. 스왑 메모리에 의존할 수 있습니다"
    fi
}

# Check port conflicts
check_port_conflicts() {
    echo_info "포트 충돌 검사 중..."
    
    local ports=(80 8080 22)
    
    for port in "${ports[@]}"; do
        if command -v ss >/dev/null 2>&1; then
            if ss -tuln | grep -q ":${port} "; then
                echo_warning "포트 ${port}이 이미 사용 중입니다"
            else
                echo_success "포트 ${port} 사용 가능"
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tuln | grep -q ":${port} "; then
                echo_warning "포트 ${port}이 이미 사용 중입니다"
            else
                echo_success "포트 ${port} 사용 가능"
            fi
        else
            echo_info "포트 검사 도구를 찾을 수 없습니다 (ss 또는 netstat)"
        fi
    done
}

# Security check
check_security() {
    echo_info "보안 설정 검사 중..."
    
    # Check if default passwords are changed
    if grep -q "admin123" backend/backend/src/main/resources/application*.properties 2>/dev/null; then
        echo_warning "기본 패스워드가 발견되었습니다. 변경을 권장합니다"
    else
        echo_success "패스워드 설정 확인"
    fi
    
    # Check H2 console settings
    if grep -q "H2_CONSOLE_ENABLED=false" docker-compose*.yml; then
        echo_success "H2 콘솔이 안전하게 비활성화됨"
    else
        echo_warning "H2 콘솔 설정을 확인하세요"
    fi
}

# Main validation
main() {
    echo_info "=== FriendlyI 배포 전 검증 시작 ==="
    echo
    
    local checks=(
        "check_required_files"
        "check_docker_compose"
        "check_script_permissions"
        "check_memory_allocation"
        "check_port_conflicts"
        "check_security"
    )
    
    local failed=0
    
    for check in "${checks[@]}"; do
        if ! $check; then
            ((failed++))
        fi
        echo
    done
    
    echo_info "=== 검증 결과 ==="
    if [ $failed -eq 0 ]; then
        echo_success "모든 검증을 통과했습니다! 배포를 진행할 수 있습니다."
        echo_info "배포 명령: ./deploy-initial.sh"
    else
        echo_error "${failed}개의 검증에 실패했습니다. 문제를 해결한 후 다시 시도하세요."
        return 1
    fi
}

# Run validation
main "$@"