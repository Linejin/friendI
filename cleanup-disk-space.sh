#!/bin/bash
# 디스크 공간 정리 및 Maven 빌드 최적화 스크립트

echo "🧹 디스크 공간 정리 및 Maven 빌드 최적화"
echo "=========================================="

# 1. 현재 디스크 사용량 확인
echo ""
echo "📊 현재 디스크 사용량:"
df -h | head -1
df -h | grep -E "/$|/home|/var|/tmp" | head -5

echo ""
echo "💾 현재 디렉토리 크기:"
du -sh . 2>/dev/null || echo "현재 디렉토리 크기 확인 실패"

# 2. Maven 로컬 저장소 정리
echo ""
echo "📦 Maven 로컬 저장소 정리 중..."
MAVEN_REPO="$HOME/.m2/repository"
if [ -d "$MAVEN_REPO" ]; then
    REPO_SIZE_BEFORE=$(du -sh "$MAVEN_REPO" 2>/dev/null | cut -f1)
    echo "정리 전 Maven 저장소 크기: $REPO_SIZE_BEFORE"
    
    # Maven 캐시 정리 (오래된 SNAPSHOT 버전들 제거)
    find "$MAVEN_REPO" -name "*SNAPSHOT*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # 임시 파일들 정리
    find "$MAVEN_REPO" -name "*.tmp" -delete 2>/dev/null || true
    find "$MAVEN_REPO" -name "*.part" -delete 2>/dev/null || true
    find "$MAVEN_REPO" -name "*resolver-status.properties" -delete 2>/dev/null || true
    
    REPO_SIZE_AFTER=$(du -sh "$MAVEN_REPO" 2>/dev/null | cut -f1)
    echo "정리 후 Maven 저장소 크기: $REPO_SIZE_AFTER"
else
    echo "Maven 로컬 저장소를 찾을 수 없습니다: $MAVEN_REPO"
fi

# 3. 시스템 임시 파일 정리
echo ""
echo "🗑️ 시스템 임시 파일 정리 중..."
if [ -d "/tmp" ]; then
    # 오래된 임시 파일들 정리 (1일 이상된 파일들)
    find /tmp -type f -atime +1 -user "$(whoami)" -delete 2>/dev/null || true
    echo "✅ /tmp 디렉토리 정리 완료"
fi

# 사용자 임시 디렉토리 정리
if [ -d "$HOME/tmp" ]; then
    rm -rf "$HOME/tmp"/* 2>/dev/null || true
    echo "✅ 사용자 임시 디렉토리 정리 완료"
fi

# 4. Docker 시스템 정리
echo ""
echo "🐳 Docker 시스템 정리 중..."
if command -v docker >/dev/null 2>&1; then
    # 사용하지 않는 Docker 이미지, 컨테이너, 볼륨 정리
    docker system prune -f 2>/dev/null || echo "Docker system prune 실패 (권한 필요할 수 있음)"
    
    # 빌드 캐시 정리
    docker builder prune -f 2>/dev/null || echo "Docker builder prune 실패"
    
    echo "✅ Docker 시스템 정리 완료"
else
    echo "Docker가 설치되어 있지 않습니다"
fi

# 5. 프로젝트 빌드 아티팩트 정리
echo ""
echo "🏗️ 프로젝트 빌드 아티팩트 정리 중..."
if [ -d "backend/backend/target" ]; then
    TARGET_SIZE=$(du -sh "backend/backend/target" 2>/dev/null | cut -f1)
    echo "정리 전 target 디렉토리 크기: $TARGET_SIZE"
    rm -rf backend/backend/target
    echo "✅ backend/target 디렉토리 정리 완료"
fi

if [ -d "frontend/node_modules" ]; then
    NODE_MODULES_SIZE=$(du -sh "frontend/node_modules" 2>/dev/null | cut -f1)
    echo "Frontend node_modules 크기: $NODE_MODULES_SIZE"
    echo "⚠️ node_modules는 수동으로 정리하세요: rm -rf frontend/node_modules"
fi

if [ -d "frontend/build" ]; then
    rm -rf frontend/build
    echo "✅ frontend/build 디렉토리 정리 완료"
fi

# 6. 로그 파일 정리
echo ""
echo "📝 로그 파일 정리 중..."
find . -name "*.log" -size +10M -delete 2>/dev/null || true
find . -name "npm-debug.log*" -delete 2>/dev/null || true
find . -name "yarn-error.log*" -delete 2>/dev/null || true
echo "✅ 큰 로그 파일들 정리 완료"

# 7. 정리 후 디스크 사용량 재확인
echo ""
echo "📊 정리 후 디스크 사용량:"
df -h | head -1
df -h | grep -E "/$|/home|/var|/tmp" | head -5

# 8. 사용 가능한 공간 확인 및 권장사항
echo ""
echo "💡 빌드를 위한 권장사항:"
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [ $AVAILABLE_GB -lt 2 ]; then
    echo "⚠️ 사용 가능한 공간이 ${AVAILABLE_GB}GB로 부족합니다"
    echo "   추가 정리가 필요합니다:"
    echo "   - 불필요한 파일 삭제"
    echo "   - 다른 파티션 사용"
    echo "   - Maven 빌드 시 임시 디렉토리 지정"
elif [ $AVAILABLE_GB -lt 5 ]; then
    echo "⚠️ 사용 가능한 공간이 ${AVAILABLE_GB}GB로 제한적입니다"
    echo "   최소 빌드 옵션을 사용하세요"
else
    echo "✅ 사용 가능한 공간: ${AVAILABLE_GB}GB (충분함)"
fi

echo ""
echo "🎯 다음 단계:"
echo "1. ./build-backend-minimal.sh  # 최소 빌드 (권장)"
echo "2. ./build-backend-local.sh    # 일반 빌드"
echo "3. 수동 정리 후 재시도"