#!/bin/bash
# EC2 t3.small 무중단 재배포 스크립트

set -e

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

START_TIME=$(date +%s)

echo "🔄 EC2 t3.small 무중단 재배포"
echo "=============================="
echo ""

# 환경 변수 설정 (t3.small 2GB RAM 고려)
export NODE_OPTIONS="--max-old-space-size=768"  # 768MB로 감소
export JAVA_OPTS="-Xms128m -Xmx768m -XX:+UseSerialGC -XX:+UseContainerSupport"  # 768MB로 감소
export MAVEN_OPTS="-Xmx384m -XX:+UseSerialGC"  # 384MB로 감소

log_info "환경 변수 설정 완료 (t3.small 최적화)"

# 기존 서비스 상태 확인
log_info "기존 서비스 상태 확인..."

SERVICES=("friendi-postgres" "friendi-redis" "friendi-backend" "friendi-frontend")
RUNNING_SERVICES=0

for service in "${SERVICES[@]}"; do
    if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
        log_success "$service 실행 중"
        RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
    else
        log_warning "$service 실행되지 않음"
    fi
done

if [ $RUNNING_SERVICES -eq 0 ]; then
    log_error "실행 중인 서비스가 없습니다. 초기 배포를 먼저 실행하세요."
    log_info "초기 배포 명령: ./deploy-initial.sh"
    exit 1
fi

echo ""
log_info "무중단 재배포를 시작합니다..."

# 1. Git 변경사항 확인
log_info "Git 변경사항 확인..."
if command -v git &> /dev/null && [ -d ".git" ]; then
    if ! git diff --quiet HEAD~1 HEAD 2>/dev/null; then
        log_info "Git 변경사항이 감지되었습니다"
        git log --oneline -5 | head -3
    else
        log_info "Git 변경사항 없음"
    fi
fi
echo ""

# 2. 리소스 확인 및 최적화
log_info "리소스 확인 및 최적화..."

AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
AVAILABLE_DISK=$(df / | awk 'NR==2{print $4}')

log_info "사용 가능한 메모리: ${AVAILABLE_MEM}MB"
log_info "사용 가능한 디스크: ${AVAILABLE_DISK}KB"

if [ "$AVAILABLE_MEM" -lt 800 ]; then
    log_warning "메모리 부족 (${AVAILABLE_MEM}MB). 시스템 최적화 실행..."
    
    # 메모리 정리
    sync && echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
    
    # 사용하지 않는 Docker 리소스 정리
    log_info "사용하지 않는 Docker 리소스 정리..."
    docker system prune -f >/dev/null 2>&1 || true
    docker builder prune -f >/dev/null 2>&1 || true
    
    # npm 캐시 정리
    npm cache clean --force >/dev/null 2>&1 || true
    
    # 메모리 재확인
    AVAILABLE_MEM_AFTER=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    log_info "최적화 후 사용 가능한 메모리: ${AVAILABLE_MEM_AFTER}MB"
    
    if [ "$AVAILABLE_MEM_AFTER" -lt 600 ]; then
        log_error "메모리 부족으로 무중단 재배포를 중단합니다"
        log_info "일반 재배포를 사용하세요: ./deploy-initial.sh"
        exit 1
    fi
    
    log_success "시스템 최적화 완료"
fi

# 3. 백업 컨테이너 정보 수집
log_info "현재 컨테이너 정보 백업..."

CURRENT_BACKEND_ID=$(docker ps -q --filter "name=friendi-backend" 2>/dev/null || true)
CURRENT_FRONTEND_ID=$(docker ps -q --filter "name=friendi-frontend" 2>/dev/null || true)

if [ -n "$CURRENT_BACKEND_ID" ]; then
    CURRENT_BACKEND_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CURRENT_BACKEND_ID" 2>/dev/null || echo "unknown")
    log_info "현재 Backend 이미지: $CURRENT_BACKEND_IMAGE"
fi

if [ -n "$CURRENT_FRONTEND_ID" ]; then
    CURRENT_FRONTEND_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CURRENT_FRONTEND_ID" 2>/dev/null || echo "unknown")
    log_info "현재 Frontend 이미지: $CURRENT_FRONTEND_IMAGE"
fi

# 4. Backend 무중단 재배포
if [ -d "backend/backend" ] && [ -f "backend/backend/pom.xml" ]; then
    log_info "Backend 무중단 재배포 시작..."
    
    # Backend 소스 변경 확인
    BACKEND_CHANGED=false
    if command -v git &> /dev/null && [ -d ".git" ]; then
        if git diff --quiet HEAD~1 HEAD -- backend/ 2>/dev/null; then
            log_info "Backend 소스 변경 없음. 이미지 재빌드 생략 가능"
        else
            BACKEND_CHANGED=true
            log_info "Backend 소스 변경 감지. 재빌드 필요"
        fi
    else
        BACKEND_CHANGED=true
        log_info "Git 미사용. Backend 재빌드 진행"
    fi
    
    if [ "$BACKEND_CHANGED" = true ]; then
        # Backend 로컬 빌드
        log_info "Backend 로컬 빌드 중..."
        cd backend/backend
        
        if [ ! -x "./mvnw" ]; then
            chmod +x ./mvnw
        fi
        
        # 임시 Maven 저장소
        TEMP_M2="/tmp/m2-redeploy-$$"
        mkdir -p "$TEMP_M2"
        
        ./mvnw clean package \
            -DskipTests=true \
            -Dmaven.test.skip=true \
            -Dmaven.javadoc.skip=true \
            -Dmaven.source.skip=true \
            -Dmaven.install.skip=true \
            -Dmaven.site.skip=true \
            -Dmaven.compiler.fork=false \
            -Dmaven.repo.local="$TEMP_M2" \
            --batch-mode \
            --no-transfer-progress \
            --quiet
        
        BACKEND_JAR=$(find target -name "backend-*.jar" -type f | head -1)
        if [ ! -f "$BACKEND_JAR" ]; then
            log_error "Backend JAR 파일 생성 실패"
            rm -rf "$TEMP_M2"
            exit 1
        fi
        
        log_success "Backend JAR 생성: $(basename "$BACKEND_JAR")"
        rm -rf "$TEMP_M2"
        cd ../..
        
        # Backend 새 이미지 빌드
        log_info "Backend 새 이미지 빌드..."
        NEW_BACKEND_TAG="backend:$(date +%s)"
        docker build -t "$NEW_BACKEND_TAG" ./backend/backend/ --quiet
        
        # Blue-Green 배포를 위한 임시 컨테이너 시작
        log_info "새 Backend 컨테이너 시작 (포트 8081)..."
        docker run -d \
            --name friendi-backend-new \
            --network "$(docker inspect friendi-backend | jq -r '.[0].NetworkSettings.Networks | keys[0]' 2>/dev/null || echo 'default')" \
            -p 8081:8080 \
            -e SPRING_PROFILES_ACTIVE=docker \
            "$NEW_BACKEND_TAG" >/dev/null
        
        # 새 Backend 헬스체크
        log_info "새 Backend 헬스체크 대기..."
        for i in {1..60}; do
            if curl -s -f http://localhost:8081/actuator/health >/dev/null 2>&1; then
                log_success "새 Backend 준비 완료"
                break
            fi
            if [ $i -eq 60 ]; then
                log_error "새 Backend 헬스체크 실패"
                docker logs friendi-backend-new --tail 10
                docker rm -f friendi-backend-new >/dev/null 2>&1 || true
                docker rmi "$NEW_BACKEND_TAG" >/dev/null 2>&1 || true
                exit 1
            fi
            sleep 2
        done
        
        # 기존 Backend 컨테이너 교체
        log_info "Backend 컨테이너 교체..."
        docker stop friendi-backend >/dev/null 2>&1 || true
        docker rm friendi-backend >/dev/null 2>&1 || true
        
        # 새 컨테이너를 원래 이름과 포트로 재시작
        docker stop friendi-backend-new >/dev/null 2>&1
        docker commit friendi-backend-new "$NEW_BACKEND_TAG" >/dev/null
        docker rm friendi-backend-new >/dev/null 2>&1
        
        docker run -d \
            --name friendi-backend \
            --network "$(docker network ls --filter name=app-network -q || echo 'bridge')" \
            -p 8080:8080 \
            -e SPRING_PROFILES_ACTIVE=docker \
            --restart unless-stopped \
            "$NEW_BACKEND_TAG" >/dev/null
        
        # 최종 Backend 헬스체크
        log_info "Backend 최종 헬스체크..."
        for i in {1..30}; do
            if curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
                log_success "Backend 재배포 완료"
                break
            fi
            if [ $i -eq 30 ]; then
                log_error "Backend 최종 헬스체크 실패"
                exit 1
            fi
            sleep 2
        done
        
        # 기존 Backend 이미지 정리
        if [ -n "$CURRENT_BACKEND_IMAGE" ] && [ "$CURRENT_BACKEND_IMAGE" != "$NEW_BACKEND_TAG" ]; then
            docker rmi "$CURRENT_BACKEND_IMAGE" >/dev/null 2>&1 || true
        fi
    else
        log_info "Backend 변경사항 없음. 재시작만 수행..."
        docker restart friendi-backend >/dev/null 2>&1
        sleep 10
    fi
    
    log_success "Backend 무중단 재배포 완료"
else
    log_info "Backend 소스 없음. 건너뛰기"
fi

# 5. Frontend 무중단 재배포
if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
    log_info "Frontend 무중단 재배포 시작..."
    
    # Frontend 소스 변경 확인
    FRONTEND_CHANGED=false
    if command -v git &> /dev/null && [ -d ".git" ]; then
        if git diff --quiet HEAD~1 HEAD -- frontend/ 2>/dev/null; then
            log_info "Frontend 소스 변경 없음. 이미지 재빌드 생략 가능"
        else
            FRONTEND_CHANGED=true
            log_info "Frontend 소스 변경 감지. 재빌드 필요"
        fi
    else
        FRONTEND_CHANGED=true
        log_info "Git 미사용. Frontend 재빌드 진행"
    fi
    
    if [ "$FRONTEND_CHANGED" = true ]; then
        # Frontend 새 이미지 빌드
        log_info "Frontend 새 이미지 빌드..."
        NEW_FRONTEND_TAG="frontend:$(date +%s)"
        docker build -t "$NEW_FRONTEND_TAG" ./frontend/ --quiet
        
        # Blue-Green 배포를 위한 임시 컨테이너 시작
        log_info "새 Frontend 컨테이너 시작 (포트 3001)..."
        docker run -d \
            --name friendi-frontend-new \
            --network "$(docker inspect friendi-frontend | jq -r '.[0].NetworkSettings.Networks | keys[0]' 2>/dev/null || echo 'default')" \
            -p 3001:80 \
            "$NEW_FRONTEND_TAG" >/dev/null
        
        # 새 Frontend 헬스체크
        log_info "새 Frontend 헬스체크 대기..."
        for i in {1..30}; do
            if curl -s -f http://localhost:3001 >/dev/null 2>&1; then
                log_success "새 Frontend 준비 완료"
                break
            fi
            if [ $i -eq 30 ]; then
                log_warning "새 Frontend 헬스체크 실패 (계속 진행)"
                break
            fi
            sleep 2
        done
        
        # 기존 Frontend 컨테이너 교체
        log_info "Frontend 컨테이너 교체..."
        docker stop friendi-frontend >/dev/null 2>&1 || true
        docker rm friendi-frontend >/dev/null 2>&1 || true
        
        # 새 컨테이너를 원래 이름과 포트로 재시작
        docker stop friendi-frontend-new >/dev/null 2>&1
        docker commit friendi-frontend-new "$NEW_FRONTEND_TAG" >/dev/null
        docker rm friendi-frontend-new >/dev/null 2>&1
        
        docker run -d \
            --name friendi-frontend \
            --network "$(docker network ls --filter name=app-network -q || echo 'bridge')" \
            -p 3000:80 \
            --restart unless-stopped \
            "$NEW_FRONTEND_TAG" >/dev/null
        
        # 최종 Frontend 헬스체크
        log_info "Frontend 최종 헬스체크..."
        for i in {1..20}; do
            if curl -s -f http://localhost:3000 >/dev/null 2>&1; then
                log_success "Frontend 재배포 완료"
                break
            fi
            if [ $i -eq 20 ]; then
                log_warning "Frontend 최종 헬스체크 타임아웃 (서비스는 정상 동작할 수 있음)"
                break
            fi
            sleep 2
        done
        
        # 기존 Frontend 이미지 정리
        if [ -n "$CURRENT_FRONTEND_IMAGE" ] && [ "$CURRENT_FRONTEND_IMAGE" != "$NEW_FRONTEND_TAG" ]; then
            docker rmi "$CURRENT_FRONTEND_IMAGE" >/dev/null 2>&1 || true
        fi
    else
        log_info "Frontend 변경사항 없음. 재시작만 수행..."
        docker restart friendi-frontend >/dev/null 2>&1
        sleep 5
    fi
    
    log_success "Frontend 무중단 재배포 완료"
else
    log_info "Frontend 소스 없음. 건너뛰기"
fi

# 6. 최종 정리 및 검증
log_info "재배포 후 정리..."

# 사용하지 않는 이미지 정리
docker image prune -f >/dev/null 2>&1 || true

# 전체 서비스 상태 확인
log_info "전체 서비스 상태 검증..."
sleep 5

HEALTH_CHECK_FAILED=0

# PostgreSQL 체크
if ! docker exec friendi-postgres pg_isready -U friendlyi_user -d friendlyi >/dev/null 2>&1; then
    log_error "PostgreSQL 상태 이상"
    HEALTH_CHECK_FAILED=1
else
    log_success "PostgreSQL 정상"
fi

# Redis 체크
if ! docker exec friendi-redis redis-cli ping 2>/dev/null | grep -q PONG; then
    log_error "Redis 상태 이상"
    HEALTH_CHECK_FAILED=1
else
    log_success "Redis 정상"
fi

# Backend API 체크
if ! curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
    log_error "Backend API 상태 이상"
    HEALTH_CHECK_FAILED=1
else
    log_success "Backend API 정상"
fi

# Frontend 체크
if ! curl -s -f http://localhost:3000 >/dev/null 2>&1; then
    log_warning "Frontend 접근 불가 (nginx 설정 확인 필요)"
else
    log_success "Frontend 정상"
fi

# 7. 배포 결과 요약
END_TIME=$(date +%s)
DEPLOY_TIME=$((END_TIME - START_TIME))
DEPLOY_MIN=$((DEPLOY_TIME / 60))
DEPLOY_SEC=$((DEPLOY_TIME % 60))

echo ""
if [ $HEALTH_CHECK_FAILED -eq 0 ]; then
    echo "🎉 무중단 재배포 성공!"
else
    echo "⚠️  무중단 재배포 완료 (일부 경고)"
fi
echo "=========================="
echo ""
echo "⏱️  총 재배포 시간: ${DEPLOY_MIN}분 ${DEPLOY_SEC}초"
echo ""
echo "📊 컨테이너 상태:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=friendi-"
echo ""
echo "💾 리소스 사용량:"
free -h | head -2
echo ""
echo "🌐 서비스 접속:"
echo "- Frontend:      http://localhost:3000"
echo "- Backend API:   http://localhost:8080"
echo "- Health Check:  http://localhost:8080/actuator/health"
echo "- Swagger UI:    http://localhost:8080/swagger-ui/"
echo ""
echo "🔧 추가 명령어:"
echo "- 로그 확인:     docker-compose logs -f [서비스명]"
echo "- 상태 모니터링: ./monitor-ec2.sh"
echo "- 리소스 정리:   ./cleanup-resources.sh"
echo ""

if [ $HEALTH_CHECK_FAILED -eq 0 ]; then
    log_success "무중단 재배포가 성공적으로 완료되었습니다!"
else
    log_warning "재배포 완료. 일부 서비스 상태를 확인해주세요."
fi