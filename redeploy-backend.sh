#!/bin/bash
# Backend 설정 수정 후 빠른 재배포

echo "🚀 Backend 설정 수정 후 재배포 시작..."

# 기존 Backend 정리
echo "1. 기존 Backend 컨테이너 정리..."
docker-compose stop backend 2>/dev/null || true
docker-compose rm -f backend 2>/dev/null || true

# Backend 이미지도 삭제 (설정 변경으로 인한 새 빌드 필요)
echo "2. 기존 Backend 이미지 삭제..."
docker rmi friendlyi-backend:latest 2>/dev/null || true

# PostgreSQL, Redis 상태 확인
echo "3. 데이터베이스 서비스 상태 확인..."
if ! docker-compose ps postgres | grep -q "Up" || ! docker-compose ps redis | grep -q "Up"; then
    echo "   데이터베이스 서비스 시작 중..."
    docker-compose up -d postgres redis
    echo "   데이터베이스 시작 대기... (45초)"
    sleep 45
else
    echo "   ✅ 데이터베이스 서비스 실행 중"
fi

# Backend 새로 빌드
echo "4. Backend 새로 빌드 중... (시간이 소요됩니다)"
docker-compose build --no-cache backend

# Backend 시작
echo "5. Backend 컨테이너 시작..."
docker-compose up -d backend

# 시작 대기
echo "6. Backend 시작 대기... (90초)"
sleep 90

# 상태 확인
echo "7. 서비스 상태 확인:"
docker-compose ps

echo "8. Backend 로그 확인 (최근 30줄):"
docker-compose logs --tail=30 backend

# 헬스체크
echo "9. Backend 헬스체크..."
for i in {1..10}; do
    if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
        echo "✅ Backend 헬스체크 성공!"
        
        # 성공 정보 출력
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
        echo
        echo "🎉 Backend 재배포 성공!"
        echo "📋 접속 정보:"
        echo "   🔧 Backend API: http://$PUBLIC_IP:8080"
        echo "   💾 헬스체크: http://$PUBLIC_IP:8080/actuator/health"
        echo "   📊 API 문서: http://$PUBLIC_IP:8080/swagger-ui.html"
        echo
        echo "📊 데이터베이스 연결 테스트:"
        curl -s http://localhost:8080/actuator/health | grep -o '"status":"[^"]*"' || echo "헬스체크 응답 확인 필요"
        
        exit 0
    else
        echo "   헬스체크 재시도... ($i/10)"
        sleep 15
    fi
done

echo "❌ Backend 헬스체크 실패"
echo
echo "🔍 문제 진단:"
echo "전체 로그:"
docker-compose logs backend

echo
echo "컨테이너 상세 정보:"
docker inspect friendlyi-backend-friendi | grep -A 10 -B 10 "State"

echo
echo "포트 확인:"
netstat -tlnp | grep 8080

exit 1