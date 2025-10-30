#!/bin/bash

# FriendlyI EC2 Linux 배포 스크립트

echo "=========================================="
echo "    FriendlyI EC2 Linux 배포 시작"
echo "=========================================="
echo ""

# Gradle wrapper 권한 확인 및 수정
echo "[Gradle Wrapper 권한 확인]"
if [ -f "backend/backend/gradlew" ]; then
    if [ ! -x "backend/backend/gradlew" ]; then
        echo "⚠️ Gradle wrapper에 실행 권한이 없습니다. 권한을 부여합니다..."
        chmod +x backend/backend/gradlew
        echo "✓ 실행 권한 부여 완료"
    else
        echo "✓ Gradle wrapper 실행 권한 확인 완료"
    fi
else
    echo "❌ backend/backend/gradlew 파일을 찾을 수 없습니다."
    exit 1
fi

# Gradle wrapper JAR 파일 확인 및 복구
echo "[Gradle Wrapper JAR 확인]"
GRADLE_WRAPPER_JAR="backend/backend/gradle/wrapper/gradle-wrapper.jar"

if [ ! -f "$GRADLE_WRAPPER_JAR" ]; then
    echo "⚠️ gradle-wrapper.jar 파일이 없습니다."
    echo "💡 Gradle이 처음 실행될 때 자동으로 다운로드됩니다."
    echo "   빌드 과정에서 자동으로 해결됩니다."
else
    echo "✓ gradle-wrapper.jar 파일 확인 완료"
fi
echo ""

# 시스템 정보 확인
echo "[시스템 정보 확인]"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | grep ^Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $4}') available"
echo ""

# Docker 및 Docker Compose 버전 확인
echo "[Docker 환경 확인]"
if command -v docker &> /dev/null; then
    echo "✓ Docker: $(docker --version)"
else
    echo "❌ Docker가 설치되어 있지 않습니다."
    echo "Docker 설치 가이드: https://docs.docker.com/engine/install/"
    exit 1
fi

if command -v docker-compose &> /dev/null; then
    echo "✓ Docker Compose: $(docker-compose --version)"
elif docker compose version &> /dev/null; then
    echo "✓ Docker Compose: $(docker compose version)"
else
    echo "❌ Docker Compose가 설치되어 있지 않습니다."
    exit 1
fi
echo ""

# 포트 사용 여부 확인
echo "[포트 확인]"
if ss -tuln | grep -q ":80 "; then
    echo "⚠️ 포트 80이 사용 중입니다. 기존 서비스를 중지하거나 포트를 변경하세요."
    ss -tuln | grep ":80 "
fi

if ss -tuln | grep -q ":8080 "; then
    echo "⚠️ 포트 8080이 사용 중입니다. 기존 서비스를 중지하거나 포트를 변경하세요."
    ss -tuln | grep ":8080 "
fi
echo ""

# 환경 설정 확인
echo "[환경 설정 확인]"
if [ -f "docker-compose.yml" ]; then
    echo "✓ docker-compose.yml 존재"
else
    echo "❌ docker-compose.yml 파일이 없습니다."
    exit 1
fi

if [ -f ".env" ]; then
    echo "✓ .env 파일 존재"
else
    echo "⚠️ .env 파일이 없습니다. 기본 설정으로 진행합니다."
fi
echo ""

# 기존 컨테이너 정리
echo "[기존 컨테이너 정리]"
if docker ps -a | grep -q "friendlyi"; then
    echo "기존 FriendlyI 컨테이너를 정리합니다..."
    docker-compose down -v 2>/dev/null || true
    echo "✓ 기존 컨테이너 정리 완료"
else
    echo "✓ 정리할 컨테이너 없음"
fi
echo ""

# 로그 디렉토리 생성
echo "[로그 디렉토리 생성]"
mkdir -p logs
chmod 755 logs
echo "✓ 로그 디렉토리 생성 완료"
echo ""

# 메모리 기반 빌드 전략 선택
MEMORY_MB=$(free -m | awk 'NR==2{printf "%.0f", $2}')
echo "[메모리 기반 배포 전략 선택]"
echo "사용 가능한 메모리: ${MEMORY_MB}MB"

if [ "$MEMORY_MB" -lt 1500 ]; then
    echo "⚠️ 메모리가 부족합니다 (${MEMORY_MB}MB < 1500MB)"
    echo "대안 빌드 스크립트를 실행합니다..."
    chmod +x build-alternative.sh
    ./build-alternative.sh
    exit $?
elif [ "$MEMORY_MB" -lt 3000 ]; then
    echo "🔄 저사양 최적화 모드로 빌드합니다..."
    COMPOSE_FILE="docker-compose.lowmem.yml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        # 저사양 compose 파일이 없으면 생성
        sed 's/dockerfile: Dockerfile/dockerfile: Dockerfile.lowmem/' docker-compose.yml > docker-compose.lowmem.yml
    fi
else
    echo "🚀 표준 모드로 빌드합니다..."
    COMPOSE_FILE="docker-compose.yml"
fi

# Docker 이미지 빌드 및 실행
echo "[애플리케이션 배포 - $COMPOSE_FILE 사용]"
echo "Docker 이미지 빌드를 시작합니다... (시간이 오래 걸릴 수 있습니다)"

if docker-compose -f "$COMPOSE_FILE" up --build -d; then
    echo "✓ 애플리케이션 빌드 및 실행 성공"
else
    echo "❌ 애플리케이션 실행 실패"
    echo ""
    echo "빌드 로그를 확인합니다..."
    docker-compose -f "$COMPOSE_FILE" logs
    
    echo ""
    echo "🔧 문제 해결 옵션:"
    echo "1. 메모리 부족인 경우: 대안 빌드 스크립트 실행"
    echo "   ./build-alternative.sh"
    echo ""
    echo "2. EC2 인스턴스 업그레이드 (t3.medium 이상 권장)"
    echo ""
    echo "3. 스왑 파일 생성으로 가상 메모리 증가"
    echo "   sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile"
    echo "   sudo mkswap /swapfile && sudo swapon /swapfile"
    
    exit 1
fi
echo ""

# 서비스 시작 대기
echo "[서비스 시작 대기]"
echo "서비스가 완전히 시작될 때까지 기다립니다..."

# Backend 헬스체크
for i in {1..30}; do
    if curl -f -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo "✓ Backend 서비스 시작 완료"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "⚠️ Backend 서비스 시작 확인 실패 (30초 대기 완료)"
        echo "수동으로 확인하세요: curl http://localhost:8080/actuator/health"
        break
    fi
    
    echo "Backend 서비스 시작 대기 중... ($i/30)"
    sleep 1
done

# Frontend 확인
sleep 5
if curl -f -s http://localhost > /dev/null 2>&1; then
    echo "✓ Frontend 서비스 시작 완료"
else
    echo "⚠️ Frontend 서비스 시작 확인 실패"
    echo "수동으로 확인하세요: curl http://localhost"
fi
echo ""

# 최종 상태 확인
echo "[배포 완료 - 서비스 상태]"
docker-compose ps
echo ""

# 서비스 URL 안내
echo "=========================================="
echo "           배포 완료! 🚀"
echo "=========================================="
echo ""
echo "📡 서비스 접속 URL:"

# 퍼블릭 IP 확인 시도
PUBLIC_IP=$(curl -s -m 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
PRIVATE_IP=$(curl -s -m 5 http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

if [ "$PUBLIC_IP" != "YOUR_EC2_PUBLIC_IP" ]; then
    echo "🌍 퍼블릭 접속: http://$PUBLIC_IP"
    echo "🏠 프라이빗 접속: http://$PRIVATE_IP"
else
    echo "🏠 로컬 접속: http://localhost"
    echo "🌍 외부 접속: http://[EC2_PUBLIC_IP]"
fi

echo ""
echo "🔍 서비스 상태 확인:"
echo "  - Backend Health: curl http://localhost:8080/actuator/health"
echo "  - Frontend: curl http://localhost"
echo ""
echo "📊 모니터링:"
echo "  - 로그 확인: docker-compose logs -f"
echo "  - 컨테이너 상태: docker-compose ps"
echo "  - 시스템 리소스: docker stats"
echo ""
echo "🛠 관리 명령어:"
echo "  - 서비스 중지: docker-compose down"
echo "  - 서비스 재시작: docker-compose restart"
echo "  - 로그 디렉토리: ./logs/"
echo ""

# 보안 그룹 확인 안내
echo "⚠️  중요 사항:"
echo "1. EC2 보안 그룹에서 포트 80, 8080을 열어야 외부 접속이 가능합니다"
echo "2. 운영 환경에서는 HTTPS(443) 설정을 권장합니다"
echo "3. 정기적인 보안 업데이트와 모니터링이 필요합니다"
echo ""
echo "=========================================="