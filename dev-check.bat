@echo off
echo ========================================
echo       개발 환경 설정 확인
echo ========================================
echo.

echo [Frontend 설정 확인]
cd /d "d:\I\frontend"
echo 현재 위치: %cd%

if exist "package.json" (
    echo ✓ package.json 존재
) else (
    echo ✗ package.json 없음
)

if exist "node_modules" (
    echo ✓ node_modules 존재
) else (
    echo ✗ node_modules 없음 - npm install 필요
)

if exist ".env.local" (
    echo ✓ .env.local 존재
) else (
    echo ⚠ .env.local 없음 - .env.example을 복사하여 생성 필요
)

echo.
echo [Backend 설정 확인]
cd /d "d:\I\backend\backend"
echo 현재 위치: %cd%

if exist "build.gradle" (
    echo ✓ build.gradle 존재
) else (
    echo ✗ build.gradle 없음
)

if exist "gradlew.bat" (
    echo ✓ gradlew.bat 존재
) else (
    echo ✗ gradlew.bat 없음
)

if exist ".env" (
    echo ✓ .env 존재
) else (
    echo ⚠ .env 없음 - .env.example을 복사하여 생성 필요
)

echo.
echo [Java 버전 확인]
java -version

echo.
echo [Node.js 버전 확인]
cd /d "d:\I\frontend"
node --version
npm --version

echo.
echo ========================================
echo.

if not exist "d:\I\frontend\.env.local" (
    echo [설정 필요]
    echo Frontend .env.local 파일을 생성하세요:
    echo   cd frontend
    echo   copy .env.example .env.local
    echo.
)

if not exist "d:\I\backend\backend\.env" (
    echo Backend .env 파일을 생성하세요:
    echo   cd backend\backend
    echo   copy .env.example .env
    echo.
)

if not exist "d:\I\frontend\node_modules" (
    echo Frontend 의존성을 설치하세요:
    echo   cd frontend
    echo   npm install
    echo.
)

echo 모든 확인이 완료되었습니다!
pause