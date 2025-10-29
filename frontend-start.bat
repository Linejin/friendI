@echo off
echo ========================================
echo         Frontend 서버 시작
echo ========================================
echo.

cd /d "d:\I\frontend"

echo 환경 설정을 확인 중...
if exist ".env.local" (
    echo .env.local 파일이 발견되었습니다.
) else (
    echo 주의: .env.local 파일이 없습니다. .env.example을 복사해서 .env.local을 만드세요.
)

echo.
echo Frontend 개발 서버를 시작합니다...
echo 포트: 3000
echo 환경: development
echo.
echo 종료하려면 Ctrl+C를 누르세요.
echo ========================================
echo.

npm start