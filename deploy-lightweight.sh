#!/bin/bash
# 디스크 부족 상황용 경량 Backend 배포

echo "🛠️ 경량 Backend 배포 (디스크 절약 모드)"

# 1. 디스크 사용량 확인
echo "현재 디스크 사용량:"
df -h / | grep -v Filesystem

ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$ROOT_USAGE" -gt 95 ]; then
    echo "❌ 디스크 사용량이 95%를 초과했습니다. 먼저 정리 스크립트를 실행하세요."
    echo "실행: ./cleanup-disk-emergency.sh"
    exit 1
fi

# 2. 기존 Backend 정리
echo "기존 Backend 컨테이너 정리..."
docker-compose stop backend 2>/dev/null || true
docker-compose rm -f backend 2>/dev/null || true

# 3. 기존 이미지 정리 (공간 절약)
echo "기존 Backend 이미지 정리..."
docker rmi friendlyi-backend:latest 2>/dev/null || true
docker rmi $(docker images --filter "dangling=true" -q) 2>/dev/null || true

# 4. 경량 Dockerfile 사용
echo "경량 Dockerfile로 빌드 중..."
cd backend/backend
docker build -f Dockerfile.lightweight -t friendlyi-backend:latest . || {
    echo "❌ 경량 빌드 실패. 표준 방법으로 재시도..."
    
    # 표준 방법으로 재시도 (하지만 캐시 없이)
    docker build --no-cache --progress=plain -t friendlyi-backend:latest . || {
        echo "❌ 빌드 실패. Maven 로컬 빌드 시도..."
        
        # 로컬에서 JAR 빌드 후 간단한 Dockerfile 사용
        ./mvnw clean package -DskipTests -Dmaven.test.skip=true --no-transfer-progress || exit 1
        
        # 초경량 Dockerfile 생성
        cat > Dockerfile.emergency << 'EOF'
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN apk add --no-cache curl
COPY target/backend-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-Xms128m", "-Xmx768m", "-jar", "app.jar", "--spring.profiles.active=docker"]
EOF
        
        docker build -f Dockerfile.emergency -t friendlyi-backend:latest .
    }
}

cd ../../

# 5. 데이터베이스 서비스 확인
echo "데이터베이스 서비스 확인..."
if ! docker-compose ps postgres | grep -q "Up"; then
    echo "PostgreSQL 시작 중..."
    docker-compose up -d postgres redis
    sleep 30
fi

# 6. Backend 시작
echo "Backend 컨테이너 시작..."
docker-compose up -d backend

# 7. 시작 대기
echo "Backend 시작 대기 중... (60초)"
sleep 60

# 8. 상태 확인
echo "서비스 상태:"
docker-compose ps

# 9. 헬스체크
echo "헬스체크 시도..."
for i in {1..5}; do
    if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
        echo "✅ Backend 배포 성공!"
        echo "🔗 접속: http://$(curl -s ifconfig.me 2>/dev/null || echo localhost):8080"
        
        # 디스크 사용량 재확인
        echo "배포 후 디스크 사용량:"
        df -h / | grep -v Filesystem
        
        exit 0
    else
        echo "헬스체크 재시도... ($i/5)"
        sleep 15
    fi
done

echo "❌ Backend 헬스체크 실패"
echo "로그 확인:"
docker-compose logs --tail=20 backend

exit 1