#!/bin/bash

# 502 Bad Gateway 디버깅 스크립트
echo "🔍 502 Bad Gateway 문제 진단 중..."
echo "=========================================="

# 1. 컨테이너 상태 확인
echo -e "\n📦 컨테이너 상태:"
sudo docker ps -a

echo -e "\n📊 컨테이너 상태 요약:"
sudo docker-compose -f docker-compose.minimal.yml ps

# 2. 백엔드 컨테이너 로그 상세 확인
echo -e "\n📝 백엔드 컨테이너 로그 (최근 50줄):"
sudo docker logs friendlyi-backend-minimal --tail 50

# 3. 백엔드 헬스체크 직접 테스트
echo -e "\n🏥 백엔드 헬스체크 테스트:"
echo "내부 컨테이너 네트워크에서 테스트..."
sudo docker exec friendlyi-frontend-minimal curl -v http://backend:8080/actuator/health 2>/dev/null || echo "❌ 컨테이너 간 연결 실패"

echo -e "\n로컬호스트에서 테스트..."
curl -v http://localhost:8080/actuator/health 2>/dev/null || echo "❌ 로컬호스트 연결 실패"

# 4. 네트워크 상태 확인
echo -e "\n🌐 네트워크 상태:"
sudo netstat -tulpn | grep -E ':8080|:3000'

# 5. Docker 네트워크 확인
echo -e "\n🔗 Docker 네트워크:"
sudo docker network ls
sudo docker network inspect $(sudo docker-compose -f docker-compose.minimal.yml ps -q | head -1 | xargs sudo docker inspect --format='{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' 2>/dev/null) 2>/dev/null | grep -A 5 '"Name"'

# 6. 백엔드 컨테이너 내부 프로세스 확인
echo -e "\n⚙️ 백엔드 컨테이너 내부 프로세스:"
sudo docker exec friendlyi-backend-minimal ps aux 2>/dev/null || echo "백엔드 컨테이너가 실행되지 않음"

# 7. 메모리 사용량 확인
echo -e "\n💾 메모리 사용량:"
free -h
sudo docker stats --no-stream

# 8. 백엔드 컨테이너 재시작 테스트
echo -e "\n🔄 백엔드 컨테이너 재시작 시도..."
sudo docker restart friendlyi-backend-minimal

echo "⏳ 30초 대기 후 재테스트..."
sleep 30

echo -e "\n🔄 재시작 후 백엔드 테스트:"
curl -s http://localhost:8080/actuator/health || echo "❌ 여전히 연결 실패"

# 9. 최종 진단
echo -e "\n🎯 진단 요약:"
if sudo docker ps | grep -q "friendlyi-backend-minimal"; then
    echo "✅ 백엔드 컨테이너: 실행 중"
else
    echo "❌ 백엔드 컨테이너: 실행되지 않음"
fi

if sudo docker ps | grep -q "friendlyi-frontend-minimal"; then
    echo "✅ 프론트엔드 컨테이너: 실행 중"
else
    echo "❌ 프론트엔드 컨테이너: 실행되지 않음"
fi

if netstat -tulpn | grep -q ":8080"; then
    echo "✅ 포트 8080: 리스닝 중"
else
    echo "❌ 포트 8080: 리스닝하지 않음"
fi

echo -e "\n💡 해결 방안:"
echo "1. 백엔드 컨테이너가 죽어있다면: sudo docker-compose -f docker-compose.minimal.yml restart backend"
echo "2. 메모리 부족이라면: sudo docker system prune -f"
echo "3. 설정 문제라면: ./rebuild-ec2.sh 실행"
echo "4. 포트 8080 보안 그룹 확인 필요"