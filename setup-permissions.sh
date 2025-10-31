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
echo ""
echo "📦 배포 스크립트:"
echo "- ./deploy-initial.sh              # 초기 배포 (DB 데이터 보존, 앱 재배포)"
echo "- ./redeploy-zero-downtime.sh      # 무중단 재배포 (기존 서비스 유지하며 업데이트)"
echo ""
echo "📊 모니터링 스크립트:"
echo "- ./monitor-ec2.sh                 # EC2 리소스 및 서비스 모니터링"
echo ""
echo "🧹 유지보수 스크립트:"
echo "- ./cleanup-resources.sh           # Docker 및 시스템 리소스 정리"
echo ""
echo "🔧 기타 스크립트:"
echo "- ./build-backend-local.sh         # Backend 로컬 빌드만"
echo "- ./test-frontend.sh               # Frontend 테스트"
echo "- ./cleanup-disk-space.sh          # 디스크 공간 정리"
echo ""
echo "💡 배포 가이드:"
echo "1. 첫 배포:        ./deploy-initial.sh (DB 데이터 보존)"
echo "2. 코드 업데이트:  ./redeploy-zero-downtime.sh (무중단)"
echo "3. 상태 모니터링:  ./monitor-ec2.sh"
echo "4. 문제 발생 시:   ./deploy-initial.sh로 전체 재배포"
echo "5. 정기 정리:      ./cleanup-resources.sh"