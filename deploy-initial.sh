#!/bin/bash
# EC2 t3.small 초기 배포 스크립트 (전체 정리 후 새로 배포)

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

echo "🚀 EC2 t3.small 초기 배포 (데이터베이스 데이터 보존)"
echo "==============================================="
echo "✅ 데이터베이스 데이터는 보존됩니다"
echo "⚠️  애플리케이션 컨테이너와 이미지는 재생성됩니다"
echo ""

# 확인 메시지
read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "배포가 취소되었습니다."
    exit 0
fi

# 환경 변수 설정
export NODE_OPTIONS="--max-old-space-size=1024"
export JAVA_OPTS="-Xms256m -Xmx1024m -XX:+UseSerialGC -XX:+UseContainerSupport"
export MAVEN_OPTS="-Xmx512m -XX:+UseSerialGC"

log_info "환경 변수 설정 완료 (t3.small 최적화)"

# 1. 데이터베이스 데이터 보존하며 Docker 환경 정리
log_info "데이터베이스 데이터 보존하며 Docker 환경 정리 중..."

# 데이터베이스 컨테이너 상태 확인 및 백업
log_info "데이터베이스 상태 확인..."
POSTGRES_RUNNING=false
REDIS_RUNNING=false

if docker ps --filter "name=postgres" --filter "status=running" | grep -q postgres; then
    POSTGRES_RUNNING=true
    log_info "PostgreSQL이 실행 중입니다. 안전하게 중지..."
    docker stop $(docker ps -q --filter "name=postgres") 2>/dev/null || true
fi

if docker ps --filter "name=redis" --filter "status=running" | grep -q redis; then
    REDIS_RUNNING=true
    log_info "Redis가 실행 중입니다. 안전하게 중지..."
    docker stop $(docker ps -q --filter "name=redis") 2>/dev/null || true
fi

# 모든 컨테이너 중지 및 제거 (데이터베이스 포함)
log_info "모든 컨테이너 중지 및 제거..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# 모든 이미지 제거 (시스템 이미지 제외)
log_info "모든 Docker 이미지 제거..."
docker rmi $(docker images -q) -f 2>/dev/null || true

# 데이터베이스 볼륨 제외하고 볼륨 제거
log_info "데이터베이스 볼륨 제외하고 볼륨 제거..."
# 데이터베이스 관련 볼륨들을 보존
PRESERVE_VOLUMES=("postgres-data" "redis-data" "i_postgres-data" "i_redis-data" "friendi_postgres-data" "friendi_redis-data")
ALL_VOLUMES=$(docker volume ls -q 2>/dev/null || true)
if [ -n "$ALL_VOLUMES" ]; then
    for volume in $ALL_VOLUMES; do
        PRESERVE=false
        for preserve_vol in "${PRESERVE_VOLUMES[@]}"; do
            if [[ "$volume" == *"$preserve_vol"* ]]; then
                PRESERVE=true
                log_info "데이터베이스 볼륨 보존: $volume"
                break
            fi
        done
        if [ "$PRESERVE" = false ]; then
            docker volume rm "$volume" -f 2>/dev/null || true
        fi
    done
fi

# 모든 네트워크 제거
log_info "사용자 정의 네트워크 제거..."
docker network rm $(docker network ls -q --filter type=custom) 2>/dev/null || true

# Docker 시스템 완전 정리
log_info "Docker 시스템 완전 정리..."
docker system prune -af --volumes 2>/dev/null || true
docker builder prune -af 2>/dev/null || true

log_success "Docker 환경 정리 완료 (데이터베이스 데이터 보존)"

# 2. 로컬 빌드 아티팩트 정리
log_info "로컬 빌드 아티팩트 정리 중..."

# Backend 빌드 아티팩트 삭제
rm -rf backend/backend/target 2>/dev/null || true

# Frontend 빌드 아티팩트 삭제  
rm -rf frontend/build 2>/dev/null || true
rm -rf frontend/node_modules 2>/dev/null || true

# Maven 로컬 캐시 정리 (SNAPSHOT만)
if [ -d "$HOME/.m2/repository" ]; then
    find "$HOME/.m2/repository" -name "*SNAPSHOT*" -type d -exec rm -rf {} + 2>/dev/null || true
fi

# npm 캐시 정리
npm cache clean --force 2>/dev/null || true

log_success "로컬 빌드 아티팩트 정리 완료"

# 3. 시스템 리소스 확인
log_info "시스템 리소스 확인..."
echo ""
echo "💾 메모리 상태:"
free -h | head -2
echo ""
echo "💿 디스크 상태:"
df -h / | tail -1
echo ""

AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$AVAILABLE_MEM" -lt 800 ]; then
    log_warning "사용 가능한 메모리가 ${AVAILABLE_MEM}MB로 부족할 수 있습니다"
    log_info "페이지 캐시 정리 중..."
    sync && echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
fi

# 4. 경량화 설정 파일 생성
log_info "경량화 설정 파일 생성 중..."

# Backend 경량화 Dockerfile
cat > backend/backend/Dockerfile << 'EOF'
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN apk add --no-cache curl && rm -rf /var/cache/apk/*
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser
COPY target/backend-*.jar app.jar
RUN chown appuser:appuser app.jar
USER appuser
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=2 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
EXPOSE 8080
ENV JAVA_OPTS="-server -Xms128m -Xmx1024m -XX:+UseSerialGC -XX:+UseContainerSupport -XX:MaxRAMPercentage=50.0 -Djava.awt.headless=true -Dspring.jmx.enabled=false"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
EOF

# Frontend 경량화 Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine AS build
WORKDIR /app
RUN apk add --no-cache --virtual .build-deps python3 make g++
ENV NODE_OPTIONS="--max-old-space-size=1024"
ENV GENERATE_SOURCEMAP=false
ENV CI=true
COPY package*.json ./
RUN npm ci --only=production --no-audit --no-fund --prefer-offline
COPY . .
RUN npm run build && npm cache clean --force && apk del .build-deps && rm -rf node_modules src public *.json *.js *.ts

FROM nginx:alpine
RUN rm -rf /etc/nginx/conf.d/default.conf /usr/share/nginx/html/* && mkdir -p /var/cache/nginx && touch /var/run/nginx.pid
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/build /usr/share/nginx/html
RUN chown -R nginx:nginx /var/cache/nginx /var/run/nginx.pid /usr/share/nginx/html
USER nginx
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=2 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
EOF

# nginx.conf 경량화
cat > frontend/nginx.conf << 'EOF'
user nginx;
worker_processes 1;
worker_rlimit_nofile 1024;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 512;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log off;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    types_hash_max_size 2048;
    client_max_body_size 10M;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 4;
    gzip_proxied any;
    gzip_types text/plain text/css text/javascript application/json application/javascript;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 7d;
            add_header Cache-Control "public, immutable";
            access_log off;
        }

        location /api/ {
            proxy_pass http://backend:8080/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 10s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        location /actuator/ {
            proxy_pass http://backend:8080/actuator/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /swagger-ui/ {
            proxy_pass http://backend:8080/swagger-ui/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location / {
            try_files $uri $uri/ /index.html;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
        }

        error_page 404 /index.html;
    }
}
EOF

# Docker Compose 초기 배포용
cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:

services:
  postgres:
    image: postgres:15-alpine
    container_name: friendi-postgres
    restart: unless-stopped
    networks:
      - app-network
    environment:
      POSTGRES_DB: friendlyi
      POSTGRES_USER: friendlyi_user
      POSTGRES_PASSWORD: friendlyi_password123
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5433:5432"
    command: >
      postgres
      -c shared_buffers=64MB -c effective_cache_size=128MB -c maintenance_work_mem=32MB
      -c work_mem=2MB -c max_connections=50 -c random_page_cost=1.1
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U friendlyi_user -d friendlyi"]
      interval: 30s
      timeout: 5s
      retries: 3

  redis:
    image: redis:7-alpine
    container_name: friendi-redis
    restart: unless-stopped
    networks:
      - app-network
    ports:
      - "6379:6379"
    command: >
      redis-server --maxmemory 128mb --maxmemory-policy allkeys-lru
      --save 900 1 --save 300 10 --save 60 10000 --rdbcompression yes
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 5s
      retries: 3

  backend:
    build:
      context: ./backend/backend
      dockerfile: Dockerfile
    container_name: friendi-backend
    restart: unless-stopped
    networks:
      - app-network
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: docker
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: friendi-frontend
    restart: unless-stopped
    networks:
      - app-network
    ports:
      - "3000:80"
    depends_on:
      backend:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
EOF

log_success "경량화 설정 파일 생성 완료"

# 5. Backend 로컬 빌드
log_info "Backend 로컬 빌드 시작..."

cd backend/backend

# Maven wrapper 권한 확인
if [ ! -x "./mvnw" ]; then
    chmod +x ./mvnw
fi

# JAVA_HOME 설정
if [ -z "$JAVA_HOME" ]; then
    for java_path in \
        "/usr/lib/jvm/java-21-openjdk" \
        "/usr/lib/jvm/java-21-openjdk-amd64" \
        "/usr/lib/jvm/java-21-amazon-corretto" \
        "/opt/java/openjdk-21"
    do
        if [ -d "$java_path" ]; then
            export JAVA_HOME="$java_path"
            break
        fi
    done
fi

log_info "JAVA_HOME: $JAVA_HOME"

# 임시 Maven 저장소
TEMP_M2="/tmp/m2-initial-$$"
mkdir -p "$TEMP_M2"

log_info "Backend Maven 빌드 실행..."
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

# JAR 파일 확인
BACKEND_JAR=$(find target -name "backend-*.jar" -type f | head -1)
if [ ! -f "$BACKEND_JAR" ]; then
    log_error "Backend JAR 파일 생성 실패"
    rm -rf "$TEMP_M2"
    exit 1
fi

JAR_SIZE=$(du -h "$BACKEND_JAR" | cut -f1)
log_success "Backend JAR 생성: $(basename "$BACKEND_JAR") ($JAR_SIZE)"

rm -rf "$TEMP_M2"
cd ../..

# 6. Docker 이미지 순차 빌드 (메모리 절약)
log_info "Docker 이미지 순차 빌드 시작..."

# Backend 먼저 빌드
log_info "Backend 이미지 빌드 중..."
docker-compose build --no-cache backend
docker image prune -f 2>/dev/null || true

# Frontend 빌드
log_info "Frontend 이미지 빌드 중..."
docker-compose build --no-cache frontend
docker image prune -f 2>/dev/null || true

log_success "Docker 이미지 빌드 완료"

# 7. 서비스 순차 시작
log_info "서비스 순차 시작..."

# 데이터베이스 먼저 (기존 데이터 유지)
log_info "데이터베이스 서비스 시작 (기존 데이터 유지)..."
docker-compose up -d postgres redis
sleep 15

# 데이터베이스 데이터 복구 확인
if [ "$POSTGRES_RUNNING" = true ]; then
    log_info "기존 PostgreSQL 데이터가 유지되었는지 확인..."
fi

if [ "$REDIS_RUNNING" = true ]; then
    log_info "기존 Redis 데이터가 유지되었는지 확인..."
fi

# PostgreSQL 대기
log_info "PostgreSQL 연결 대기..."
for i in {1..30}; do
    if docker exec friendi-postgres pg_isready -U friendlyi_user -d friendlyi >/dev/null 2>&1; then
        log_success "PostgreSQL 준비 완료"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "PostgreSQL 연결 타임아웃"
        exit 1
    fi
    sleep 2
done

# Redis 대기
log_info "Redis 연결 대기..."
for i in {1..15}; do
    if docker exec friendi-redis redis-cli ping 2>/dev/null | grep -q PONG; then
        log_success "Redis 준비 완료"
        break
    fi
    if [ $i -eq 15 ]; then
        log_error "Redis 연결 타임아웃"
        exit 1
    fi
    sleep 2
done

# Backend 시작
log_info "Backend 서비스 시작..."
docker-compose up -d backend

# Backend 헬스체크
log_info "Backend 헬스체크 대기..."
for i in {1..60}; do
    if curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        log_success "Backend 준비 완료"
        break
    fi
    if [ $i -eq 60 ]; then
        log_error "Backend 헬스체크 타임아웃"
        docker logs friendi-backend --tail 20
        exit 1
    fi
    sleep 2
done

# Frontend 시작
log_info "Frontend 서비스 시작..."
docker-compose up -d frontend

# Frontend 헬스체크
log_info "Frontend 헬스체크 대기..."
for i in {1..30}; do
    if curl -s -f http://localhost:3000 >/dev/null 2>&1; then
        log_success "Frontend 준비 완료"
        break
    fi
    if [ $i -eq 30 ]; then
        log_warning "Frontend 헬스체크 타임아웃 (계속 진행)"
        break
    fi
    sleep 2
done

# 8. 최종 정리 및 상태 확인
log_info "배포 후 정리..."
docker image prune -f 2>/dev/null || true

END_TIME=$(date +%s)
DEPLOY_TIME=$((END_TIME - START_TIME))
DEPLOY_MIN=$((DEPLOY_TIME / 60))
DEPLOY_SEC=$((DEPLOY_TIME % 60))

echo ""
echo "🎉 초기 배포 완료!"
echo "=================="
echo ""
echo "⏱️  총 배포 시간: ${DEPLOY_MIN}분 ${DEPLOY_SEC}초"
echo ""
echo "📊 컨테이너 상태:"
docker-compose ps
echo ""
echo "💾 리소스 사용량:"
free -h | head -2
echo ""
echo "💽 데이터베이스 볼륨 상태:"
echo "PostgreSQL 볼륨:"
docker volume ls | grep postgres || echo "  볼륨 없음"
echo "Redis 볼륨:"
docker volume ls | grep redis || echo "  볼륨 없음"
echo ""
echo "🌐 접속 정보:"
echo "- Frontend:      http://localhost:3000"
echo "- Backend API:   http://localhost:8080"
echo "- Health Check:  http://localhost:8080/actuator/health"
echo "- Swagger UI:    http://localhost:8080/swagger-ui/"
echo ""
echo "🔧 관리 명령어:"
echo "- 무중단 재배포: ./redeploy-zero-downtime.sh"
echo "- 상태 모니터링: ./monitor-ec2.sh"
echo "- 리소스 정리:   ./cleanup-resources.sh"
echo ""
log_success "초기 배포가 성공적으로 완료되었습니다! (데이터베이스 데이터 보존됨)"