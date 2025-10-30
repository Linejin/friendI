#!/bin/bash
# FriendlyI 빠른 배포 스크립트 (EC2용)
# Usage: ./quick-deploy.sh

echo "🚀 FriendlyI 빠른 배포 시작..."

# 프로젝트 디렉토리 확인
if [ ! -d "backend" ]; then
    if [ ! -d "friendI" ]; then
        echo "📦 저장소 클론 중..."
        git clone https://github.com/Linejin/friendI.git
        cd friendI/backend
    else
        echo "📂 기존 프로젝트 디렉토리로 이동..."
        cd friendI/backend
    fi
else
    echo "📂 backend 디렉토리로 이동..."
    cd backend
fi

# 최신 코드 가져오기
echo "📥 최신 코드 업데이트 중..."
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "Git 업데이트 실패 (계속 진행)"

# 메모리 확인 및 환경 설정
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
echo "💾 시스템 메모리: ${TOTAL_MEM}MB"

if [ $TOTAL_MEM -lt 1500 ]; then
    echo "⚙️ EC2 Small 최적화 설정 적용"
    if [ -f ".env.small" ]; then
        cp .env.small .env
    else
        echo "⚠️ .env.small 파일이 없습니다. 기본 설정 사용"
        cp .env.example .env 2>/dev/null || echo "환경 파일 없음"
    fi
    COMPOSE_FILE="docker-compose.small.yml"
else
    echo "⚙️ 표준 설정 적용"
    [ ! -f ".env" ] && cp .env.example .env 2>/dev/null
    COMPOSE_FILE="docker-compose.yml"
fi

# Docker 및 Docker Compose 확인
if ! command -v docker &> /dev/null; then
    echo "🐳 Docker 설치 중..."
    if command -v yum &> /dev/null; then
        sudo yum update -y && sudo yum install -y docker
        sudo systemctl start docker && sudo systemctl enable docker
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y docker.io
        sudo systemctl start docker && sudo systemctl enable docker
    fi
    sudo usermod -aG docker $USER
fi

if ! command -v docker-compose &> /dev/null; then
    echo "🔧 Docker Compose 설치 중..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# 기존 컨테이너 중지
echo "🛑 기존 서비스 중지 중..."
docker-compose -f $COMPOSE_FILE down 2>/dev/null || docker-compose down 2>/dev/null || echo "중지할 서비스 없음"

# Docker 정리 (공간 절약)
echo "🧹 Docker 시스템 정리 중..."
docker system prune -f

# 새 버전 배포
echo "🚢 새 버전 배포 중..."
if [ -f "$COMPOSE_FILE" ]; then
    echo "📋 사용할 구성 파일: $COMPOSE_FILE"
    docker-compose -f $COMPOSE_FILE up -d --build
else
    echo "📋 기본 구성 파일 사용"
    docker-compose up -d --build
fi

echo "⏳ 서비스 시작 대기 중..."
sleep 20

# 상태 확인
echo "📊 서비스 상태 확인:"
if [ -f "$COMPOSE_FILE" ]; then
    docker-compose -f $COMPOSE_FILE ps
else
    docker-compose ps
fi

# 헬스체크
echo "🏥 애플리케이션 헬스체크 중..."
for i in {1..6}; do
    if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        echo "✅ 애플리케이션이 정상적으로 실행 중입니다!"
        break
    else
        if [ $i -eq 6 ]; then
            echo "⚠️ 헬스체크 실패. 로그 확인 필요"
        else
            echo "⏳ 헬스체크 재시도... ($i/6)"
            sleep 5
        fi
    fi
done

# 접속 정보
echo ""
echo "🎉 배포 완료!"
echo "📱 접속 URL:"
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP확인실패")
echo "   🌍 외부 접속: http://${PUBLIC_IP}:8080"
echo "   🏠 내부 접속: http://localhost:8080"
echo "   ❤️ 헬스체크: http://${PUBLIC_IP}:8080/actuator/health"

echo ""
echo "🔐 기본 계정:"
echo "   관리자: admin / admin123"
echo "   사용자: user1 / 1234"

echo ""
echo "💡 유용한 명령어:"
echo "   로그 확인: docker-compose logs -f"
echo "   상태 확인: docker-compose ps"
echo "   서비스 중지: docker-compose down"
echo ""
echo "⚠️ EC2 보안 그룹에서 8080 포트 인바운드 규칙을 추가하세요!"