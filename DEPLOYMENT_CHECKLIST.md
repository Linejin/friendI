# FriendlyI 배포 체크리스트

## ✅ 배포 전 최종 점검사항

### 🐳 Docker 설정
- [x] Dockerfile 문법 검증
- [x] docker-compose.yml 설정 검증
- [x] 메모리 제한 설정 적절
- [x] 헬스체크 구현
- [x] 멀티스테이지 빌드

### 🔒 보안 설정
- [x] 기본 패스워드 변경
- [x] 환경변수 기반 보안 정보
- [x] H2 콘솔 비활성화 (운영환경)
- [x] 비root 사용자 실행
- [x] 최소 권한 원칙

### 💾 메모리 최적화
- [x] JVM 힙 크기 최적화
- [x] GC 설정 (Serial GC for t3.small)
- [x] 컨테이너 메모리 제한
- [x] 스왑 메모리 설정

### 📊 모니터링
- [x] 헬스체크 엔드포인트
- [x] 시스템 리소스 모니터링
- [x] 로그 로테이션
- [x] 성능 메트릭 수집

### 🚀 배포 스크립트
- [x] 시스템 요구사항 검증
- [x] 자동 환경 설정
- [x] 무중단 배포 지원
- [x] 자동 롤백 기능
- [x] 오류 처리 및 로깅

## 🎯 AWS EC2 t3.small 최적화

### 메모리 사용량 (2GB 총 RAM)
- 백엔드: 768MB (38%)
- 프론트엔드: 128MB (6%)
- 시스템: 512MB (26%)
- 여유: 640MB (30%)
- 스왑: 2GB (추가)

### JVM 설정
```bash
JAVA_OPTS=-Xmx512m -Xms128m -XX:+UseSerialGC -XX:MaxRAMPercentage=60
```

### Docker 리소스 제한
```yaml
deploy:
  resources:
    limits:
      memory: 768M
    reservations:
      memory: 128M
```

## 📋 배포 명령어

### 1. EC2 초기 설정 (최초 1회)
```bash
./setup-ec2-initial.sh
```

### 2. 배포 전 검증
```bash
./validate-deployment.sh
```

### 3. 초기 배포
```bash
./deploy-initial.sh
```

### 4. 무중단 재배포
```bash
./redeploy-zero-downtime.sh
```

### 5. 모니터링
```bash
./monitor-ec2.sh --watch
```

## 🔍 트러블슈팅

### 메모리 부족 시
```bash
# 스왑 확인
free -h

# 저사양 설정 사용
docker-compose -f docker-compose.lowmem.yml up -d
```

### 빌드 실패 시
```bash
# Docker 정리
docker system prune -af

# 순차 빌드
docker-compose build --no-cache backend
docker-compose build --no-cache frontend
```

### 포트 충돌 시
```bash
# 사용 중인 포트 확인
sudo ss -tuln | grep ':80\|:8080'

# 기존 서비스 중지
sudo systemctl stop nginx apache2
```

## ✨ 배포 완료!

모든 점검사항을 통과했습니다. 
AWS EC2 t3.small 환경에서 안전하게 배포할 수 있습니다! 🚀