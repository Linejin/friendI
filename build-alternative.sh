#!/bin/bash

# EC2에서 Gradle 빌드 실패 시 대안 스크립트
# 호스트에서 빌드 후 Docker 이미지 생성

echo "=========================================="
echo "    Alternative Build for Low-Memory EC2"
echo "=========================================="
echo ""

# 현재 메모리 확인
echo "[메모리 상태 확인]"
free -h
echo ""

# 스왑 파일 생성 (메모리 부족 시)
if [ $(free | grep Swap | awk '{print $2}') -eq 0 ]; then
    echo "[스왑 파일 생성]"
    echo "메모리 부족으로 스왑 파일을 생성합니다..."
    
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # 영구 설정
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    fi
    
    echo "✓ 2GB 스왑 파일 생성 완료"
    free -h
    echo ""
fi

# 백엔드 빌드 시도
echo "[Backend 빌드 시도 1: 호스트에서 Gradle 빌드]"
cd backend/backend

# 로컬에 Java가 있는지 확인
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | grep -oP 'version "([0-9]+)' | cut -d'"' -f2)
    echo "Java 버전: $JAVA_VERSION"
    
    if [ "$JAVA_VERSION" -ge "11" ]; then
        echo "호스트에서 Gradle 빌드를 시도합니다..."
        
        # Gradle wrapper JAR 파일 확인
        if [ ! -f "gradle/wrapper/gradle-wrapper.jar" ]; then
            echo "❌ gradle-wrapper.jar 파일이 없습니다."
            echo "Gradle Wrapper를 복구합니다..."
            
            mkdir -p gradle/wrapper
            GRADLE_VERSION="8.10.2"
            WRAPPER_URL="https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar"
            
            if curl -L -o gradle/wrapper/gradle-wrapper.jar "$WRAPPER_URL" 2>/dev/null; then
                echo "✓ gradle-wrapper.jar 다운로드 완료"
            else
                echo "❌ gradle-wrapper.jar 다운로드 실패"
                echo "fix-gradle-wrapper.sh 스크립트를 실행하세요."
                cd ../..
                exit 1
            fi
        fi
        
        # Gradle wrapper 실행 권한 확인 및 부여
        if [ ! -x "./gradlew" ]; then
            echo "Gradle wrapper에 실행 권한을 부여합니다..."
            chmod +x ./gradlew
        fi
        
        # 메모리 제한된 환경에서 빌드
        export GRADLE_OPTS="-Dorg.gradle.daemon=false -Xmx1g -XX:+UseSerialGC"
        
        if ./gradlew clean build -x test --no-daemon --max-workers=1; then
            echo "✓ 호스트 빌드 성공!"
            
            # 빌드된 JAR 파일을 Docker 이미지에 직접 복사하는 간단한 Dockerfile 생성
            cat > Dockerfile.prebuilt << 'EOF'
FROM eclipse-temurin:21-jre-alpine

RUN apk add --no-cache curl
RUN addgroup -g 1000 app && adduser -D -u 1000 -G app app

WORKDIR /app
COPY build/libs/*.jar app.jar
RUN chown -R app:app /app
USER app

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
EOF
            
            echo "✓ 사전 빌드용 Dockerfile 생성 완료"
            cd ../..
            
            # Docker Compose 설정을 사전 빌드 버전으로 변경
            echo "[Docker Compose 사전 빌드 모드로 전환]"
            cp docker-compose.yml docker-compose.yml.backup
            
            sed 's/dockerfile: Dockerfile/dockerfile: Dockerfile.prebuilt/' docker-compose.yml > docker-compose.prebuilt.yml
            
            echo "✓ 사전 빌드 모드 설정 완료"
            echo ""
            echo "다음 명령어로 배포하세요:"
            echo "  docker-compose -f docker-compose.prebuilt.yml up --build -d"
            
            exit 0
        else
            echo "❌ 호스트 빌드 실패"
        fi
    else
        echo "⚠️ Java 11 이상이 필요합니다. 현재: $JAVA_VERSION"
    fi
else
    echo "⚠️ 호스트에 Java가 설치되어 있지 않습니다."
fi

cd ../..

echo ""
echo "[Backend 빌드 시도 2: Docker 멀티스테이지 최적화]"

# 메모리 최적화된 Dockerfile 생성
cat > backend/backend/Dockerfile.lowmem << 'EOF'
# 초저사양 EC2용 Dockerfile
FROM eclipse-temurin:21-jdk-alpine AS build

RUN apk add --no-cache curl

WORKDIR /app

# 매우 보수적인 메모리 설정
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=false -Xmx512m -XX:+UseSerialGC"
ENV JAVA_TOOL_OPTIONS="-Xmx512m -XX:+UseSerialGC"

COPY gradle/ ./gradle/
COPY gradlew ./
COPY gradle.properties ./
COPY build.gradle ./
COPY settings.gradle ./

# Make gradlew executable with verification
RUN chmod +x ./gradlew && ls -la ./gradlew

# 의존성을 먼저 해결 (실패해도 계속)
RUN timeout 300 ./gradlew dependencies --no-daemon || echo "Dependencies partially downloaded"

COPY src/ ./src/

# 매우 보수적인 빌드 (타임아웃 20분)
RUN timeout 1200 ./gradlew clean build -x test \
    --no-daemon \
    --no-parallel \
    --max-workers=1 \
    -Dorg.gradle.jvmargs="-Xmx512m -XX:+UseSerialGC" \
    --stacktrace \
    || (echo "Build failed, trying without clean..." && \
        timeout 1200 ./gradlew build -x test \
        --no-daemon \
        --no-parallel \
        --max-workers=1 \
        -Dorg.gradle.jvmargs="-Xmx512m -XX:+UseSerialGC")

FROM eclipse-temurin:21-jre-alpine

RUN apk add --no-cache curl
RUN addgroup -g 1000 app && adduser -D -u 1000 -G app app

WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
RUN chown -R app:app /app
USER app

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-Xmx256m", "-XX:+UseSerialGC", "-jar", "/app/app.jar"]
EOF

echo "✓ 저사양 EC2용 Dockerfile 생성 완료"
echo ""

# Docker Compose 저사양 버전 생성
cp docker-compose.yml docker-compose.yml.backup
sed 's/dockerfile: Dockerfile/dockerfile: Dockerfile.lowmem/' docker-compose.yml > docker-compose.lowmem.yml

echo "사용 가능한 빌드 옵션:"
echo "1. 사전 빌드 모드 (호스트 Java 필요):"
echo "   docker-compose -f docker-compose.prebuilt.yml up --build -d"
echo ""
echo "2. 저사양 최적화 모드:"
echo "   docker-compose -f docker-compose.lowmem.yml up --build -d"
echo ""
echo "3. 원본 모드 (메모리 충분한 경우):"
echo "   docker-compose up --build -d"
echo ""

echo "=========================================="
echo "권장사항:"
echo "- t3.micro (1GB RAM): 사전 빌드 모드 사용"
echo "- t3.small (2GB RAM): 저사양 최적화 모드 사용"  
echo "- t3.medium (4GB RAM) 이상: 원본 모드 사용"
echo "=========================================="