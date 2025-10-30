#!/bin/bash
# Actuator 의존성 추가 후 빠른 재배포

echo "🔧 Actuator 의존성 추가 후 Backend 재빌드 시작..."

# 1. 기존 Backend 정리
echo "1. 기존 Backend 컨테이너 정리..."
docker-compose stop backend 2>/dev/null || true
docker-compose rm -f backend 2>/dev/null || true

# 2. Backend 이미지 삭제 (새 의존성으로 인한 재빌드 필요)
echo "2. 기존 Backend 이미지 삭제..."
docker rmi friendlyi-backend:latest 2>/dev/null || true

# 3. 데이터베이스 서비스 상태 확인
echo "3. 데이터베이스 서비스 상태 확인..."
docker-compose ps postgres redis

if ! docker-compose ps postgres | grep -q "Up" || ! docker-compose ps redis | grep -q "Up"; then
    echo "   데이터베이스 서비스 시작 중..."
    docker-compose up -d postgres redis
    echo "   데이터베이스 시작 대기... (30초)"
    sleep 30
else
    echo "   ✅ 데이터베이스 서비스 실행 중"
fi

# 4. Backend 새로 빌드 (Actuator 의존성 포함)
echo "4. Backend 새로 빌드 중 (Actuator 의존성 포함)..."
docker-compose build --no-cache backend

if [ $? -ne 0 ]; then
    echo "❌ Docker 빌드 실패. 로컬 Maven 빌드 시도..."
    
    # 로컬에서 JAR 빌드
    cd backend/backend
    chmod +x mvnw
    ./mvnw clean package -DskipTests -Dmaven.test.skip=true --no-transfer-progress
    
    if [ $? -eq 0 ]; then
        echo "✅ 로컬 Maven 빌드 성공"
        
        # 간단한 Dockerfile로 이미지 생성
        cat > Dockerfile.simple << 'EOF'
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN apk add --no-cache curl
COPY target/backend-*.jar app.jar
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
ENV SPRING_PROFILES_ACTIVE=docker
ENV JAVA_OPTS="-Xms256m -Xmx1g -XX:+UseG1GC"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
EOF
        
        docker build -f Dockerfile.simple -t friendlyi-backend:latest .
        cd ../../
    else
        echo "❌ 로컬 Maven 빌드도 실패"
        exit 1
    fi
fi

# 5. Backend 컨테이너 시작
echo "5. Backend 컨테이너 시작..."
docker-compose up -d backend

# 6. 시작 대기 및 로그 모니터링
echo "6. Backend 시작 대기... (60초)"
echo "   실시간 로그 확인:"

# 백그라운드에서 로그 표시
docker-compose logs -f backend &
LOG_PID=$!

sleep 60

# 로그 프로세스 종료
kill $LOG_PID 2>/dev/null || true

# 7. 서비스 상태 확인
echo "7. 서비스 상태 확인:"
docker-compose ps

# 8. Actuator 헬스체크
echo "8. Actuator 헬스체크..."
for i in {1..10}; do
    echo "   헬스체크 시도 $i/10..."
    
    # HTTP 상태 코드 확인
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Actuator 헬스체크 성공!"
        
        # 헬스체크 결과 출력
        echo "📋 헬스체크 결과:"
        curl -s http://localhost:8080/actuator/health | jq . 2>/dev/null || curl -s http://localhost:8080/actuator/health
        
        # 성공 정보 출력
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
        echo
        echo "🎉 Backend Actuator 재배포 성공!"
        echo "📋 접속 정보:"
        echo "   🔧 Backend API: http://$PUBLIC_IP:8080"
        echo "   💾 헬스체크: http://$PUBLIC_IP:8080/actuator/health"
        echo "   📊 정보 확인: http://$PUBLIC_IP:8080/actuator/info"
        echo "   📈 메트릭스: http://$PUBLIC_IP:8080/actuator/metrics"
        echo "   📚 API 문서: http://$PUBLIC_IP:8080/swagger-ui/index.html"
        echo
        echo "🛠️ 관리 명령어:"
        echo "   Backend 로그: docker-compose logs -f backend"
        echo "   전체 상태: docker-compose ps"
        echo "   헬스체크: curl http://localhost:8080/actuator/health"
        
        exit 0
        
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "   ❌ Actuator 엔드포인트를 찾을 수 없습니다 (404)"
    elif [ "$HTTP_CODE" = "500" ]; then
        echo "   ❌ 서버 내부 오류 (500)"
    else
        echo "   ⏳ 서비스 시작 중... (HTTP: $HTTP_CODE)"
    fi
    
    sleep 10
done

echo "❌ Actuator 헬스체크 최종 실패"
echo
echo "🔍 문제 진단:"
echo "최근 Backend 로그:"
docker-compose logs --tail=30 backend

echo
echo "컨테이너 상태:"
docker-compose ps backend

echo
echo "네트워크 연결 테스트:"
echo "8080 포트 리스닝 확인:"
docker-compose exec backend netstat -tlnp 2>/dev/null | grep 8080 || echo "8080 포트 리스닝 없음"

echo
echo "💡 수동 확인 방법:"
echo "1. docker-compose logs -f backend"
echo "2. docker-compose exec backend curl http://localhost:8080/actuator/health"
echo "3. curl http://localhost:8080/actuator/health"

exit 1