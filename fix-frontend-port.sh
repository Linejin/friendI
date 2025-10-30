#!/bin/bash
# 포트 80 충돌 해결 및 Frontend 재배포

echo "🔧 포트 80 충돌 해결 중..."

# 1. 현재 80 포트 사용 프로세스 확인
echo "현재 80 포트 사용 상황:"
netstat -tlnp 2>/dev/null | grep ":80 " || echo "80 포트 사용 프로세스 없음"

# 2. Frontend 컨테이너 정리
echo "기존 Frontend 컨테이너 정리..."
docker-compose stop frontend 2>/dev/null || true
docker-compose rm -f frontend 2>/dev/null || true

# 3. Docker Compose에서 Frontend 포트를 3000으로 변경
echo "Frontend 포트를 3000으로 변경..."
cp docker-compose.yml docker-compose.yml.backup

# 포트 변경
sed -i 's/"80:80"/"3000:80"/g' docker-compose.yml
sed -i 's/- "80:80"/- "3000:80"/g' docker-compose.yml

echo "변경된 포트 설정 확인:"
grep -A 3 -B 1 "3000:80" docker-compose.yml || echo "포트 설정 변경됨"

# 4. Frontend 재시작
echo "Frontend 서비스 재시작 중..."
docker-compose up -d frontend

# 5. Frontend 시작 대기
echo "Frontend 시작 대기 중... (60초)"
sleep 60

# 6. 상태 확인
echo "Frontend 컨테이너 상태:"
docker-compose ps frontend

# 7. 헬스체크
echo "Frontend 헬스체크 (포트 3000)..."
for i in {1..5}; do
    if curl -f http://localhost:3000 >/dev/null 2>&1; then
        echo "✅ Frontend 헬스체크 성공! (포트 3000)"
        
        # 성공 정보
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
        echo
        echo "🎉 Frontend 포트 변경 완료!"
        echo "📋 새로운 접속 정보:"
        echo "   🌐 Frontend: http://$PUBLIC_IP:3000"
        echo "   🔧 Backend: http://$PUBLIC_IP:8080"
        echo "   📚 API 문서: http://$PUBLIC_IP:3000/swagger-ui/"
        echo "   💾 헬스체크: http://$PUBLIC_IP:3000/actuator/health"
        echo
        echo "⚠️ AWS 보안 그룹에 3000 포트 인바운드 규칙 추가 필요!"
        
        exit 0
    else
        echo "Frontend 헬스체크 재시도... ($i/5)"
        sleep 10
    fi
done

echo "❌ Frontend 헬스체크 실패"
echo "Frontend 로그 확인:"
docker-compose logs --tail=20 frontend

echo
echo "💡 수동 해결 방법:"
echo "1. 80 포트 사용 프로세스 확인: sudo lsof -i :80"
echo "2. 프로세스 종료: sudo kill -9 [PID]"
echo "3. 다시 시도: docker-compose up -d frontend"

exit 1