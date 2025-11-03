# 502 Bad Gateway 빠른 진단 가이드

## 1. 백엔드 컨테이너 상태 확인
```bash
# 컨테이너 실행 상태
sudo docker ps -a | grep backend

# 백엔드 로그 확인 
sudo docker logs friendlyi-backend-minimal --tail 20

# 백엔드 재시작 (메모리 이슈 가능성)
sudo docker restart friendlyi-backend-minimal
```

## 2. 포트 8080 확인
```bash
# 포트 8080이 리스닝되는지 확인
sudo netstat -tulpn | grep 8080

# 백엔드 헬스체크 직접 테스트
curl http://localhost:8080/actuator/health
```

## 3. 메모리 이슈 확인 (t3.small 2GB 제한)
```bash
# 현재 메모리 사용량
free -h

# 컨테이너별 메모리 사용량
sudo docker stats --no-stream

# 시스템 리소스 정리
sudo docker system prune -f
```

## 4. AWS 보안 그룹 확인
**EC2 콘솔에서 확인 필요:**
- 인바운드 규칙에 포트 8080이 있는지 확인
- 현재 3000번 포트만 열려있을 가능성 높음

## 5. 네트워크 문제 해결
```bash
# nginx 설정 재확인
sudo docker exec friendlyi-frontend-minimal cat /etc/nginx/nginx.conf | grep -A 10 "location /api"

# Docker 네트워크 재생성
sudo docker-compose -f docker-compose.minimal.yml down
sudo docker-compose -f docker-compose.minimal.yml up -d
```

## 6. 가장 가능성 높은 원인들:
1. **백엔드 컨테이너가 메모리 부족으로 죽음** (t3.small 2GB 제한)
2. **AWS 보안 그룹에 8080 포트 미개방**
3. **백엔드 JVM 시작 실패** (메모리 설정 문제)
4. **Spring Boot 애플리케이션 시작 오류**

즉시 확인하세요:
```bash
sudo docker ps | grep backend
sudo netstat -tulpn | grep 8080
free -h
```