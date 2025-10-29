@echo off
echo ========================================
echo      개발 환경 초기 설정
echo ========================================
echo.

echo [1/4] Frontend 환경 설정 중...
cd /d "d:\I\frontend"

if not exist ".env.local" (
    if exist ".env.example" (
        copy ".env.example" ".env.local"
        echo ✓ .env.local 파일이 생성되었습니다.
    ) else (
        echo ⚠ .env.example 파일이 없습니다.
    )
) else (
    echo ✓ .env.local 파일이 이미 존재합니다.
)

echo.
echo [2/4] Frontend 의존성 설치 중...
if not exist "node_modules" (
    echo npm install을 실행 중입니다...
    npm install
    echo ✓ Frontend 의존성 설치 완료
) else (
    echo ✓ node_modules가 이미 존재합니다.
)

echo.
echo [3/4] Backend 환경 설정 중...
cd /d "d:\I\backend\backend"

if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env"
        echo ✓ .env 파일이 생성되었습니다.
    ) else (
        echo ⚠ .env.example 파일이 없습니다.
    )
) else (
    echo ✓ .env 파일이 이미 존재합니다.
)

echo.
echo [4/4] Backend Gradle 권한 설정...
if exist "gradlew.bat" (
    echo ✓ gradlew.bat 파일이 존재합니다.
) else (
    echo ⚠ gradlew.bat 파일이 없습니다.
)

echo.
echo ========================================
echo        초기 설정 완료!
echo ========================================
echo.
echo 이제 다음 명령으로 개발 서버를 시작할 수 있습니다:
echo.
echo [전체 실행]
echo   dev-start.bat
echo.
echo [개별 실행]
echo   backend-start.bat   (Backend만)
echo   frontend-start.bat  (Frontend만)
echo.
echo [설정 확인]
echo   dev-check.bat
echo.
echo ========================================
pause