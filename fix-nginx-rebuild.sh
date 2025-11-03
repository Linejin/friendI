#!/bin/bash

# Nginx 설정 검증 및 컨테이너 재빌드 스크립트
echo "🔧 Nginx 설정 수정 후 재빌드 중..."

# 1. 현재 컨테이너 중단
echo "📋 기존 컨테이너 중단..."
sudo docker-compose -f docker-compose.minimal.yml down

# 2. 프론트엔드 이미지 삭제 (새로운 nginx.conf 적용을 위해)
echo "🗑️ 기존 프론트엔드 이미지 삭제..."
sudo docker rmi $(sudo docker images | grep friendlyi-frontend | awk '{print $3}') 2>/dev/null || echo "기존 이미지 없음"

# 3. 프론트엔드만 다시 빌드
echo "🔨 프론트엔드 컨테이너 재빌드..."
sudo docker-compose -f docker-compose.minimal.yml build --no-cache frontend

# 4. 모든 서비스 시작
echo "🚀 모든 서비스 시작..."
sudo docker-compose -f docker-compose.minimal.yml up -d

# 5. 컨테이너 상태 확인
echo "📊 컨테이너 상태 확인..."
sleep 15
sudo docker ps

echo -e "\n📝 프론트엔드 로그 확인:"
sudo docker logs friendlyi-frontend-minimal --tail 10

echo -e "\n📝 백엔드 로그 확인:"
sudo docker logs friendlyi-backend-minimal --tail 10

# 6. 포트 연결 테스트
echo -e "\n🔌 포트 연결 테스트:"
if curl -s --connect-timeout 5 http://localhost:3000 > /dev/null; then
    echo "✅ 포트 3000: 연결 성공!"
else
    echo "❌ 포트 3000: 연결 실패"
fi

if curl -s --connect-timeout 5 http://localhost:8080/actuator/health > /dev/null; then
    echo "✅ 포트 8080: 연결 성공!"
else
    echo "❌ 포트 8080: 연결 실패"
fi

# 7. 외부 IP 표시
EC2_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null)
echo -e "\n🌐 접속 URL:"
echo "프론트엔드: http://$EC2_IP:3000"
echo "백엔드 API: http://$EC2_IP:8080/api"

echo -e "\n✅ 재빌드 완료!"