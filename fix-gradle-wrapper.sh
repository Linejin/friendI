#!/bin/bash

# Gradle Wrapper 복구 스크립트
echo "=========================================="
echo "    Gradle Wrapper 복구 도구"
echo "=========================================="
echo ""

# 현재 디렉토리 확인
if [ ! -f "backend/backend/build.gradle" ]; then
    echo "❌ backend/backend/build.gradle 파일을 찾을 수 없습니다."
    echo "프로젝트 루트 디렉토리에서 실행하세요."
    exit 1
fi

cd backend/backend

echo "[1/4] 현재 Gradle Wrapper 상태 확인"
if [ -f "gradle/wrapper/gradle-wrapper.jar" ]; then
    echo "✓ gradle-wrapper.jar 존재"
    JAR_SIZE=$(ls -la gradle/wrapper/gradle-wrapper.jar | awk '{print $5}')
    echo "  파일 크기: $JAR_SIZE bytes"
    
    if [ "$JAR_SIZE" -lt 50000 ]; then
        echo "⚠️ JAR 파일이 너무 작습니다. 손상된 것 같습니다."
        NEED_DOWNLOAD=true
    else
        echo "✓ JAR 파일 크기 정상"
        NEED_DOWNLOAD=false
    fi
else
    echo "❌ gradle-wrapper.jar 없음"
    NEED_DOWNLOAD=true
fi

if [ -f "gradle/wrapper/gradle-wrapper.properties" ]; then
    echo "✓ gradle-wrapper.properties 존재"
    GRADLE_VERSION=$(grep "gradle-.*-bin.zip" gradle/wrapper/gradle-wrapper.properties | sed 's/.*gradle-\(.*\)-bin.zip.*/\1/')
    echo "  Gradle 버전: $GRADLE_VERSION"
else
    echo "❌ gradle-wrapper.properties 없음"
    GRADLE_VERSION="8.10.2"
    echo "  기본 버전으로 설정: $GRADLE_VERSION"
fi
echo ""

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "[2/4] Gradle Wrapper JAR 다운로드"
    
    # wrapper 디렉토리 생성
    mkdir -p gradle/wrapper
    
    # Gradle wrapper jar 직접 다운로드
    WRAPPER_URL="https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar"
    echo "다운로드 URL: $WRAPPER_URL"
    
    if command -v curl &> /dev/null; then
        echo "curl로 다운로드 중..."
        if curl -L -o gradle/wrapper/gradle-wrapper.jar "$WRAPPER_URL"; then
            echo "✓ curl 다운로드 성공"
        else
            echo "❌ curl 다운로드 실패"
            # 대안 URL로 시도
            echo "대안 URL로 시도 중..."
            WRAPPER_URL_ALT="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-wrapper-only.zip"
            if curl -L -o /tmp/gradle-wrapper.zip "$WRAPPER_URL_ALT"; then
                cd /tmp && unzip -q gradle-wrapper.zip && cd - > /dev/null
                cp /tmp/gradle/wrapper/gradle-wrapper.jar gradle/wrapper/
                rm -rf /tmp/gradle /tmp/gradle-wrapper.zip
                echo "✓ 대안 방법으로 다운로드 성공"
            else
                echo "❌ 대안 다운로드도 실패"
            fi
        fi
    elif command -v wget &> /dev/null; then
        echo "wget으로 다운로드 중..."
        if wget -O gradle/wrapper/gradle-wrapper.jar "$WRAPPER_URL"; then
            echo "✓ wget 다운로드 성공"
        else
            echo "❌ wget 다운로드 실패"
        fi
    else
        echo "❌ curl 또는 wget이 필요합니다."
        exit 1
    fi
    
    # 다운로드 확인
    if [ -f "gradle/wrapper/gradle-wrapper.jar" ]; then
        JAR_SIZE=$(ls -la gradle/wrapper/gradle-wrapper.jar | awk '{print $5}')
        echo "다운로드된 파일 크기: $JAR_SIZE bytes"
        
        if [ "$JAR_SIZE" -lt 50000 ]; then
            echo "❌ 다운로드된 파일이 손상되었습니다."
            exit 1
        else
            echo "✓ JAR 파일 다운로드 성공"
        fi
    else
        echo "❌ JAR 파일 다운로드 실패"
        exit 1
    fi
else
    echo "[2/4] Gradle Wrapper JAR 정상 - 건너뛰기"
fi
echo ""

echo "[3/4] Gradle Wrapper Properties 확인/생성"
cat > gradle/wrapper/gradle-wrapper.properties << EOF
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF
echo "✓ gradle-wrapper.properties 생성 완료"
echo ""

echo "[4/4] Gradle Wrapper 실행 테스트"
chmod +x gradlew

if [ -f gradlew ]; then
    echo "gradlew 실행 테스트 중..."
    if timeout 60 ./gradlew --version; then
        echo "✓ Gradle Wrapper 정상 동작"
    else
        echo "⚠️ Gradle Wrapper 실행 실패 또는 타임아웃"
        echo "하지만 JAR 파일은 복구되었으므로 Docker 빌드는 가능할 것입니다."
    fi
else
    echo "❌ gradlew 파일이 없습니다."
fi
echo ""

cd ../..

echo "=========================================="
echo "           복구 완료!"
echo "=========================================="
echo ""
echo "복구된 파일들:"
ls -la backend/backend/gradle/wrapper/
echo ""
echo "다음 단계:"
echo "1. Git에 추가: git add backend/backend/gradle/wrapper/gradle-wrapper.jar"
echo "2. 커밋: git commit -m 'Add missing gradle-wrapper.jar'"
echo "3. 푸시: git push"
echo "4. 배포 재시도: ./deploy-ec2.sh"
echo ""
echo "=========================================="