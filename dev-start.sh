#!/bin/bash

echo "========================================"
echo "   FriendlyI 개발 환경 실행 스크립트"
echo "========================================"
echo ""

echo "[1/3] Backend 서버 시작 중..."
cd "backend/backend"
echo "Backend 서버를 백그라운드에서 시작합니다 (포트: 8080)"
./gradlew bootRun &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"
cd - > /dev/null

echo ""
echo "[2/3] 3초 대기 중... (Backend 초기화)"
sleep 3

echo "[3/3] Frontend 개발 서버 시작 중..."
cd "frontend"
echo "Frontend 개발 서버를 시작합니다 (포트: 3000)"
echo ""
echo "========================================"
echo " 애플리케이션 URL:"
echo " - Frontend: http://localhost:3000"
echo " - Backend:  http://localhost:8080"
echo "========================================"
echo ""
echo "종료하려면 Ctrl+C를 누르세요"
echo ""

# Frontend 시작
npm start

# 스크립트 종료 시 Backend도 함께 종료
echo ""
echo "Frontend 서버가 종료되었습니다."
echo "Backend 서버도 종료 중..."
kill $BACKEND_PID 2>/dev/null
echo "모든 서버가 종료되었습니다."