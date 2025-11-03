#!/bin/bash

# EC2 연결 문제 진단 스크립트
echo "🔍 EC2 FriendlyI 연결 문제 진단 중..."
echo "==========================================\n"

# 1. Docker 컨테이너 상태 확인
echo "📦 Docker 컨테이너 상태:"
sudo docker ps -a

echo -e "\n📊 컨테이너 리소스 사용량:"
sudo docker stats --no-stream

echo -e "\n💾 시스템 메모리 사용량:"
free -h

echo -e "\n🌐 네트워크 포트 상태:"
sudo netstat -tulpn | grep -E ':3000|:8080|:5432|:6379'

echo -e "\n🔥 방화벽 상태 (ufw):"
sudo ufw status

echo -e "\n📋 최근 Docker Compose 서비스 상태:"
sudo docker-compose -f docker-compose.minimal.yml ps

echo -e "\n📝 백엔드 컨테이너 로그 (최근 20줄):"
sudo docker logs friendlyi-backend-minimal --tail 20

echo -e "\n📝 프론트엔드 컨테이너 로그 (최근 20줄):"
sudo docker logs friendlyi-frontend-minimal --tail 20

echo -e "\n🏥 컨테이너 헬스체크 상태:"
sudo docker inspect friendlyi-backend-minimal | grep -A 5 '"Health"'
sudo docker inspect friendlyi-frontend-minimal | grep -A 5 '"Health"'

echo -e "\n🔌 EC2 인스턴스 외부 IP:"
curl -s http://checkip.amazonaws.com

echo -e "\n🔧 보안 그룹 확인이 필요한 포트들:"
echo "  - 포트 3000: 프론트엔드 (HTTP)"  
echo "  - 포트 8080: 백엔드 API (HTTP)"
echo "  - 포트 22: SSH 접속"
echo -e "\n💡 AWS 콘솔에서 EC2 > 보안 그룹 > 인바운드 규칙을 확인하세요!"

echo -e "\n==========================================\n"
echo "✅ 진단 완료! 위 정보를 확인해보세요."