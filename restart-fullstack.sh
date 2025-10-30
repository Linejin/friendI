#!/bin/bash
# 풀스택 배포 재시작 스크립트 (포트 충돌 해결 포함)

set -e

echo "🚀 풀스택 배포 재시작 중..."
echo "================================"

# 1. 현재 컨테이너 상태 확인
echo "📋 현재 컨테이너 상태:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. 실행 중인 컨테이너들 정리
echo
echo "🧹 기존 컨테이너 정리 중..."
docker-compose down --remove-orphans

# 3. 포트 80 사용 여부 확인 및 해결
echo
echo "🔍 포트 충돌 확인 중..."
if netstat -tlnp 2>/dev/null | grep ":80 " >/dev/null; then
    echo "⚠️ 포트 80이 사용 중입니다"
    echo "Frontend를 3000 포트로 변경하여 배포합니다"
    
    # docker-compose.yml에서 Frontend 포트 변경
    if grep -q "80:80" docker-compose.yml; then
        sed -i 's/80:80/3000:80/g' docker-compose.yml
        sed -i 's/443:443/3443:443/g' docker-compose.yml
        echo "✅ Frontend 포트를 3000으로 변경했습니다"
    fi
else
    echo "✅ 포트 80 사용 가능"
fi

# 4. Docker 이미지 빌드
echo
echo "🔨 이미지 빌드 중..."
docker-compose build --no-cache

# 5. 데이터베이스 먼저 시작
echo
echo "💾 데이터베이스 서비스 시작 중..."
docker-compose up -d postgres redis

# 6. 데이터베이스 연결 대기
echo "⏳ 데이터베이스 준비 대기 중..."
sleep 10

# PostgreSQL 연결 확인
echo "PostgreSQL 연결 확인 중..."
timeout=60
counter=0
while ! docker exec -i i-postgres pg_isready -h localhost -p 5432 >/dev/null 2>&1; do
    counter=$((counter + 1))
    if [ $counter -gt $timeout ]; then
        echo "❌ PostgreSQL 연결 실패 - 타임아웃"
        exit 1
    fi
    echo "PostgreSQL 대기 중... ($counter/$timeout)"
    sleep 1
done
echo "✅ PostgreSQL 준비 완료"

# Redis 연결 확인
echo "Redis 연결 확인 중..."
timeout=30
counter=0
while ! docker exec -i i-redis redis-cli ping >/dev/null 2>&1; do
    counter=$((counter + 1))
    if [ $counter -gt $timeout ]; then
        echo "❌ Redis 연결 실패 - 타임아웃"
        exit 1
    fi
    echo "Redis 대기 중... ($counter/$timeout)"
    sleep 1
done
echo "✅ Redis 준비 완료"

# 7. Backend 시작
echo
echo "⚙️ Backend 서비스 시작 중..."
docker-compose up -d backend

# Backend 헬스체크 대기
echo "Backend 헬스체크 대기 중..."
timeout=120
counter=0
while ! curl -s http://localhost:8080/actuator/health >/dev/null 2>&1; do
    counter=$((counter + 1))
    if [ $counter -gt $timeout ]; then
        echo "❌ Backend 헬스체크 실패 - 타임아웃"
        echo "Backend 로그 확인:"
        docker logs i-backend --tail 20
        exit 1
    fi
    echo "Backend 대기 중... ($counter/$timeout)"
    sleep 1
done
echo "✅ Backend 준비 완료"

# 8. Frontend 시작
echo
echo "🌐 Frontend 서비스 시작 중..."
docker-compose up -d frontend

# Frontend 헬스체크 대기
echo "Frontend 헬스체크 대기 중..."
frontend_port=$(docker-compose port frontend 80 2>/dev/null | cut -d: -f2)
if [ -z "$frontend_port" ]; then
    frontend_port=3000  # 기본값
fi

timeout=60
counter=0
while ! curl -s http://localhost:$frontend_port >/dev/null 2>&1; do
    counter=$((counter + 1))
    if [ $counter -gt $timeout ]; then
        echo "❌ Frontend 헬스체크 실패 - 타임아웃"
        echo "Frontend 로그 확인:"
        docker logs i-frontend --tail 20
        exit 1
    fi
    echo "Frontend 대기 중... ($counter/$timeout)"
    sleep 1
done
echo "✅ Frontend 준비 완료"

# 9. 최종 상태 확인
echo
echo "🎉 풀스택 배포 완료!"
echo "======================="
echo "📋 서비스 상태:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "🌐 접속 정보:"
echo "- Frontend: http://localhost:$frontend_port"
if [ "$frontend_port" != "80" ]; then
    echo "- Frontend HTTPS: https://localhost:3443"
fi
echo "- Backend API: http://localhost:8080"
echo "- Backend Health: http://localhost:8080/actuator/health"
echo "- Swagger UI: http://localhost:8080/swagger-ui.html"
echo "- PostgreSQL: localhost:5433"
echo "- Redis: localhost:6379"

echo
echo "🔧 유용한 명령어:"
echo "- 전체 로그 보기: docker-compose logs -f"
echo "- 개별 로그 보기: docker logs i-[service-name]"
echo "- 서비스 재시작: docker-compose restart [service-name]"
echo "- 전체 중지: docker-compose down"

# 10. AWS 보안 그룹 업데이트 알림
if [ "$frontend_port" != "80" ]; then
    echo
    echo "📝 AWS 보안 그룹 업데이트 필요:"
    echo "- EC2 보안 그룹에서 포트 $frontend_port 인바운드 규칙 추가"
    echo "- 기존 80 포트 규칙은 제거 가능"
fi

echo
echo "✅ 풀스택 배포가 완료되었습니다!"