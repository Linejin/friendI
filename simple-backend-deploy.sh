#!/bin/bash
# 초간단 Backend 배포 스크립트

echo "🚀 Backend 간단 배포 시작..."

# 기존 Backend 정리
echo "기존 Backend 컨테이너 정리..."
docker-compose stop backend 2>/dev/null || true
docker-compose rm -f backend 2>/dev/null || true

# PostgreSQL, Redis 확인 및 시작
echo "데이터베이스 서비스 확인 및 시작..."
docker-compose up -d postgres redis

# 30초 대기
echo "데이터베이스 시작 대기... (30초)"
sleep 30

# Backend 빌드 및 시작
echo "Backend 빌드 및 시작..."
docker-compose build --no-cache backend
docker-compose up -d backend

# 60초 대기
echo "Backend 시작 대기... (60초)"
sleep 60

# 상태 확인
echo "전체 서비스 상태:"
docker-compose ps

echo "Backend 로그 (최근 20줄):"
docker-compose logs --tail=20 backend

# 헬스체크
echo "헬스체크 시도..."
if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
    echo "✅ Backend 배포 성공!"
    echo "🔗 API 접속: http://$(curl -s ifconfig.me):8080"
else
    echo "❌ Backend 헬스체크 실패"
    echo "Backend 전체 로그:"
    docker-compose logs backend
fi