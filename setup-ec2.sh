#!/bin/bash

# EC2 서버 초기 설정 스크립트
# Amazon Linux 2/Ubuntu 지원

echo "=========================================="
echo "    EC2 서버 초기 설정"
echo "=========================================="
echo ""

# OS 감지
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

echo "감지된 OS: $OS $VER"
echo ""

# 시스템 업데이트
echo "[1/4] 시스템 업데이트"
if [[ "$OS" == *"Amazon Linux"* ]]; then
    sudo yum update -y
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    sudo apt-get update && sudo apt-get upgrade -y
else
    echo "지원하지 않는 OS입니다. 수동으로 설치를 진행하세요."
    exit 1
fi
echo "✓ 시스템 업데이트 완료"
echo ""

# 필수 도구 설치
echo "[2/4] 필수 도구 설치"
if [[ "$OS" == *"Amazon Linux"* ]]; then
    sudo yum install -y git curl wget unzip htop
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    sudo apt-get install -y git curl wget unzip htop
fi
echo "✓ 필수 도구 설치 완료"
echo ""

# Docker 설치
echo "[3/4] Docker 설치"
if ! command -v docker &> /dev/null; then
    if [[ "$OS" == *"Amazon Linux"* ]]; then
        # Amazon Linux Docker 설치
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker ec2-user
        
    elif [[ "$OS" == *"Ubuntu"* ]]; then
        # Ubuntu Docker 설치
        sudo apt-get remove -y docker docker-engine docker.io containerd runc
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        
        # Docker GPG 키 추가
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Docker 저장소 추가
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Docker 설치
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker $USER
    fi
    
    echo "✓ Docker 설치 완료"
else
    echo "✓ Docker가 이미 설치되어 있습니다"
fi
echo ""

# Docker Compose 설치
echo "[4/4] Docker Compose 설치"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    # Docker Compose 최신 버전 설치
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # 심볼릭 링크 생성
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    echo "✓ Docker Compose 설치 완료: $COMPOSE_VERSION"
else
    echo "✓ Docker Compose가 이미 설치되어 있습니다"
fi
echo ""

# 방화벽 설정 (선택적)
echo "[추가 설정] 방화벽 포트 확인"
if command -v ufw &> /dev/null; then
    echo "Ubuntu 방화벽 상태:"
    sudo ufw status
    echo ""
    echo "필요한 포트를 열려면 다음 명령어를 사용하세요:"
    echo "  sudo ufw allow 22    # SSH"
    echo "  sudo ufw allow 80    # HTTP"
    echo "  sudo ufw allow 443   # HTTPS"
    echo "  sudo ufw allow 8080  # Backend API"
elif command -v firewall-cmd &> /dev/null; then
    echo "CentOS/RHEL 방화벽 상태:"
    sudo firewall-cmd --list-all
fi
echo ""

# 설치 완료 확인
echo "=========================================="
echo "           설치 완료 확인"
echo "=========================================="
echo ""

echo "📋 설치된 소프트웨어 버전:"
echo "  - Git: $(git --version)"
echo "  - Docker: $(docker --version)"

if command -v docker-compose &> /dev/null; then
    echo "  - Docker Compose: $(docker-compose --version)"
elif docker compose version &> /dev/null 2>&1; then
    echo "  - Docker Compose: $(docker compose version --short)"
fi
echo ""

echo "🔧 다음 단계:"
echo "1. 터미널을 재시작하거나 다음 명령어 실행:"
echo "   newgrp docker"
echo ""
echo "2. FriendlyI 프로젝트 클론:"
echo "   git clone https://github.com/Linejin/friendI.git"
echo "   cd friendI"
echo ""
echo "3. 배포 스크립트 실행:"
echo "   chmod +x deploy-ec2.sh"
echo "   ./deploy-ec2.sh"
echo ""

# 중요 사항 안내
echo "⚠️  중요 사항:"
echo "1. EC2 보안 그룹에서 필요한 포트(80, 443, 8080)를 열어야 합니다"
echo "2. 현재 사용자를 docker 그룹에 추가했습니다. 터미널 재시작이 필요할 수 있습니다"
echo "3. 충분한 디스크 공간(최소 10GB)과 메모리(최소 2GB)가 있는지 확인하세요"
echo ""

echo "=========================================="
echo "EC2 초기 설정이 완료되었습니다! 🎉"
echo "=========================================="