#!/bin/bash
# Frontend + Backend CORS 수정 후 재배포 스크립트 (Linux/macOS)

echo "🔧 Backend CORS 설정 수정 후 재배포 중..."
echo "============================================="

# 1. 현재 Backend 컨테이너 상태 확인
echo ""
echo "📋 현재 Backend 컨테이너 상태:"
docker ps --filter "name=backend" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Backend 컨테이너 중지
echo ""
echo "🛑 Backend 컨테이너 중지 중..."
docker-compose stop backend 2>/dev/null
echo "✅ Backend 컨테이너 중지 완료"

# 3. Backend 이미지 재빌드
echo ""
echo "🔨 Backend 이미지 재빌드 중..."
if docker-compose build --no-cache backend; then
    echo "✅ Backend 이미지 빌드 완료"
else
    echo "⚠️ 빌드 중 일부 경고가 있었지만 계속 진행합니다"
fi

# 4. 데이터베이스가 실행 중인지 확인
echo ""
echo "💾 데이터베이스 상태 확인 중..."
POSTGRES_STATUS=$(docker ps --filter "name=postgres" --format "{{.Status}}")
REDIS_STATUS=$(docker ps --filter "name=redis" --format "{{.Status}}")

if echo "$POSTGRES_STATUS" | grep -q "Up"; then
    echo "✅ PostgreSQL 실행 중: $POSTGRES_STATUS"
else
    echo "⚠️ PostgreSQL 시작 중..."
    docker-compose up -d postgres 2>/dev/null
    sleep 10
fi

if echo "$REDIS_STATUS" | grep -q "Up"; then
    echo "✅ Redis 실행 중: $REDIS_STATUS"
else
    echo "⚠️ Redis 시작 중..."
    docker-compose up -d redis 2>/dev/null
    sleep 5
fi

# 5. Backend 컨테이너 시작
echo ""
echo "🚀 Backend 컨테이너 시작 중..."
docker-compose up -d backend 2>/dev/null
echo "✅ Backend 컨테이너 시작 완료"

# 6. Backend 헬스체크 대기
echo ""
echo "⏳ Backend 헬스체크 대기 중..."
TIMEOUT=120
COUNTER=0
HEALTH_CHECK_PASSED=false

while [ $COUNTER -lt $TIMEOUT ] && [ "$HEALTH_CHECK_PASSED" = false ]; do
    if curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        HEALTH_CHECK_PASSED=true
        echo "✅ Backend 헬스체크 성공!"
        break
    fi
    
    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 10)) -eq 0 ]; then
        echo "Backend 대기 중... ($COUNTER/$TIMEOUT)"
    fi
    sleep 2
done

if [ "$HEALTH_CHECK_PASSED" = false ]; then
    echo "⚠️ Backend 헬스체크 타임아웃 - 로그 확인:"
    docker-compose logs --tail=20 backend
fi

# 7. CORS 테스트
echo ""
echo "🌐 CORS 설정 테스트..."
CORS_RESPONSE=$(curl -s -X OPTIONS \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Content-Type" \
    -I http://localhost:8080/api/ 2>/dev/null)

if echo "$CORS_RESPONSE" | grep -q "Access-Control-Allow-Origin"; then
    echo "✅ CORS 설정이 올바르게 적용되었습니다"
else
    echo "⚠️ CORS 헤더 확인 필요"
    echo "CORS 응답 헤더:"
    echo "$CORS_RESPONSE" | grep -i "access-control"
fi

# 8. 최종 상태 확인
echo ""
echo "🎉 Backend 재배포 완료!"
echo "========================="

echo ""
echo "📋 서비스 상태:"
docker-compose ps

echo ""
echo "🌐 접속 정보:"
echo "- Backend API: http://localhost:8080"
echo "- Backend Health: http://localhost:8080/actuator/health"
echo "- Swagger UI: http://localhost:8080/swagger-ui/"
echo "- Frontend: http://localhost:3000"

echo ""
echo "🔧 CORS 수정 사항:"
echo "- 모든 도메인 패턴 허용 (allowed-origin-patterns=*)"
echo "- 추가 HTTP 메서드 지원 (HEAD 포함)"
echo "- 확장된 헤더 노출 설정"

echo ""
echo "📝 테스트 명령어:"
echo "- CORS 테스트: curl -X OPTIONS -H \"Origin: http://localhost:3000\" http://localhost:8080/api/ -I"
echo "- API 테스트: curl http://localhost:8080/actuator/health"
echo "- 로그 확인: docker-compose logs -f backend"