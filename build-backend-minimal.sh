#!/bin/bash
# Backend 최소 빌드 스크립트 (디스크 공간 절약형)

echo "🔧 Backend 최소 빌드 (디스크 공간 절약형)"
echo "======================================="

# 현재 위치 저장
ORIGINAL_DIR=$(pwd)

# Backend 디렉토리 확인
if [ ! -f "backend/backend/pom.xml" ]; then
    echo "❌ backend/backend/pom.xml을 찾을 수 없습니다."
    exit 1
fi

cd backend/backend
echo "✅ Backend 디렉토리로 이동: $(pwd)"

# Maven wrapper 권한 확인
if [ ! -x "./mvnw" ]; then
    chmod +x ./mvnw
    echo "✅ mvnw 실행 권한 부여"
fi

# JAVA_HOME 설정
if [ -z "$JAVA_HOME" ]; then
    for java_path in \
        "/usr/lib/jvm/java-21-openjdk" \
        "/usr/lib/jvm/java-21-openjdk-amd64" \
        "/usr/lib/jvm/java-21-amazon-corretto" \
        "/opt/java/openjdk-21" \
        "/usr/java/jdk-21"
    do
        if [ -d "$java_path" ]; then
            export JAVA_HOME="$java_path"
            break
        fi
    done
fi

echo "JAVA_HOME: $JAVA_HOME"

# 1. 기존 target 디렉토리 정리
echo ""
echo "🧹 기존 빌드 아티팩트 정리..."
if [ -d "target" ]; then
    rm -rf target
    echo "✅ target 디렉토리 정리 완료"
fi

# 2. Maven 로컬 저장소를 임시 위치로 설정 (디스크 공간 절약)
TEMP_M2_REPO="/tmp/maven-repo-$$"
echo ""
echo "📦 임시 Maven 저장소 설정: $TEMP_M2_REPO"

# 3. 최소 빌드 실행 (테스트 스킵, 문서 생성 스킵, 소스 JAR 스킵)
echo ""
echo "🔨 최소 Maven 빌드 시작..."
echo "빌드 옵션: 테스트 스킵, 문서 스킵, 소스 JAR 스킵"

BUILD_CMD="./mvnw clean package \
    -DskipTests=true \
    -Dmaven.test.skip=true \
    -Dmaven.javadoc.skip=true \
    -Dmaven.source.skip=true \
    -Dmaven.install.skip=true \
    -Dmaven.deploy.skip=true \
    -Dmaven.site.skip=true \
    -Dmaven.compiler.fork=false \
    -Dmaven.repo.local=$TEMP_M2_REPO \
    --batch-mode \
    --no-transfer-progress"

echo "실행 명령: $BUILD_CMD"

if $BUILD_CMD; then
    echo "✅ Maven 빌드 성공!"
else
    echo "❌ Maven 빌드 실패"
    
    # 임시 Maven 저장소 정리
    rm -rf "$TEMP_M2_REPO" 2>/dev/null
    cd "$ORIGINAL_DIR"
    exit 1
fi

# 4. JAR 파일 확인 및 최적화
echo ""
echo "📋 생성된 JAR 파일 확인..."
JAR_FILE=$(find target -name "backend-*.jar" -type f | head -1)
if [ -f "$JAR_FILE" ]; then
    JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
    echo "✅ JAR 파일: $(basename "$JAR_FILE") (크기: $JAR_SIZE)"
    
    # JAR 파일을 루트로 복사 (Docker 빌드용)
    cp "$JAR_FILE" "../../$(basename "$JAR_FILE")"
    echo "✅ JAR 파일을 루트 디렉토리로 복사"
else
    echo "❌ JAR 파일을 찾을 수 없습니다"
    rm -rf "$TEMP_M2_REPO" 2>/dev/null
    cd "$ORIGINAL_DIR"
    exit 1
fi

# 5. 빌드 아티팩트 정리 (공간 절약)
echo ""
echo "🧹 빌드 후 정리..."
rm -rf target/classes
rm -rf target/generated-sources
rm -rf target/maven-archiver
rm -rf target/maven-status
echo "✅ 불필요한 빌드 아티팩트 정리 완료"

# 6. 임시 Maven 저장소 정리
rm -rf "$TEMP_M2_REPO" 2>/dev/null
echo "✅ 임시 Maven 저장소 정리 완료"

# 원래 위치로 복귀
cd "$ORIGINAL_DIR"

# 7. Docker 이미지 빌드 (최소 Dockerfile 사용)
echo ""
echo "🐳 최소 Docker 이미지 빌드..."

# 컨테이너 중지
docker-compose stop backend 2>/dev/null
docker-compose rm -f backend 2>/dev/null

# 최소 Dockerfile로 빌드
if [ -f "backend/backend/Dockerfile.minimal" ]; then
    # 임시로 Dockerfile 교체
    if [ -f "backend/backend/Dockerfile.backup" ]; then
        rm -f "backend/backend/Dockerfile.backup"
    fi
    mv "backend/backend/Dockerfile" "backend/backend/Dockerfile.backup"
    cp "backend/backend/Dockerfile.minimal" "backend/backend/Dockerfile"
    
    # Docker 빌드
    if docker-compose build --no-cache backend; then
        echo "✅ Docker 이미지 빌드 성공!"
    else
        echo "❌ Docker 이미지 빌드 실패"
    fi
    
    # Dockerfile 복원
    rm -f "backend/backend/Dockerfile"
    mv "backend/backend/Dockerfile.backup" "backend/backend/Dockerfile"
else
    echo "⚠️ Dockerfile.minimal이 없습니다. 일반 빌드를 사용합니다."
    docker-compose build --no-cache backend
fi

# 8. 루트의 JAR 파일 정리
rm -f backend-*.jar 2>/dev/null

echo ""
echo "🎉 최소 빌드 완료!"
echo ""
echo "📊 공간 절약 효과:"
echo "- 임시 Maven 저장소 사용으로 로컬 저장소 용량 절약"
echo "- 테스트, 문서, 소스 JAR 생성 스킵"
echo "- 빌드 후 불필요한 아티팩트 자동 정리"
echo "- 최소 Docker 이미지 사용"

echo ""
echo "🚀 다음 단계:"
echo "docker-compose up -d backend  # Backend 컨테이너 시작"