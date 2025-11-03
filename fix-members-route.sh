#!/bin/bash

# 회원관리 페이지 라우트 수정 후 프론트엔드 재빌드 스크립트

echo "🔧 회원관리 페이지 라우트 수정 후 프론트엔드 재빌드"
echo "==========================================="

# 1. 최신 코드 가져오기
echo -e "\n📥 최신 코드 가져오기:"
git pull origin master

# 2. 현재 실행 중인 컨테이너들 상태 확인
echo -e "\n📊 현재 컨테이너 상태:"
sudo docker ps | grep friendlyi

# 3. 프론트엔드 컨테이너만 재빌드 (라우트 수정사항 반영)
echo -e "\n🔨 프론트엔드 컨테이너 재빌드:"
sudo docker-compose -f docker-compose.minimal.yml build --no-cache frontend

# 4. 프론트엔드 컨테이너 재시작
echo -e "\n🔄 프론트엔드 컨테이너 재시작:"
sudo docker-compose -f docker-compose.minimal.yml up -d frontend

# 5. 잠시 대기 후 상태 확인
echo -e "\n⏳ 15초 대기 중..."
sleep 15

echo -e "\n✅ 업데이트된 컨테이너 상태:"
sudo docker ps | grep friendlyi

# 6. 라우트 테스트
echo -e "\n🔍 라우트 테스트:"
echo "프론트엔드 메인 페이지..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 && echo " ✅ 프론트엔드 접근 가능" || echo " ❌ 프론트엔드 접근 실패"

echo "백엔드 API..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/swagger-ui/index.html && echo " ✅ 백엔드 Swagger 접근 가능" || echo " ❌ 백엔드 접근 실패"

# 7. 컨테이너 로그 확인 (마지막 10줄)
echo -e "\n📝 프론트엔드 컨테이너 로그 (최근 10줄):"
sudo docker logs friendlyi-frontend-minimal --tail 10

echo -e "\n🎯 테스트 방법:"
echo "1. 웹 브라우저에서 http://$(curl -s ifconfig.me):3000 접속"
echo "2. admin / friendlyi2025! 로 로그인"
echo "3. 상단 네비게이션에서 '회원관리' 메뉴 확인"
echo "4. /members 페이지 접근 테스트"

echo -e "\n✅ 회원관리 페이지 라우트 수정 완료!"
echo "⚠️  관리자 계정(ROOSTER 등급)만 회원관리 페이지에 접근 가능합니다."