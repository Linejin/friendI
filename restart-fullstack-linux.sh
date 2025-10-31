#!/bin/bash
# 풀스택 배포 재시작 스크립트 (Linux/macOS) - 완전 새 버전

# 기본 설정
FRONTEND_PORT=3000
FRONTEND_HTTPS_PORT=3443

# 옵션 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            FRONTEND_PORT="$2"
            shift 2
            ;;
        --https-port)
            FRONTEND_HTTPS_PORT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--port PORT] [--https-port HTTPS_PORT]"
            exit 1
            ;;
    esac
done

echo "🚀 풀스택 배포 재시작 중..."
echo "Frontend Port: $FRONTEND_PORT"
echo "Frontend HTTPS Port: $FRONTEND_HTTPS_PORT"
echo "================================"

# 1. 현재 컨테이너 상태 확인
echo ""
echo "📋 현재 컨테이너 상태:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. 실행 중인 컨테이너들 정리
echo ""
echo "🧹 기존 컨테이너 정리 중..."
docker-compose down --remove-orphans 2>/dev/null
echo "✅ 컨테이너 정리 완료"

# 3. 포트 80 사용 여부 확인 및 해결
echo ""
echo "🔍 포트 충돌 확인 중..."
if netstat -tlnp 2>/dev/null | grep ":80 " >/dev/null; then
    echo "⚠️ 포트 80이 사용 중입니다"
    echo "Frontend를 $FRONTEND_PORT 포트로 변경하여 배포합니다"
    
    # docker-compose.yml에서 Frontend 포트 변경
    if [ -f "docker-compose.yml" ]; then
        if grep -q "80:80" docker-compose.yml; then
            sed -i.bak "s/80:80/$FRONTEND_PORT:80/g" docker-compose.yml
            sed -i.bak "s/443:443/$FRONTEND_HTTPS_PORT:443/g" docker-compose.yml
            echo "✅ Frontend 포트를 $FRONTEND_PORT 으로 변경했습니다"
        fi
    fi
else
    echo "✅ 포트 80 사용 가능"
    FRONTEND_PORT=80
    FRONTEND_HTTPS_PORT=443
fi

# 4. Docker 이미지 빌드
echo ""
echo "🔨 이미지 빌드 중..."
if docker-compose build --no-cache; then
    echo "✅ 이미지 빌드 완료"
else
    echo "⚠️ 이미지 빌드 중 일부 오류 발생, 계속 진행합니다"
fi

# 5. 데이터베이스 먼저 시작
echo ""
echo "💾 데이터베이스 서비스 시작 중..."
docker-compose up -d postgres redis 2>/dev/null
echo "✅ 데이터베이스 서비스 시작 완료"

# 6. 데이터베이스 연결 대기
echo ""
echo "⏳ 데이터베이스 준비 대기 중..."
sleep 10

# PostgreSQL 연결 확인
echo "PostgreSQL 연결 확인 중..."
TIMEOUT=60
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if docker exec i-postgres pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
        echo "✅ PostgreSQL 준비 완료"
        break
    fi
    
    COUNTER=$((COUNTER + 1))
    echo "PostgreSQL 대기 중... ($COUNTER/$TIMEOUT)"
    sleep 1
done

if [ $COUNTER -eq $TIMEOUT ]; then
    echo "❌ PostgreSQL 연결 실패 - 타임아웃"
    docker logs i-postgres --tail 20 2>/dev/null
    exit 1
fi

# Redis 연결 확인
echo "Redis 연결 확인 중..."
TIMEOUT=30
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if docker exec i-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo "✅ Redis 준비 완료"
        break
    fi
    
    COUNTER=$((COUNTER + 1))
    echo "Redis 대기 중... ($COUNTER/$TIMEOUT)"
    sleep 1
done

if [ $COUNTER -eq $TIMEOUT ]; then
    echo "❌ Redis 연결 실패 - 타임아웃"
    docker logs i-redis --tail 20 2>/dev/null
    exit 1
fi

# 7. Backend 시작
echo ""
echo "⚙️ Backend 서비스 시작 중..."
docker-compose up -d backend 2>/dev/null
echo "✅ Backend 서비스 시작 완료"

# Backend 헬스체크 대기
echo "Backend 헬스체크 대기 중..."
TIMEOUT=120
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        echo "✅ Backend 준비 완료"
        break
    fi
    
    COUNTER=$((COUNTER + 1))
    echo "Backend 대기 중... ($COUNTER/$TIMEOUT)"
    sleep 1
done

if [ $COUNTER -eq $TIMEOUT ]; then
    echo "❌ Backend 헬스체크 실패 - 타임아웃"
    echo "Backend 로그 확인:"
    docker logs i-backend --tail 20
    exit 1
fi

# 8. Frontend 시작
echo ""
echo "🌐 Frontend 서비스 시작 중..."
docker-compose up -d frontend 2>/dev/null
echo "✅ Frontend 서비스 시작 완료"

# Frontend 헬스체크 대기
echo "Frontend 헬스체크 대기 중..."
TIMEOUT=60
COUNTER=0

while [ $COUNTER -lt $TIMEOUT ]; do
    if curl -s -f http://localhost:$FRONTEND_PORT >/dev/null 2>&1; then
        echo "✅ Frontend 준비 완료"
        break
    fi
    
    COUNTER=$((COUNTER + 1))
    echo "Frontend 대기 중... ($COUNTER/$TIMEOUT)"
    sleep 1
done

if [ $COUNTER -eq $TIMEOUT ]; then
    echo "❌ Frontend 헬스체크 실패 - 타임아웃"
    echo "Frontend 로그 확인:"
    docker logs i-frontend --tail 20
fi

# 9. 최종 상태 확인
echo ""
echo "🎉 풀스택 배포 완료!"
echo "======================="

echo ""
echo "📋 서비스 상태:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🌐 접속 정보:"
echo "- Frontend: http://localhost:$FRONTEND_PORT"
if [ "$FRONTEND_PORT" != "80" ]; then
    echo "- Frontend HTTPS: https://localhost:$FRONTEND_HTTPS_PORT"
fi
echo "- Backend API: http://localhost:8080"
echo "- Backend Health: http://localhost:8080/actuator/health"
echo "- Swagger UI: http://localhost:8080/swagger-ui.html"
echo "- PostgreSQL: localhost:5433"
echo "- Redis: localhost:6379"

echo ""
echo "🔧 유용한 명령어:"
echo "- 전체 로그 보기: docker-compose logs -f"
echo "- 개별 로그 보기: docker logs i-[service-name]"
echo "- 서비스 재시작: docker-compose restart [service-name]"
echo "- 전체 중지: docker-compose down"

# 10. AWS 보안 그룹 업데이트 알림
if [ "$FRONTEND_PORT" != "80" ]; then
    echo ""
    echo "📝 AWS 보안 그룹 업데이트 필요:"
    echo "- EC2 보안 그룹에서 포트 $FRONTEND_PORT 인바운드 규칙 추가"
    echo "- 기존 80 포트 규칙은 제거 가능"
fi

echo ""
echo "✅ 풀스택 배포가 완료되었습니다!"