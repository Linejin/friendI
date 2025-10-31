#!/bin/bash

# Zero Downtime Redeployment Script for FriendlyI
# Rolling update with health checks

set -e
trap 'echo "❌ Error occurred on line $LINENO. Exit code: $?" >&2' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_NAME="friendlyi"
HEALTH_CHECK_URL="http://localhost:8080/actuator/health"
FRONTEND_URL="http://localhost:80"
BACKUP_DIR="./backups"
MAX_HEALTH_CHECK_ATTEMPTS=30
HEALTH_CHECK_INTERVAL=10

echo_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to create backup
create_backup() {
    echo_info "백업 생성 중..."
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/backup_$timestamp.tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup logs and data
    tar -czf "$backup_file" \
        --exclude='node_modules' \
        --exclude='target' \
        --exclude='build' \
        logs/ data/ docker-compose.yml .env 2>/dev/null || true
    
    echo_success "백업 생성 완료: $backup_file"
    
    # Keep only last 5 backups
    ls -t "$BACKUP_DIR"/backup_*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null || true
}

# Function to check service health
check_service_health() {
    local service_url=$1
    local service_name=$2
    local attempt=1
    
    echo_info "$service_name 서비스 상태 확인 중..."
    
    while [ $attempt -le $MAX_HEALTH_CHECK_ATTEMPTS ]; do
        if curl -f -s "$service_url" >/dev/null 2>&1; then
            echo_success "$service_name 서비스가 정상 상태입니다."
            return 0
        fi
        
        echo_info "$service_name 상태 확인 중... ($attempt/$MAX_HEALTH_CHECK_ATTEMPTS)"
        sleep $HEALTH_CHECK_INTERVAL
        ((attempt++))
    done
    
    echo_error "$service_name 서비스가 응답하지 않습니다."
    return 1
}

# Function to get current git commit
get_current_commit() {
    git rev-parse HEAD 2>/dev/null || echo "unknown"
}

# Function to pull latest changes
pull_latest_changes() {
    echo_info "최신 코드 확인 중..."
    
    if [ ! -d ".git" ]; then
        echo_warning "Git 저장소가 아닙니다. 코드 업데이트를 건너뜁니다."
        return 0
    fi
    
    local current_commit=$(get_current_commit)
    
    git fetch origin master
    local latest_commit=$(git rev-parse origin/master)
    
    if [ "$current_commit" = "$latest_commit" ]; then
        echo_info "이미 최신 버전입니다."
        read -p "강제로 재배포하시겠습니까? (y/n): " force_deploy
        if [ "$force_deploy" != "y" ] && [ "$force_deploy" != "Y" ]; then
            echo_info "재배포를 취소합니다."
            exit 0
        fi
    else
        echo_info "새로운 커밋이 있습니다. 업데이트합니다..."
        git pull origin master
        echo_success "코드 업데이트 완료"
    fi
}

# Function to rolling update backend
rolling_update_backend() {
    echo_info "백엔드 롤링 업데이트 시작..."
    
    # Detect compose file to use
    local compose_file="docker-compose.yml"
    if [ -f ".compose_file_used" ]; then
        compose_file=$(cat .compose_file_used)
    elif [ "$(free -m | awk 'NR==2{print $2}')" -lt 3000 ]; then
        compose_file="docker-compose.lowmem.yml"
    fi
    
    # Build new backend image
    echo_info "새 백엔드 이미지 빌드 중... (사용 파일: $compose_file)"
    docker-compose -f "$compose_file" build backend
    
    # Get current backend container ID
    local old_container=$(docker-compose ps -q backend)
    
    if [ -n "$old_container" ]; then
        echo_info "기존 백엔드 컨테이너 발견: $old_container"
        
        # Start new backend container with different name
        docker-compose up -d --no-deps --scale backend=2 backend
        
        # Wait for new container to be healthy
        sleep 20
        
        if check_service_health "$HEALTH_CHECK_URL" "새 백엔드"; then
            echo_info "기존 백엔드 컨테이너 중지 중..."
            docker stop "$old_container" || true
            docker rm "$old_container" || true
            
            # Scale back to 1
            docker-compose up -d --no-deps --scale backend=1 backend
            
            echo_success "백엔드 롤링 업데이트 완료"
        else
            echo_error "새 백엔드 컨테이너가 정상적으로 시작되지 않았습니다."
            echo_info "기존 컨테이너로 롤백합니다..."
            docker-compose up -d --no-deps --scale backend=1 backend
            return 1
        fi
    else
        # No existing container, just start new one
        docker-compose up -d --no-deps backend
        check_service_health "$HEALTH_CHECK_URL" "백엔드"
    fi
}

# Function to rolling update frontend
rolling_update_frontend() {
    echo_info "프론트엔드 롤링 업데이트 시작..."
    
    # Build new frontend image
    echo_info "새 프론트엔드 이미지 빌드 중..."
    docker-compose build frontend
    
    # Get current frontend container ID
    local old_container=$(docker-compose ps -q frontend)
    
    if [ -n "$old_container" ]; then
        echo_info "기존 프론트엔드 컨테이너 발견: $old_container"
        
        # Start new frontend container
        docker-compose up -d --no-deps --scale frontend=2 frontend
        
        # Wait a bit for the new container to start
        sleep 15
        
        if check_service_health "$FRONTEND_URL" "새 프론트엔드"; then
            echo_info "기존 프론트엔드 컨테이너 중지 중..."
            docker stop "$old_container" || true
            docker rm "$old_container" || true
            
            # Scale back to 1
            docker-compose up -d --no-deps --scale frontend=1 frontend
            
            echo_success "프론트엔드 롤링 업데이트 완료"
        else
            echo_error "새 프론트엔드 컨테이너가 정상적으로 시작되지 않았습니다."
            echo_info "기존 컨테이너로 롤백합니다..."
            docker-compose up -d --no-deps --scale frontend=1 frontend
            return 1
        fi
    else
        # No existing container, just start new one
        docker-compose up -d --no-deps frontend
        check_service_health "$FRONTEND_URL" "프론트엔드"
    fi
}

# Function to cleanup unused images
cleanup_images() {
    echo_info "미사용 Docker 이미지 정리 중..."
    
    # Remove dangling images
    docker image prune -f
    
    # Remove unused images (keep recent ones)
    docker images --filter "dangling=false" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}" | \
    grep "$PROJECT_NAME" | \
    tail -n +6 | \
    awk '{print $3}' | \
    xargs -r docker rmi 2>/dev/null || true
    
    echo_success "이미지 정리 완료"
}

# Function to show status
show_status() {
    echo_success "=== 재배포 완료 ==="
    
    echo_info "현재 서비스 상태:"
    docker-compose ps
    
    echo
    echo_info "서비스 URL:"
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/ || echo "확인 불가")
    echo "  - Frontend: http://$PUBLIC_IP"
    echo "  - Backend API: http://$PUBLIC_IP:8080"
    echo "  - Health Check: http://$PUBLIC_IP:8080/actuator/health"
    
    echo
    echo_info "리소스 사용량:"
    docker stats --no-stream
}

# Function to rollback if needed
rollback() {
    echo_warning "롤백을 시작합니다..."
    
    # Find latest backup
    local latest_backup=$(ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -1)
    
    if [ -n "$latest_backup" ]; then
        echo_info "백업에서 복원 중: $latest_backup"
        tar -xzf "$latest_backup"
        docker-compose up -d
        echo_success "롤백 완료"
    else
        echo_error "사용 가능한 백업이 없습니다."
        echo_info "수동으로 이전 버전으로 되돌려야 합니다."
    fi
}

# Main function
main() {
    echo_info "FriendlyI 무중단 재배포를 시작합니다..."
    
    cd "$SCRIPT_DIR"
    
    # Create backup before deployment
    create_backup
    
    # Pull latest changes
    pull_latest_changes
    
    # Update services with zero downtime
    if rolling_update_backend && rolling_update_frontend; then
        echo_success "무중단 재배포가 완료되었습니다!"
        
        # Cleanup
        cleanup_images
        
        # Show status
        show_status
    else
        echo_error "재배포 중 오류가 발생했습니다."
        read -p "롤백하시겠습니까? (y/n): " do_rollback
        if [ "$do_rollback" = "y" ] || [ "$do_rollback" = "Y" ]; then
            rollback
        fi
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "rollback")
        rollback
        exit 0
        ;;
    "status")
        show_status
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
