#!/bin/bash
# 무중단 배포 스크립트 (Zero-Downtime Deployment)

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
    echo "    🚀 FriendlyI 무중단 배포 (Zero-Downtime)"
    echo "    📦 기존 서비스 감지 및 안전한 업데이트"
    echo "=================================================="
    echo -e "${NC}"
}

# 기존 서비스 상태 확인
check_existing_services() {
    log_info "기존 서비스 상태 확인 중..."
    
    # Docker Compose 서비스 확인
    EXISTING_SERVICES=$(docker-compose ps --services 2>/dev/null || echo "")
    RUNNING_SERVICES=$(docker-compose ps --filter status=running --services 2>/dev/null || echo "")
    
    # 개별 PostgreSQL 컨테이너 확인
    POSTGRES_CONTAINERS=$(docker ps --filter "name=postgres" --filter "status=running" --format "{{.Names}}" 2>/dev/null || echo "")
    
    # 포트 사용 확인
    PORT_5432=$(netstat -tlnp 2>/dev/null | grep ":5432" || echo "")
    PORT_5433=$(netstat -tlnp 2>/dev/null | grep ":5433" || echo "")
    PORT_8080=$(netstat -tlnp 2>/dev/null | grep ":8080" || echo "")
    PORT_80=$(netstat -tlnp 2>/dev/null | grep ":80" || echo "")
    
    echo "🔍 기존 서비스 상태:"
    echo "  - Docker Compose 서비스: $EXISTING_SERVICES"
    echo "  - 실행 중인 서비스: $RUNNING_SERVICES"
    echo "  - PostgreSQL 컨테이너: $POSTGRES_CONTAINERS"
    echo "  - 포트 5432 사용: $([ -n "$PORT_5432" ] && echo "사용 중" || echo "사용 가능")"
    echo "  - 포트 5433 사용: $([ -n "$PORT_5433" ] && echo "사용 중" || echo "사용 가능")"
    echo "  - 포트 8080 사용: $([ -n "$PORT_8080" ] && echo "사용 중" || echo "사용 가능")"
    echo "  - 포트 80 사용: $([ -n "$PORT_80" ] && echo "사용 중" || echo "사용 가능")"
    
    # 전역 변수 설정
    HAS_EXISTING_POSTGRES=$([ -n "$POSTGRES_CONTAINERS" ] && echo "true" || echo "false")
    HAS_RUNNING_SERVICES=$([ -n "$RUNNING_SERVICES" ] && echo "true" || echo "false")
}

# 데이터 백업
backup_data() {
    if [ "$HAS_EXISTING_POSTGRES" = "true" ]; then
        log_info "PostgreSQL 데이터 백업 중..."
        
        BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # 실행 중인 PostgreSQL에서 백업
        for container in $POSTGRES_CONTAINERS; do
            log_info "컨테이너 $container에서 데이터 백업 중..."
            docker exec "$container" pg_dumpall -U postgres > "$BACKUP_DIR/${container}_backup.sql" 2>/dev/null || \
            docker exec "$container" pg_dumpall -U friendlyi_user > "$BACKUP_DIR/${container}_backup.sql" 2>/dev/null || \
            log_warning "컨테이너 $container 백업 실패 (권한 문제일 수 있음)"
        done
        
        # Docker 볼륨 백업
        if docker volume ls | grep -q postgres; then
            log_info "PostgreSQL 볼륨 백업 중..."
            docker run --rm -v postgres_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/postgres_volume_backup.tar.gz -C /data . 2>/dev/null || \
            log_warning "볼륨 백업 실패"
        fi
        
        log_success "백업 완료: $BACKUP_DIR"
    else
        log_info "백업할 기존 PostgreSQL 데이터가 없습니다."
    fi
}

# 무중단 업데이트 전략
zero_downtime_update() {
    log_info "무중단 업데이트 전략 실행 중..."
    
    if [ "$HAS_RUNNING_SERVICES" = "true" ]; then
        log_info "기존 서비스가 실행 중입니다. 단계적 업데이트를 수행합니다."
        
        # 1단계: Frontend 먼저 업데이트 (더 빠름)
        if echo "$RUNNING_SERVICES" | grep -q "frontend"; then
            log_info "1단계: Frontend 업데이트 중..."
            docker-compose up -d --no-deps frontend
            
            # Frontend 헬스체크
            sleep 15
            if curl -f http://localhost:80 >/dev/null 2>&1 || curl -f http://localhost:3000 >/dev/null 2>&1; then
                log_success "✅ Frontend 업데이트 완료"
            else
                log_warning "⚠️ Frontend 헬스체크 실패"
            fi
        fi
        
        # 2단계: Backend 업데이트
        if echo "$RUNNING_SERVICES" | grep -q "backend"; then
            log_info "2단계: Backend 업데이트 중..."
            docker-compose up -d --no-deps backend
            
            # Backend 헬스체크
            sleep 30
            if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
                log_success "✅ Backend 업데이트 완료"
            else
                log_warning "⚠️ Backend 헬스체크 실패"
            fi
        fi
        
        # 3단계: 데이터베이스 업데이트 (가장 신중하게)
        if echo "$RUNNING_SERVICES" | grep -q "postgres" || [ "$HAS_EXISTING_POSTGRES" = "true" ]; then
            log_info "3단계: PostgreSQL 업데이트 중..."
            
            # 기존 PostgreSQL 설정 확인
            EXISTING_DB_VERSION=$(docker exec ${POSTGRES_CONTAINERS%% *} psql -U postgres -c "SELECT version();" 2>/dev/null | grep PostgreSQL || echo "확인 불가")
            log_info "기존 DB 버전: $EXISTING_DB_VERSION"
            
            # 포트 충돌 방지
            if [ -n "$PORT_5432" ]; then
                log_warning "5432 포트가 사용 중입니다. 5433 포트를 사용합니다."
                sed -i 's/5432:5432/5433:5432/g' docker-compose.yml 2>/dev/null || true
            fi
            
            # PostgreSQL 점진적 업데이트
            docker-compose up -d --no-deps postgres
            
            # PostgreSQL 시작 대기
            log_info "PostgreSQL 시작 대기 중... (60초)"
            sleep 60
            
            # PostgreSQL 헬스체크
            if docker-compose ps postgres | grep -q "healthy"; then
                log_success "✅ PostgreSQL 업데이트 완료"
            else
                log_error "❌ PostgreSQL 업데이트 실패"
                return 1
            fi
        fi
        
        # 4단계: Redis 업데이트
        if echo "$RUNNING_SERVICES" | grep -q "redis"; then
            log_info "4단계: Redis 업데이트 중..."
            docker-compose up -d --no-deps redis
            
            sleep 10
            if docker-compose ps redis | grep -q "healthy"; then
                log_success "✅ Redis 업데이트 완료"
            else
                log_warning "⚠️ Redis 헬스체크 실패"
            fi
        fi
        
    else
        log_info "기존 서비스가 없습니다. 전체 스택을 새로 시작합니다."
        
        # 포트 충돌 방지
        if [ -n "$PORT_5432" ]; then
            log_warning "5432 포트가 사용 중입니다. 5433 포트를 사용합니다."
            sed -i 's/5432:5432/5433:5432/g' docker-compose.yml 2>/dev/null || true
        fi
        
        # 전체 스택 시작
        docker-compose up -d
    fi
}

# 서비스 상태 확인 및 롤백 준비
verify_deployment() {
    log_info "배포 상태 검증 중..."
    
    # 60초 대기
    log_info "서비스 안정화 대기 중... (60초)"
    sleep 60
    
    # 각 서비스 헬스체크
    HEALTH_STATUS=""
    
    # PostgreSQL 체크
    if docker-compose ps postgres | grep -q "healthy"; then
        HEALTH_STATUS="$HEALTH_STATUS✅ PostgreSQL: 정상\n"
    else
        HEALTH_STATUS="$HEALTH_STATUS❌ PostgreSQL: 비정상\n"
        DEPLOYMENT_FAILED=true
    fi
    
    # Redis 체크
    if docker-compose ps redis | grep -q "healthy"; then
        HEALTH_STATUS="$HEALTH_STATUS✅ Redis: 정상\n"
    else
        HEALTH_STATUS="$HEALTH_STATUS❌ Redis: 비정상\n"
        DEPLOYMENT_FAILED=true
    fi
    
    # Backend 체크
    if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        HEALTH_STATUS="$HEALTH_STATUS✅ Backend: 정상\n"
    else
        HEALTH_STATUS="$HEALTH_STATUS❌ Backend: 비정상\n"
        DEPLOYMENT_FAILED=true
    fi
    
    # Frontend 체크
    if curl -f http://localhost:80 >/dev/null 2>&1 || curl -f http://localhost:3000 >/dev/null 2>&1; then
        HEALTH_STATUS="$HEALTH_STATUS✅ Frontend: 정상\n"
    else
        HEALTH_STATUS="$HEALTH_STATUS❌ Frontend: 비정상\n"
        DEPLOYMENT_FAILED=true
    fi
    
    echo -e "\n📊 배포 결과:"
    echo -e "$HEALTH_STATUS"
    
    if [ "$DEPLOYMENT_FAILED" = "true" ]; then
        log_error "❌ 배포에 실패한 서비스가 있습니다."
        
        echo -n "롤백을 수행하시겠습니까? (y/N): "
        read -r ROLLBACK_CHOICE
        
        if [ "$ROLLBACK_CHOICE" = "y" ] || [ "$ROLLBACK_CHOICE" = "Y" ]; then
            perform_rollback
        fi
        
        return 1
    else
        log_success "🎉 모든 서비스가 정상적으로 배포되었습니다!"
        return 0
    fi
}

# 롤백 수행
perform_rollback() {
    log_warning "🔄 롤백을 수행합니다..."
    
    # 최근 백업 찾기
    LATEST_BACKUP=$(ls -t ./backups/ 2>/dev/null | head -1)
    
    if [ -n "$LATEST_BACKUP" ] && [ -d "./backups/$LATEST_BACKUP" ]; then
        log_info "백업에서 복원 중: $LATEST_BACKUP"
        
        # PostgreSQL 데이터 복원
        if [ -f "./backups/$LATEST_BACKUP"/*_backup.sql ]; then
            BACKUP_FILE=$(ls "./backups/$LATEST_BACKUP"/*_backup.sql | head -1)
            docker exec -i $(docker-compose ps -q postgres) psql -U postgres < "$BACKUP_FILE" 2>/dev/null || \
            log_warning "데이터 복원 실패"
        fi
        
        log_success "롤백 완료"
    else
        log_warning "백업을 찾을 수 없어 롤백할 수 없습니다."
    fi
}

# 배포 후 정보 표시
show_deployment_info() {
    echo
    log_success "🚀 무중단 배포 완료!"
    
    # 실제 접속 정보
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "IP확인실패")
    
    echo "📋 서비스 접속 정보:"
    echo "   🌐 Frontend: http://$PUBLIC_IP/"
    echo "   🔧 Backend API: http://$PUBLIC_IP:8080"
    echo "   📊 API 문서: http://$PUBLIC_IP:8080/swagger-ui.html"
    echo "   💾 헬스체크: http://$PUBLIC_IP:8080/actuator/health"
    
    echo
    echo "📊 현재 실행 중인 서비스:"
    docker-compose ps
    
    echo
    echo "🛠️ 관리 명령어:"
    echo "   전체 로그: docker-compose logs -f"
    echo "   서비스 재시작: docker-compose restart [service-name]"
    echo "   서비스 중지: docker-compose down"
    echo "   상태 확인: docker-compose ps"
}

# 메인 실행 함수
main() {
    print_banner
    
    check_existing_services
    backup_data
    zero_downtime_update
    
    if verify_deployment; then
        show_deployment_info
        log_success "✅ 무중단 배포가 성공적으로 완료되었습니다!"
    else
        log_error "❌ 배포 중 문제가 발생했습니다."
        exit 1
    fi
}

# 스크립트 실행
main "$@"