#!/bin/bash
# Frontend 서비스 테스트 스크립트 (Linux/macOS)

# 기본 포트 설정
PORT=${1:-3000}

echo "🧪 Frontend 서비스 종합 테스트"
echo "포트: $PORT"
echo "============================="

# 테스트 함수 정의
test_endpoint() {
    local url="$1"
    local description="$2"
    local expected_status="${3:-200}"
    
    echo ""
    echo "📡 $description"
    echo "URL: $url"
    
    if response=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "$url" 2>/dev/null); then
        if [ "$response" -eq "$expected_status" ]; then
            echo "✅ 성공 (Status: $response)"
            return 0
        else
            echo "⚠️ 예상하지 못한 상태 코드: $response"
            return 1
        fi
    else
        echo "❌ 실패: 연결할 수 없습니다"
        return 1
    fi
}

test_api_endpoint() {
    local url="$1"
    local description="$2"
    
    echo ""
    echo "🔗 $description"
    echo "URL: $url"
    
    # OPTIONS 요청으로 CORS 헤더 확인
    if cors_response=$(curl -s -X OPTIONS \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Content-Type" \
        -I "$url" 2>/dev/null); then
        
        echo "✅ API 엔드포인트 접근 가능"
        
        # CORS 헤더 확인
        if echo "$cors_response" | grep -qi "Access-Control"; then
            echo "✅ CORS 헤더 설정됨"
        fi
        return 0
    else
        # GET 요청으로 재시도
        if curl -s -f "$url" >/dev/null 2>&1; then
            echo "✅ API 엔드포인트 접근 가능 (GET)"
            return 0
        else
            echo "❌ 실패: 연결할 수 없습니다"
            return 1
        fi
    fi
}

# 1. 컨테이너 상태 확인
echo ""
echo "🐳 Docker 컨테이너 상태"
CONTAINERS=$(docker ps --filter "name=frontend" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
if [ -n "$CONTAINERS" ] && [ "$(echo "$CONTAINERS" | wc -l)" -gt 1 ]; then
    echo "$CONTAINERS"
    echo "✅ Frontend 컨테이너 실행 중"
else
    echo "❌ Frontend 컨테이너를 찾을 수 없습니다"
    echo "docker-compose up -d frontend 를 먼저 실행하세요"
    exit 1
fi

# 2. 기본 웹 서비스 테스트
RESULTS=()
test_endpoint "http://localhost:$PORT/" "Frontend 메인 페이지" && RESULTS+=(1) || RESULTS+=(0)

# 3. 정적 파일 테스트
STATIC_FILES=("/favicon.ico" "/manifest.json")

for file in "${STATIC_FILES[@]}"; do
    test_endpoint "http://localhost:$PORT$file" "정적 파일: $file" 200 && RESULTS+=(1) || RESULTS+=(0)
done

# 4. API 프록시 테스트
echo ""
echo "🔌 API 프록시 테스트"
test_api_endpoint "http://localhost:$PORT/api/" "API 기본 엔드포인트" && RESULTS+=(1) || RESULTS+=(0)

# 5. 백엔드 서비스 프록시 테스트
BACKEND_ENDPOINTS=("/actuator/health" "/swagger-ui/" "/v3/api-docs")

for endpoint in "${BACKEND_ENDPOINTS[@]}"; do
    test_endpoint "http://localhost:$PORT$endpoint" "Backend 프록시: $endpoint" && RESULTS+=(1) || RESULTS+=(0)
done

# 6. Nginx 설정 검증
echo ""
echo "⚙️ Nginx 설정 검증"
if nginx_test=$(docker-compose exec -T frontend nginx -t 2>&1); then
    if echo "$nginx_test" | grep -q "successful"; then
        echo "✅ Nginx 설정 문법 검증 성공"
        RESULTS+=(1)
    else
        echo "❌ Nginx 설정 오류:"
        echo "$nginx_test"
        RESULTS+=(0)
    fi
else
    echo "❌ Nginx 설정 검증 실패"
    RESULTS+=(0)
fi

# 7. 로그 상태 확인
echo ""
echo "📋 최근 로그 확인"
if logs=$(docker-compose logs --tail=10 frontend 2>&1); then
    error_logs=$(echo "$logs" | grep -i "error\|emerg\|alert\|crit" || true)
    
    if [ -n "$error_logs" ]; then
        echo "⚠️ 로그에서 오류 발견:"
        echo "$error_logs"
        RESULTS+=(0)
    else
        echo "✅ 로그에 심각한 오류 없음"
        RESULTS+=(1)
    fi
else
    echo "⚠️ 로그 확인 중 오류 발생"
fi

# 8. 결과 요약
echo ""
echo "📊 테스트 결과 요약"
echo "===================="

SUCCESS_COUNT=0
TOTAL_COUNT=${#RESULTS[@]}

for result in "${RESULTS[@]}"; do
    if [ "$result" -eq 1 ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
done

if [ $TOTAL_COUNT -gt 0 ]; then
    SUCCESS_RATE=$((SUCCESS_COUNT * 100 / TOTAL_COUNT))
else
    SUCCESS_RATE=0
fi

echo "성공: $SUCCESS_COUNT / $TOTAL_COUNT ($SUCCESS_RATE%)"

if [ $SUCCESS_RATE -ge 80 ]; then
    echo "🎉 Frontend 서비스가 정상적으로 작동 중입니다!"
elif [ $SUCCESS_RATE -ge 60 ]; then
    echo "⚠️ 일부 기능에 문제가 있을 수 있습니다"
else
    echo "❌ 심각한 문제가 있습니다. 로그를 확인하세요"
fi

# 9. 추가 정보
echo ""
echo "🔗 유용한 링크:"
echo "- Frontend: http://localhost:$PORT"
echo "- API Health: http://localhost:$PORT/actuator/health"
echo "- Swagger UI: http://localhost:$PORT/swagger-ui/"

echo ""
echo "🛠️ 문제 해결 명령어:"
echo "- 실시간 로그: docker-compose logs -f frontend"
echo "- 컨테이너 재시작: docker-compose restart frontend"
echo "- Nginx 설정 테스트: docker-compose exec frontend nginx -t"
echo "- 전체 재배포: ./build-backend-local.sh && docker-compose restart frontend"