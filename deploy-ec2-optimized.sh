#!/bin/bash
# EC2 t3.small 최적화 풀스택 경량화 배포 스크립트
# 메모리: 2GB, CPU: 2 vCPU 최적화

set -e  # 오류 시 즉시 종료

echo "🚀 EC2 t3.small 최적화 풀스택 배포"
echo "메모리: 2GB | CPU: 2 vCPU | 디스크 절약형"
echo "======================================"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 시작 시간 기록
START_TIME=$(date +%s)

# 0. 환경 변수 설정
export NODE_OPTIONS="--max-old-space-size=1024"  # Node.js 메모리 제한
export JAVA_OPTS="-Xms256m -Xmx1024m -XX:+UseSerialGC -XX:+UseContainerSupport"
export MAVEN_OPTS="-Xmx512m -XX:+UseSerialGC"

log_info "환경 변수 설정 완료"
log_info "Node.js 메모리 제한: 1GB"
log_info "Java 메모리 제한: 1GB"
log_info "Maven 메모리 제한: 512MB"

# 1. 시스템 리소스 확인
log_info "시스템 리소스 확인 중..."
echo ""
echo "📊 시스템 정보:"
echo "메모리 사용량:"
free -h | head -2
echo ""
echo "디스크 사용량:"
df -h | head -1
df -h / | tail -1
echo ""
echo "현재 디렉토리 크기:"
du -sh . 2>/dev/null || echo "크기 계산 불가"

# 메모리 부족 경고
AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
if [ "$AVAILABLE_MEM" -lt 1000 ]; then
    log_warning "사용 가능한 메모리가 ${AVAILABLE_MEM}MB로 부족합니다"
    log_warning "다른 프로세스를 종료하거나 swap을 활성화하세요"
fi

# 2. 기존 환경 정리
log_info "기존 환경 정리 중..."

# Docker 컨테이너 정리
docker-compose down --remove-orphans 2>/dev/null || true

# Docker 시스템 정리 (용량 확보)
log_info "Docker 시스템 정리로 디스크 공간 확보..."
docker system prune -f 2>/dev/null || true
docker builder prune -f 2>/dev/null || true

# 기존 빌드 아티팩트 정리
log_info "기존 빌드 아티팩트 정리..."
rm -rf backend/backend/target 2>/dev/null || true
rm -rf frontend/build 2>/dev/null || true
rm -rf frontend/node_modules/.cache 2>/dev/null || true

log_success "환경 정리 완료"

# 3. Backend 경량화 빌드
log_info "Backend 경량화 빌드 시작..."
echo "🔨 Backend (Java 21 + Spring Boot)"

cd backend/backend

# Maven wrapper 권한 확인
if [ ! -x "./mvnw" ]; then
    chmod +x ./mvnw
    log_success "mvnw 실행 권한 부여"
fi

# JAVA_HOME 자동 설정
if [ -z "$JAVA_HOME" ]; then
    for java_path in \
        "/usr/lib/jvm/java-21-openjdk" \
        "/usr/lib/jvm/java-21-openjdk-amd64" \
        "/usr/lib/jvm/java-21-amazon-corretto" \
        "/opt/java/openjdk-21" \
        "/usr/java/jdk-21"
    do
        if [ -d "$java_path" ]; then
            export JAVA_HOME="$java_path"
            break
        fi
    done
fi

log_info "JAVA_HOME: $JAVA_HOME"

# 임시 Maven 저장소 생성 (메모리 절약)
TEMP_M2="/tmp/m2-repo-$$"
mkdir -p "$TEMP_M2"

log_info "임시 Maven 저장소: $TEMP_M2"

# 경량화 Maven 빌드
log_info "Maven 빌드 실행 (경량화 모드)..."
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
    log_error "Backend JAR 파일을 찾을 수 없습니다"
    rm -rf "$TEMP_M2"
    exit 1
fi

JAR_SIZE=$(du -h "$BACKEND_JAR" | cut -f1)
log_success "Backend JAR 생성 완료: $(basename "$BACKEND_JAR") ($JAR_SIZE)"

# Maven 임시 저장소 정리
rm -rf "$TEMP_M2"
log_success "임시 Maven 저장소 정리 완료"

cd ../..

# 4. Frontend 경량화 빌드 준비
log_info "Frontend 경량화 빌드 시작..."
echo "🌐 Frontend (React + TypeScript)"

cd frontend

# Node.js 버전 확인
NODE_VERSION=$(node --version 2>/dev/null || echo "없음")
log_info "Node.js 버전: $NODE_VERSION"

# package.json이 있는지 확인
if [ ! -f "package.json" ]; then
    log_error "package.json을 찾을 수 없습니다"
    exit 1
fi

cd ..

# 5. 경량화 Dockerfile 생성
log_info "경량화 Dockerfile 생성 중..."

# Backend 경량화 Dockerfile
cat > backend/backend/Dockerfile.ec2-optimized << 'EOF'
# EC2 t3.small 최적화 Backend Dockerfile
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# curl 설치 (헬스체크용, 최소한으로)
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# 비루트 사용자 생성
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# JAR 파일 복사
COPY target/backend-*.jar app.jar

# 권한 설정
RUN chown appuser:appuser app.jar

USER appuser

# 헬스체크 (30초 간격, 메모리 절약)
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=2 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

# EC2 t3.small 최적화 JVM 설정
ENV JAVA_OPTS="-server \
    -Xms128m \
    -Xmx1024m \
    -XX:+UseSerialGC \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=50.0 \
    -Djava.awt.headless=true \
    -Djava.security.egd=file:/dev/./urandom \
    -Dspring.jmx.enabled=false"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
EOF

# Frontend 경량화 Dockerfile
cat > frontend/Dockerfile.ec2-optimized << 'EOF'
# EC2 t3.small 최적화 Frontend Dockerfile
# Build stage - 메모리 효율적 빌드
FROM node:18-alpine AS build

WORKDIR /app

# Build dependencies 설치 (최소한)
RUN apk add --no-cache --virtual .build-deps \
    python3 make g++

# Node.js 메모리 제한
ENV NODE_OPTIONS="--max-old-space-size=1024"
ENV GENERATE_SOURCEMAP=false
ENV CI=true

# Package files 복사 및 의존성 설치
COPY package*.json ./
RUN npm ci --only=production --no-audit --no-fund --prefer-offline

# 소스 복사 및 빌드
COPY . .
RUN npm run build && \
    npm cache clean --force && \
    apk del .build-deps && \
    rm -rf node_modules src public *.json *.js *.ts

# Production stage - 초경량 nginx
FROM nginx:alpine

# 불필요한 nginx 모듈 제거를 위한 설정
RUN rm -rf /etc/nginx/conf.d/default.conf && \
    rm -rf /usr/share/nginx/html/* && \
    mkdir -p /var/cache/nginx && \
    touch /var/run/nginx.pid

# 커스텀 nginx 설정 복사
COPY nginx.conf /etc/nginx/nginx.conf

# 빌드된 앱 복사
COPY --from=build /app/build /usr/share/nginx/html

# 비루트 사용자로 실행
RUN chown -R nginx:nginx /var/cache/nginx /var/run/nginx.pid /usr/share/nginx/html

USER nginx

EXPOSE 80

# 헬스체크 (경량화)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=2 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF

# nginx.conf 최적화 (메모리 절약)
cat > frontend/nginx.conf.ec2-optimized << 'EOF'
# EC2 t3.small 최적화 nginx 설정
user nginx;
worker_processes 1;  # t3.small의 2 vCPU에 맞게 조정
worker_rlimit_nofile 1024;

error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 512;  # 메모리 절약
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 로깅 최소화 (디스크 I/O 절약)
    access_log off;
    error_log /var/log/nginx/error.log error;

    # 성능 최적화
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    types_hash_max_size 2048;
    client_max_body_size 10M;

    # Gzip 압축 (CPU 절약형)
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 4;  # CPU 절약
    gzip_proxied any;
    gzip_types text/plain text/css text/javascript application/json application/javascript;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        # 보안 헤더 (최소한)
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;

        # 정적 파일 캐싱 (메모리 효율적)
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 7d;
            add_header Cache-Control "public, immutable";
            access_log off;
        }

        # API 프록시 (Backend로 전달)
        location /api/ {
            proxy_pass http://backend:8080/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # 타임아웃 설정 (빠른 응답)
            proxy_connect_timeout 10s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        # Actuator 프록시
        location /actuator/ {
            proxy_pass http://backend:8080/actuator/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # Swagger UI 프록시
        location /swagger-ui/ {
            proxy_pass http://backend:8080/swagger-ui/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # SPA 라우팅
        location / {
            try_files $uri $uri/ /index.html;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
        }

        # 에러 페이지
        error_page 404 /index.html;
    }
}
EOF

# Docker Compose 경량화 설정
log_info "Docker Compose 경량화 설정 생성..."

cat > docker-compose.ec2-optimized.yml << 'EOF'
version: '3.8'

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:

services:
  # PostgreSQL - 메모리 최적화
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
      # PostgreSQL 메모리 최적화
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5433:5432"
    command: >
      postgres
      -c shared_buffers=64MB
      -c effective_cache_size=128MB
      -c maintenance_work_mem=32MB
      -c checkpoint_completion_target=0.7
      -c wal_buffers=2MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200
      -c work_mem=2MB
      -c min_wal_size=80MB
      -c max_wal_size=1GB
      -c max_connections=50
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U friendlyi_user -d friendlyi"]
      interval: 30s
      timeout: 5s
      retries: 3

  # Redis - 메모리 최적화
  redis:
    image: redis:7-alpine
    container_name: friendi-redis
    restart: unless-stopped
    networks:
      - app-network
    ports:
      - "6379:6379"
    command: >
      redis-server
      --maxmemory 128mb
      --maxmemory-policy allkeys-lru
      --save 900 1
      --save 300 10
      --save 60 10000
      --stop-writes-on-bgsave-error no
      --rdbcompression yes
      --rdbchecksum yes
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 5s
      retries: 3

  # Backend - t3.small 최적화
  backend:
    build:
      context: ./backend/backend
      dockerfile: Dockerfile.ec2-optimized
    container_name: friendi-backend
    restart: unless-stopped
    networks:
      - app-network
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: docker
      JAVA_OPTS: >
        -server
        -Xms128m
        -Xmx1024m
        -XX:+UseSerialGC
        -XX:+UseContainerSupport
        -XX:MaxRAMPercentage=50.0
        -Djava.awt.headless=true
        -Dspring.jmx.enabled=false
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

  # Frontend - 경량화
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.ec2-optimized
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

# 6. Docker 이미지 빌드 (순차적으로 메모리 절약)
log_info "Docker 이미지 빌드 시작 (순차 빌드로 메모리 절약)..."

# Dockerfile 교체
cp backend/backend/Dockerfile.ec2-optimized backend/backend/Dockerfile
cp frontend/Dockerfile.ec2-optimized frontend/Dockerfile
cp frontend/nginx.conf.ec2-optimized frontend/nginx.conf

# Backend 빌드
log_info "Backend 이미지 빌드 중..."
docker-compose -f docker-compose.ec2-optimized.yml build --no-cache backend

# 중간 정리 (메모리 확보)
docker image prune -f 2>/dev/null || true

# Frontend 빌드
log_info "Frontend 이미지 빌드 중..."
docker-compose -f docker-compose.ec2-optimized.yml build --no-cache frontend

log_success "Docker 이미지 빌드 완료"

# 7. 서비스 순차 시작 (메모리 부담 분산)
log_info "서비스 순차 시작 중..."

# 데이터베이스 먼저 시작
log_info "데이터베이스 서비스 시작..."
docker-compose -f docker-compose.ec2-optimized.yml up -d postgres redis

# 데이터베이스 준비 대기
log_info "데이터베이스 준비 대기 중..."
sleep 15

# PostgreSQL 헬스체크
log_info "PostgreSQL 연결 확인..."
for i in {1..30}; do
    if docker exec friendi-postgres pg_isready -U friendlyi_user -d friendlyi >/dev/null 2>&1; then
        log_success "PostgreSQL 연결 확인 완료"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "PostgreSQL 연결 타임아웃"
        exit 1
    fi
    sleep 2
done

# Redis 헬스체크
log_info "Redis 연결 확인..."
for i in {1..15}; do
    if docker exec friendi-redis redis-cli ping 2>/dev/null | grep -q PONG; then
        log_success "Redis 연결 확인 완료"
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
docker-compose -f docker-compose.ec2-optimized.yml up -d backend

# Backend 헬스체크
log_info "Backend 헬스체크 대기..."
for i in {1..60}; do
    if curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        log_success "Backend 서비스 준비 완료"
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
docker-compose -f docker-compose.ec2-optimized.yml up -d frontend

# Frontend 헬스체크
log_info "Frontend 헬스체크 대기..."
for i in {1..30}; do
    if curl -s -f http://localhost:3000 >/dev/null 2>&1; then
        log_success "Frontend 서비스 준비 완료"
        break
    fi
    if [ $i -eq 30 ]; then
        log_warning "Frontend 헬스체크 타임아웃 (계속 진행)"
        break
    fi
    sleep 2
done

# 8. 최종 정리 및 확인
log_info "배포 후 정리 작업..."

# 사용하지 않는 이미지 정리
docker image prune -f 2>/dev/null || true

# 최종 상태 확인
log_info "최종 배포 상태 확인..."

echo ""
echo "📊 컨테이너 상태:"
docker-compose -f docker-compose.ec2-optimized.yml ps

echo ""
echo "💾 메모리 사용량:"
free -h

echo ""
echo "🐳 Docker 이미지 크기:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "(friendi|postgres|redis)" || true

# 종료 시간 계산
END_TIME=$(date +%s)
DEPLOY_TIME=$((END_TIME - START_TIME))
DEPLOY_MIN=$((DEPLOY_TIME / 60))
DEPLOY_SEC=$((DEPLOY_TIME % 60))

echo ""
echo "🎉 EC2 t3.small 최적화 풀스택 배포 완료!"
echo "========================================="
echo ""
echo "⏱️  총 배포 시간: ${DEPLOY_MIN}분 ${DEPLOY_SEC}초"
echo ""
echo "🌐 접속 정보:"
echo "- Frontend:      http://localhost:3000"
echo "- Backend API:   http://localhost:8080"
echo "- Health Check:  http://localhost:8080/actuator/health"
echo "- Swagger UI:    http://localhost:8080/swagger-ui/"
echo "- PostgreSQL:    localhost:5433"
echo "- Redis:         localhost:6379"
echo ""
echo "📋 t3.small 최적화 적용 사항:"
echo "- JVM 메모리: 최대 1GB (전체의 50%)"
echo "- PostgreSQL: 공유버퍼 64MB, 연결수 50개 제한"
echo "- Redis: 최대 메모리 128MB"
echo "- Nginx: 워커 1개, 연결수 512개"
echo "- Node.js: 빌드 시 메모리 1GB 제한"
echo ""
echo "🔧 유용한 명령어:"
echo "- 전체 로그 확인: docker-compose -f docker-compose.ec2-optimized.yml logs -f"
echo "- 개별 서비스 로그: docker logs friendi-[service-name]"
echo "- 서비스 재시작: docker-compose -f docker-compose.ec2-optimized.yml restart [service]"
echo "- 전체 중지: docker-compose -f docker-compose.ec2-optimized.yml down"
echo "- 리소스 모니터링: docker stats"
echo ""
echo "✅ 풀스택 배포가 성공적으로 완료되었습니다!"