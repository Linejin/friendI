# EC2 배포 가이드

## 🚀 EC2에서 FriendlyI 배포하기

### 1단계: EC2 인스턴스 생성
```bash
# EC2 인스턴스 타입: t3.small (2GB RAM, 2 vCPU) 권장
# AMI: Amazon Linux 2 또는 Ubuntu 22.04 LTS
# 보안 그룹: SSH(22), HTTP(80), Custom(8080) 포트 열기
```

### 2단계: 스크립트 다운로드 및 실행권한 부여
```bash
# EC2에 접속 후
wget https://raw.githubusercontent.com/Linejin/friendI/master/auto-deploy.sh
wget https://raw.githubusercontent.com/Linejin/friendI/master/quick-deploy.sh
wget https://raw.githubusercontent.com/Linejin/friendI/master/setup-ec2.sh
wget https://raw.githubusercontent.com/Linejin/friendI/master/monitor.sh

chmod +x *.sh
```

### 3단계: 시스템 초기 설정 (최초 1회만)
```bash
./setup-ec2.sh
```

### 4단계: 애플리케이션 배포
```bash
# 완전 자동 배포 (권장)
./auto-deploy.sh

# 또는 빠른 배포
./quick-deploy.sh
```

### 5단계: 모니터링
```bash
./monitor.sh
```

## 📋 주요 명령어

### 배포 관련
```bash
# 전체 자동 배포
./auto-deploy.sh

# EC2 Small 강제 모드
./auto-deploy.sh --small

# 빠른 재배포
./quick-deploy.sh

# 시스템 모니터링
./monitor.sh
```

### Docker 관리
```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f

# 서비스 재시작
docker-compose restart

# 서비스 중지
docker-compose down

# 완전 재빌드
docker-compose up -d --build
```

### 시스템 확인
```bash
# 시스템 리소스
htop
free -h
df -h

# 네트워크 포트
netstat -tlnp | grep :8080

# Docker 상태
docker stats
docker system df
```

## 🔧 문제 해결

### 메모리 부족 시
```bash
# 스왑 파일 확인
free -h

# Docker 메모리 사용량 확인
docker stats

# 불필요한 이미지 정리
docker system prune -a
```

### 포트 충돌 시
```bash
# 8080 포트 사용 프로세스 확인
sudo netstat -tlnp | grep :8080
sudo lsof -i :8080

# 프로세스 종료
sudo kill -9 <PID>
```

### 컨테이너 실행 실패 시
```bash
# 상세 로그 확인
docker-compose logs backend

# 컨테이너 상태 확인
docker-compose ps

# 강제 재시작
docker-compose down
docker-compose up -d --force-recreate
```

## 🔐 보안 설정

### EC2 보안 그룹
- **인바운드 규칙**:
  - SSH: 포트 22 (관리자 IP만)
  - HTTP: 포트 80 (전체 또는 필요한 IP)
  - Custom: 포트 8080 (전체 또는 필요한 IP)

### 애플리케이션 보안
```bash
# .env 파일에서 기본 비밀번호 변경
vi .env

# 변경 필수 항목:
DB_PASSWORD=새로운_DB_비밀번호
REDIS_PASSWORD=새로운_Redis_비밀번호
JWT_SECRET=새로운_JWT_시크릿_키
ADMIN_PASSWORD=새로운_관리자_비밀번호
```

## 📊 성능 최적화

### EC2 t3.small 최적화 설정
```bash
# 이미 auto-deploy.sh에 포함된 최적화:
# - JVM 메모리: 512MB 제한
# - PostgreSQL: 메모리 사용량 최적화
# - Redis: 128MB 제한
# - Tomcat: 스레드 수 제한
```

### 모니터링 설정
```bash
# 실시간 모니터링 시작
./monitor.sh

# 시스템 로그 확인
sudo journalctl -f

# Docker 로그 확인
docker-compose logs -f --tail=100
```

## 🌐 접속 정보

배포 완료 후 다음 URL로 접속:
- **메인 API**: `http://EC2_PUBLIC_IP:8080`
- **헬스체크**: `http://EC2_PUBLIC_IP:8080/actuator/health`
- **API 문서**: `http://EC2_PUBLIC_IP:8080/swagger-ui.html`

### 기본 계정
- **관리자**: admin / admin123
- **테스트 사용자**: user1 / 1234

⚠️ **프로덕션에서는 반드시 기본 비밀번호를 변경하세요!**