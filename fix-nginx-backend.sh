#!/bin/bash

# nginx 백엔드 연결 수정 스크립트

echo "🔧 nginx 백엔드 연결 수정 중..."
echo "======================================="

# 1. 최신 코드 가져오기
echo -e "\n📥 최신 코드 가져오기:"
git pull origin master

# 2. 현재 실행 중인 컨테이너들 상태 확인
echo -e "\n📊 현재 컨테이너 상태:"
sudo docker ps | grep friendlyi

# 3. 프론트엔드 컨테이너만 재빌드 (nginx 설정 반영)
echo -e "\n🔨 프론트엔드 컨테이너 재빌드:"
sudo docker-compose -f docker-compose.minimal.yml build --no-cache frontend

# 4. 프론트엔드 컨테이너 재시작
echo -e "\n🔄 프론트엔드 컨테이너 재시작:"
sudo docker-compose -f docker-compose.minimal.yml up -d frontend

# 5. 잠시 대기 후 상태 확인
echo -e "\n⏳ 10초 대기 중..."
sleep 10

echo -e "\n✅ 업데이트된 컨테이너 상태:"
sudo docker ps | grep friendlyi

# 6. nginx 설정 확인
echo -e "\n🔍 nginx 설정 확인:"
sudo docker exec friendlyi-frontend-minimal cat /etc/nginx/nginx.conf | grep -A 10 "location /api/"

# 7. 백엔드 연결 테스트
echo -e "\n🧪 백엔드 연결 테스트:"
echo "프론트엔드 → 백엔드 연결 테스트..."
sudo docker exec friendlyi-frontend-minimal wget -qO- http://backend:8080/actuator/health 2>/dev/null || echo "❌ 연결 실패"

# 8. 외부 접근 테스트
echo -e "\n🌐 외부 접근 테스트:"
curl -s http://localhost:3000 > /dev/null && echo "✅ 프론트엔드 접근 가능" || echo "❌ 프론트엔드 접근 실패"
curl -s http://localhost:8080/swagger-ui/index.html > /dev/null && echo "✅ 백엔드 접근 가능" || echo "❌ 백엔드 접근 실패"

echo -e "\n🎯 테스트 방법:"
echo "1. 웹 브라우저에서 http://$(curl -s ifconfig.me):3000 접속"
echo "2. 로그인 페이지에서 admin / friendlyi2025! 로 로그인 시도"
echo "3. Network 탭에서 /api/auth/login 요청 결과 확인"

echo -e "\n✅ nginx 백엔드 연결 수정 완료!"