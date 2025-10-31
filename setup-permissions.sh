#!/bin/bash
# 실행 권한 부여 스크립트

echo "🔧 스크립트 및 Maven wrapper 실행 권한 부여 중..."
echo "================================================"

# 현재 디렉토리의 모든 .sh 파일에 실행 권한 부여
echo ""
echo "📝 .sh 파일들에 실행 권한 부여..."
for script in *.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "✅ $script"
    fi
done

# Maven wrapper 실행 권한 부여
echo ""
echo "📦 Maven wrapper 실행 권한 부여..."
if [ -f "backend/backend/mvnw" ]; then
    chmod +x "backend/backend/mvnw"
    echo "✅ backend/backend/mvnw"
else
    echo "⚠️ backend/backend/mvnw 파일을 찾을 수 없습니다"
fi

# Gradle wrapper 실행 권한 부여 (혹시 있다면)
if [ -f "backend/backend/gradlew" ]; then
    chmod +x "backend/backend/gradlew"
    echo "✅ backend/backend/gradlew"
fi

echo ""
echo "🎉 모든 실행 권한 부여 완료!"
echo ""
echo "📋 실행 가능한 스크립트들:"
ls -la *.sh 2>/dev/null | awk '{print "- " $9 " (권한: " $1 ")"}'

echo ""
echo "🚀 이제 다음 명령어들을 실행할 수 있습니다:"
echo "- ./build-backend-local.sh          # Backend 로컬 빌드 후 배포"
echo "- ./redeploy-backend-cors.sh        # Backend CORS 재배포"  
echo "- ./test-frontend.sh                # Frontend 테스트"
echo "- ./restart-fullstack-linux.sh      # 풀스택 재시작"