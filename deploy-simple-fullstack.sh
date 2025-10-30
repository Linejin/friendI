#!/bin/bash
# 간단한 전체 스택 배포

echo "🚀 FriendlyI 전체 스택 배포 시작..."

# 현재 상태 확인
echo "현재 디스크 사용량:"
df -h / | grep -v Filesystem

# 기존 서비스 정리
echo "기존 서비스 정리 중..."
docker-compose down 2>/dev/null || true

# 전체 스택 빌드 및 시작
echo "전체 스택 빌드 및 시작 중... (시간이 소요됩니다)"
docker-compose up -d --build

# 서비스 시작 대기
echo "서비스 시작 대기 중... (120초)"
sleep 120

# 상태 확인
echo "전체 서비스 상태:"
docker-compose ps

# 헬스체크
echo "서비스 헬스체크..."

# PostgreSQL 체크
if docker-compose ps postgres | grep -q "healthy"; then
    echo "✅ PostgreSQL: 정상"
else
    echo "❌ PostgreSQL: 비정상"
fi

# Redis 체크
if docker-compose ps redis | grep -q "healthy"; then
    echo "✅ Redis: 정상"
else
    echo "❌ Redis: 비정상"
fi

# Backend 체크
if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
    echo "✅ Backend: 정상"
    curl -s http://localhost:8080/actuator/health | grep -o '"status":"[^"]*"' || echo ""
else
    echo "❌ Backend: 비정상"
    echo "Backend 로그:"
    docker-compose logs --tail=10 backend
fi

# Frontend 체크
FRONTEND_PORT=80
if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    FRONTEND_PORT=3000
fi

if curl -f http://localhost:$FRONTEND_PORT >/dev/null 2>&1; then
    echo "✅ Frontend: 정상 (포트 $FRONTEND_PORT)"
else
    echo "❌ Frontend: 비정상"
    echo "Frontend 로그:"
    docker-compose logs --tail=10 frontend
fi

# 접속 정보
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")

echo
echo "🎉 배포 완료!"
echo "📋 접속 정보:"
echo "   🌐 웹사이트: http://$PUBLIC_IP:$FRONTEND_PORT"
echo "   🔧 API: http://$PUBLIC_IP:8080"
echo "   📚 API 문서: http://$PUBLIC_IP:8080/swagger-ui/index.html"
echo "   💾 헬스체크: http://$PUBLIC_IP:8080/actuator/health"
echo
echo "🛠️ 관리 명령어:"
echo "   전체 로그: docker-compose logs -f"
echo "   상태 확인: docker-compose ps"
echo "   서비스 재시작: docker-compose restart"
echo "   서비스 중지: docker-compose down"