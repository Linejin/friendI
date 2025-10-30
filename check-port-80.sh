#!/bin/bash
# 80 포트 사용 프로세스 확인 및 해결

echo "🔍 포트 80 사용 프로세스 확인 중..."

# 1. 80 포트 사용 프로세스 확인
echo "80 포트 사용 상황:"
if command -v lsof >/dev/null 2>&1; then
    sudo lsof -i :80 2>/dev/null || echo "lsof로 80 포트 사용 프로세스 없음"
else
    netstat -tlnp 2>/dev/null | grep ":80 " || echo "netstat으로 80 포트 사용 프로세스 없음"
fi

echo
echo "모든 웹 관련 포트 확인 (80, 443, 8080, 3000):"
netstat -tlnp 2>/dev/null | grep -E ":(80|443|8080|3000) " || echo "웹 관련 포트 사용 없음"

# 2. Apache/Nginx 서비스 확인
echo
echo "웹 서버 서비스 상태 확인:"
if systemctl is-active --quiet apache2 2>/dev/null; then
    echo "⚠️ Apache2 서비스가 실행 중입니다"
    echo "중지 방법: sudo systemctl stop apache2"
    echo "비활성화: sudo systemctl disable apache2"
elif systemctl is-active --quiet nginx 2>/dev/null; then
    echo "⚠️ Nginx 서비스가 실행 중입니다"
    echo "중지 방법: sudo systemctl stop nginx"
    echo "비활성화: sudo systemctl disable nginx"
elif systemctl is-active --quiet httpd 2>/dev/null; then
    echo "⚠️ HTTPd 서비스가 실행 중입니다"
    echo "중지 방법: sudo systemctl stop httpd"
    echo "비활성화: sudo systemctl disable httpd"
else
    echo "✅ 알려진 웹 서버 서비스 실행 중 아님"
fi

# 3. Docker 컨테이너 확인
echo
echo "80 포트를 사용하는 Docker 컨테이너 확인:"
docker ps --filter "publish=80" --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null || echo "80 포트 사용 Docker 컨테이너 없음"

# 4. 해결 옵션 제시
echo
echo "🛠️ 해결 방법 옵션:"
echo "════════════════════════════════════════"
echo "1. [권장] Frontend를 3000 포트로 사용"
echo "   ./fix-frontend-port.sh"
echo
echo "2. 80 포트 사용 서비스 중지 후 Frontend 80 포트 사용"
echo "   sudo systemctl stop apache2 nginx httpd"
echo "   docker-compose restart frontend"
echo
echo "3. 80 포트 사용 프로세스 직접 종료"
echo "   sudo lsof -i :80  # PID 확인"
echo "   sudo kill -9 [PID]  # 프로세스 종료"
echo
echo "4. 다른 포트로 Frontend 실행"
echo "   docker-compose.yml에서 포트 변경"
echo

# 5. 권장 해결책 실행 여부 확인
read -p "Frontend를 3000 포트로 변경하시겠습니까? (y/N): " choice
case "$choice" in 
    y|Y ) 
        echo "Frontend 포트를 3000으로 변경합니다..."
        ./fix-frontend-port.sh
        ;;
    * ) 
        echo "수동으로 해결하세요."
        ;;
esac