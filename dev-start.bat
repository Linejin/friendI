@echo off
echo ========================================
echo    FriendlyI 개발 환경 실행 스크립트
echo ========================================
echo.

echo [1/3] Backend 서버 시작 중...
cd /d "d:\I\backend\backend"
start "Backend Server" cmd /k "gradlew bootRun"
echo Backend 서버가 백그라운드에서 시작되었습니다 (포트: 8080)
echo.

echo [2/3] 3초 대기 중... (Backend 초기화)
timeout /t 3 /nobreak > nul

echo [3/3] Frontend 개발 서버 시작 중...
cd /d "d:\I\frontend"
echo Frontend 개발 서버를 시작합니다 (포트: 3000)
echo.
echo ========================================
echo  애플리케이션 URL:
echo  - Frontend: http://localhost:3000
echo  - Backend:  http://localhost:8080
echo ========================================
echo.
npm start