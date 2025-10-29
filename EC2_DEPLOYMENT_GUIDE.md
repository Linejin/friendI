# EC2 Linux 배포 문제 해결 가이드

## 🚨 현재 문제 해결

### Docker 이미지 문제 해결
**문제**: `openjdk:21-jre-slim: not found`
**원인**: OpenJDK 공식 이미지 정책 변경으로 일부 태그가 deprecated
**해결**: Eclipse Temurin (AdoptOpenJDK 후속) 이미지로 변경

#### 변경 내용:
```dockerfile
# 변경 전 (문제 있음)
FROM openjdk:21-jre-slim

# 변경 후 (안정적)
FROM eclipse-temurin:21-jre-alpine
```

### Docker Compose 버전 경고 해결
**문제**: `version` is obsolete
**해결**: Docker Compose v2 형식으로 수정 (version 필드 제거)

## 🛠 EC2 Linux 배포 가이드

### 1단계: EC2 서버 준비
```bash
# EC2 초기 설정 (최초 1회만)
curl -fsSL https://raw.githubusercontent.com/Linejin/friendI/master/setup-ec2.sh | bash

# 또는 수동으로
chmod +x setup-ec2.sh
./setup-ec2.sh
```

### 2단계: 프로젝트 배포
```bash
# 프로젝트 클론
git clone https://github.com/Linejin/friendI.git
cd friendI

# 배포 실행
chmod +x deploy-ec2.sh
./deploy-ec2.sh
```

## 🔧 일반적인 문제들

### 1. Docker 권한 문제
```bash
# 문제: permission denied while trying to connect to the Docker daemon socket
# 해결:
sudo usermod -aG docker $USER
newgrp docker
# 또는 터미널 재시작
```

### 2. 포트 충돌
```bash
# 문제: 포트 80 또는 8080이 이미 사용 중
# 확인:
sudo ss -tuln | grep ':80\|:8080'

# 해결: 기존 서비스 중지 또는 포트 변경
sudo systemctl stop nginx  # Nginx가 80 포트 사용 중인 경우
sudo systemctl stop apache2  # Apache가 80 포트 사용 중인 경우
```

### 3. 메모리 부족
```bash
# 문제: 컨테이너가 OOMKilled 상태
# 확인:
free -h
docker stats

# 해결: EC2 인스턴스 타입 업그레이드 (최소 t3.medium 권장)
# 또는 메모리 설정 조정
```

### 4. 네트워크 연결 문제
```bash
# 문제: 외부에서 접속 불가
# 해결: EC2 보안 그룹 설정

# AWS 콘솔에서 보안 그룹 편집:
# - Type: HTTP, Port: 80, Source: 0.0.0.0/0
# - Type: Custom TCP, Port: 8080, Source: 0.0.0.0/0
# - Type: HTTPS, Port: 443, Source: 0.0.0.0/0 (선택적)
```

### 5. 빌드 실패
```bash
# 문제: Gradle 빌드 실패
# 확인:
docker-compose logs backend

# 해결 방법들:
# 1. 디스크 공간 확인
df -h

# 2. 메모리 확인 및 스왑 설정
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 3. 빌드 타임아웃 증가 (docker-compose.yml)
GRADLE_OPTS: "-Dorg.gradle.daemon=false -Xmx1g"
```

## 🔍 모니터링 및 로그

### 실시간 모니터링
```bash
# 컨테이너 상태 확인
docker-compose ps

# 리소스 사용량 모니터링
docker stats

# 실시간 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f backend
docker-compose logs -f frontend
```

### 로그 파일 위치
```bash
# 애플리케이션 로그
./logs/application.log

# Docker 로그
journalctl -u docker.service

# 시스템 로그
tail -f /var/log/syslog  # Ubuntu
tail -f /var/log/messages  # CentOS/RHEL
```

## 🚀 성능 최적화

### JVM 최적화
```yaml
# docker-compose.yml에서 JVM 옵션 조정
environment:
  - JAVA_OPTS=-Xmx1g -Xms512m -XX:+UseG1GC -XX:+UseContainerSupport
```

### Nginx 최적화
```nginx
# nginx.conf에서 설정 추가
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
gzip on;
```

### Docker 이미지 최적화
```dockerfile
# 멀티스테이지 빌드 활용
# Alpine 베이스 이미지 사용
# .dockerignore 파일 최적화
```

## 🛡️ 보안 설정

### 1. 방화벽 설정
```bash
# Ubuntu UFW
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# CentOS/RHEL FirewallD
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 2. SSL/TLS 설정 (선택적)
```bash
# Let's Encrypt SSL 인증서 설치
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

### 3. 정기 업데이트
```bash
# 자동 업데이트 스크립트 생성
#!/bin/bash
cd /home/ec2-user/friendI
git pull origin master
docker-compose up --build -d
docker system prune -f
```

## 📞 추가 지원

### 로그 수집
```bash
# 문제 발생 시 다음 정보 수집
echo "=== System Info ===" > debug.log
uname -a >> debug.log
cat /etc/os-release >> debug.log

echo "=== Docker Info ===" >> debug.log
docker --version >> debug.log
docker-compose --version >> debug.log

echo "=== Container Status ===" >> debug.log
docker-compose ps >> debug.log

echo "=== Container Logs ===" >> debug.log
docker-compose logs >> debug.log

echo "=== System Resources ===" >> debug.log
free -h >> debug.log
df -h >> debug.log
```

### 유용한 명령어
```bash
# 전체 재배포 (clean slate)
docker-compose down -v
docker system prune -af
git pull origin master
./deploy-ec2.sh

# 백업
tar -czf friendlyi-backup-$(date +%Y%m%d).tar.gz logs/ data/

# 복구
docker-compose down
tar -xzf friendlyi-backup-YYYYMMDD.tar.gz
docker-compose up -d
```