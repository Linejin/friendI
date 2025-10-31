# FriendlyI AWS EC2 배포 스크립트 가이드

## 📋 스크립트 개요

AWS EC2 t3.small 환경에서 FriendlyI 애플리케이션을 안정적으로 배포하고 관리하기 위한 스크립트 모음입니다.

## 🛠️ 스크립트 목록

### 1. `setup-ec2-initial.sh` - EC2 초기 환경 설정
**목적**: 새로운 EC2 인스턴스의 기본 환경을 설정합니다.

**주요 기능**:
- 시스템 패키지 업데이트
- Docker 및 Docker Compose 설치
- 2GB 스왑 메모리 설정 (t3.small 대응)
- 방화벽 기본 설정
- 시스템 최적화 (파일 디스크립터, 커널 매개변수)
- 모니터링 도구 설치

**실행 방법**:
```bash
chmod +x setup-ec2-initial.sh
./setup-ec2-initial.sh
```

### 2. `setup-permissions.sh` - 권한 설정
**목적**: Docker 및 파일 시스템 권한을 올바르게 설정합니다.

**주요 기능**:
- Docker 그룹 권한 설정
- 프로젝트 디렉터리 권한 설정
- 로그 로테이션 설정
- systemd 서비스 등록 (선택)
- 방화벽 규칙 설정 (선택)

**실행 방법**:
```bash
chmod +x setup-permissions.sh
./setup-permissions.sh

# 특정 기능만 실행
./setup-permissions.sh --docker-only
./setup-permissions.sh --files-only
./setup-permissions.sh --verify
```

### 3. `deploy-initial.sh` - 초기 배포
**목적**: 애플리케이션을 처음 배포합니다.

**주요 기능**:
- 시스템 요구사항 검증
- 스왑 메모리 자동 생성 (필요시)
- 환경 설정 파일 생성
- 필요 디렉터리 생성
- Docker 이미지 빌드 및 컨테이너 시작
- 서비스 헬스 체크
- 배포 정보 표시

**실행 방법**:
```bash
chmod +x deploy-initial.sh
./deploy-initial.sh
```

### 4. `redeploy-zero-downtime.sh` - 무중단 재배포
**목적**: 서비스 중단 없이 애플리케이션을 업데이트합니다.

**주요 기능**:
- 자동 백업 생성
- 최신 코드 확인 및 업데이트
- 롤링 업데이트 (백엔드/프론트엔드)
- 헬스 체크 및 자동 롤백
- 미사용 이미지 정리

**실행 방법**:
```bash
chmod +x redeploy-zero-downtime.sh

# 무중단 재배포
./redeploy-zero-downtime.sh

# 상태 확인
./redeploy-zero-downtime.sh status

# 롤백
./redeploy-zero-downtime.sh rollback
```

### 5. `monitor-ec2.sh` - 시스템 모니터링
**목적**: 시스템 리소스와 애플리케이션 상태를 모니터링합니다.

**주요 기능**:
- 시스템 리소스 모니터링 (CPU, 메모리, 디스크)
- Docker 서비스 상태 확인
- 애플리케이션 헬스 체크
- 로그 오류 검사
- 네트워크 연결성 테스트
- 성능 리포트 생성

**실행 방법**:
```bash
chmod +x monitor-ec2.sh

# 전체 모니터링
./monitor-ec2.sh

# 실시간 모니터링
./monitor-ec2.sh --watch

# 성능 리포트 생성
./monitor-ec2.sh --report

# 특정 항목만 확인
./monitor-ec2.sh --logs      # 로그만
./monitor-ec2.sh --network   # 네트워크만
./monitor-ec2.sh --system    # 시스템 정보만
```

## 🐳 Docker 설정 파일

### `docker-compose.yml` - 표준 환경
**대상**: t3.medium 이상 (4GB+ RAM)
- 백엔드: 최대 1.5GB 메모리
- 프론트엔드: 최대 512MB 메모리

### `docker-compose.lowmem.yml` - 저사양 환경
**대상**: t3.small (2GB RAM)
- 백엔드: 최대 768MB 메모리
- 프론트엔드: 최대 128MB 메모리
- Serial GC 사용으로 메모리 사용량 최적화

**사용법**:
```bash
# 저사양 환경에서 배포
docker-compose -f docker-compose.lowmem.yml up -d
```

## 🚀 배포 시나리오

### 시나리오 1: 새 EC2 인스턴스 설정
```bash
# 1. EC2 초기 설정
./setup-ec2-initial.sh

# 2. 재부팅 (권장)
sudo reboot

# 3. 프로젝트 클론
git clone https://github.com/Linejin/friendI.git
cd friendI

# 4. 권한 설정
./setup-permissions.sh

# 5. 초기 배포
./deploy-initial.sh
```

### 시나리오 2: 코드 업데이트 배포
```bash
# 무중단 재배포
./redeploy-zero-downtime.sh
```

### 시나리오 3: 문제 발생 시 롤백
```bash
# 자동 롤백
./redeploy-zero-downtime.sh rollback
```

### 시나리오 4: 시스템 모니터링
```bash
# 현재 상태 확인
./monitor-ec2.sh

# 지속적 모니터링 (별도 터미널)
./monitor-ec2.sh --watch
```

## ⚠️ 주의사항 및 팁

### t3.small 환경 최적화
1. **스왑 메모리 필수**: 2GB 스왑 설정 권장
2. **메모리 모니터링**: 85% 이상 사용 시 주의
3. **빌드 시간**: 초기 빌드 시 10-15분 소요 가능
4. **동시 빌드 금지**: 하나의 컨테이너씩 순차 빌드

### AWS 보안 그룹 설정
```
인바운드 규칙:
- Type: SSH, Port: 22, Source: Your IP
- Type: HTTP, Port: 80, Source: 0.0.0.0/0  
- Type: Custom TCP, Port: 8080, Source: 0.0.0.0/0
```

### 로그 확인 방법
```bash
# Docker 컨테이너 로그
docker-compose logs -f backend
docker-compose logs -f frontend

# 애플리케이션 로그
tail -f logs/application.log

# 시스템 로그
journalctl -u docker.service -f
```

### 백업 및 복구
```bash
# 수동 백업
tar -czf backup-$(date +%Y%m%d).tar.gz logs/ data/ docker-compose.yml

# 백업에서 복구
tar -xzf backup-YYYYMMDD.tar.gz
docker-compose up -d
```

## 📞 트러블슈팅

### 자주 발생하는 문제들

1. **메모리 부족 (OOMKilled)**
   ```bash
   # 스왑 확인
   free -h
   
   # 저사양 설정 사용
   docker-compose -f docker-compose.lowmem.yml up -d
   ```

2. **Docker 권한 오류**
   ```bash
   # 권한 재설정
   ./setup-permissions.sh --docker-only
   newgrp docker
   ```

3. **포트 충돌**
   ```bash
   # 사용 중인 포트 확인
   sudo ss -tuln | grep ':80\|:8080'
   
   # 기존 서비스 중지
   sudo systemctl stop nginx
   ```

4. **디스크 공간 부족**
   ```bash
   # Docker 정리
   docker system prune -af
   
   # 로그 정리
   sudo truncate -s 0 logs/*.log
   ```

## 🔄 업데이트 및 유지보수

### 정기 유지보수 (월 1회 권장)
```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# Docker 이미지 정리
docker system prune -f

# 로그 정리 (자동화된 로그 로테이션 사용)

# 백업 확인
ls -la backups/
```

### 모니터링 자동화
```bash
# crontab 등록 (매시간 모니터링)
echo "0 * * * * /path/to/monitor-ec2.sh >> /var/log/friendlyi-monitor.log 2>&1" | crontab -
```

이 가이드를 통해 AWS EC2에서 FriendlyI 애플리케이션을 안정적으로 배포하고 운영할 수 있습니다.