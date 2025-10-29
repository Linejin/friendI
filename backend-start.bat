@echo off
echo ========================================
echo         Backend 서버 시작
echo ========================================
echo.

cd /d "d:\I\backend\backend"

echo 환경 설정을 확인 중...
if exist ".env" (
    echo .env 파일이 발견되었습니다.
) else (
    echo 주의: .env 파일이 없습니다. .env.example을 복사해서 .env를 만드세요.
)

echo.
echo Backend 서버를 시작합니다...
echo 포트: 8080
echo Profile: development
echo.
echo 종료하려면 Ctrl+C를 누르세요.
echo ========================================
echo.

gradlew bootRun