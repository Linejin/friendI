#!/bin/bash
# Backend 로컬 빌드 후 Docker 배포 스크립트 (Linux/macOS)

# 옵션 파싱
SKIP_BUILD=false
USE_MINIMAL=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --no-minimal)
            USE_MINIMAL=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-build] [--no-minimal]"
            exit 1
            ;;
    esac
done

echo "🔧 Backend 로컬 빌드 후 Docker 배포"
echo "====================================="

# 현재 위치 저장
ORIGINAL_DIR=$(pwd)

# Backend 디렉토리 확인
if [ ! -f "backend/backend/pom.xml" ]; then
    echo "❌ backend/backend/pom.xml을 찾을 수 없습니다. 올바른 디렉토리에서 실행하세요."
    exit 1
fi

cd backend/backend
echo "✅ Backend 디렉토리로 이동: $(pwd)"

if [ "$SKIP_BUILD" = false ]; then
    # 1. 로컬에서 Maven 빌드
    echo ""
    echo "🔨 로컬 Maven 빌드 시작..."
    
    # JAVA_HOME 설정 (필요시 수정)
    if [ -z "$JAVA_HOME" ]; then
        # 일반적인 Java 21 경로들 시도
        for java_path in \
            "/usr/lib/jvm/java-21-openjdk" \
            "/usr/lib/jvm/java-21-openjdk-amd64" \
            "/opt/java/openjdk-21" \
            "/usr/java/jdk-21" \
            "/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home"
        do
            if [ -d "$java_path" ]; then
                export JAVA_HOME="$java_path"
                break
            fi
        done
    fi
    
    echo "JAVA_HOME: $JAVA_HOME"
    
    # Maven 빌드 실행
    echo "빌드 명령: ./mvnw clean package -DskipTests -Dmaven.test.skip=true --quiet"
    
    if ./mvnw clean package -DskipTests -Dmaven.test.skip=true --quiet; then
        echo "✅ 로컬 Maven 빌드 성공!"
    else
        echo "❌ 로컬 Maven 빌드 실패"
        cd "$ORIGINAL_DIR"
        exit 1
    fi

    # JAR 파일 확인
    JAR_FILE=$(find target -name "backend-*.jar" -type f | head -1)
    if [ -f "$JAR_FILE" ]; then
        JAR_SIZE=$(du -h "$JAR_FILE" | cut -f1)
        echo "✅ JAR 파일 생성됨: $(basename "$JAR_FILE") (크기: $JAR_SIZE)"
    else
        echo "❌ JAR 파일을 찾을 수 없습니다"
        cd "$ORIGINAL_DIR"
        exit 1
    fi
else
    echo "⏩ 빌드 건너뜀 (--skip-build 옵션)"
fi

# 2. Docker 이미지 빌드
echo ""
echo "🐳 Docker 이미지 빌드..."

# 루트 디렉토리로 돌아가기
cd "$ORIGINAL_DIR"

# 컨테이너 중지
echo "기존 Backend 컨테이너 중지 중..."
docker-compose stop backend 2>/dev/null
docker-compose rm -f backend 2>/dev/null

if [ "$USE_MINIMAL" = true ]; then
    # 최소 Dockerfile 사용
    echo "최소 Dockerfile 사용 중..."
    
    # 임시로 Dockerfile 교체
    if [ -f "backend/backend/Dockerfile.backup" ]; then
        rm -f "backend/backend/Dockerfile.backup"
    fi
    mv "backend/backend/Dockerfile" "backend/backend/Dockerfile.backup"
    cp "backend/backend/Dockerfile.minimal" "backend/backend/Dockerfile"
    
    # Docker 빌드
    if docker-compose build --no-cache backend; then
        echo "✅ Docker 이미지 빌드 성공!"
        BUILD_SUCCESS=true
    else
        echo "❌ Docker 이미지 빌드 실패"
        BUILD_SUCCESS=false
    fi
    
    # Dockerfile 복원
    rm -f "backend/backend/Dockerfile"
    mv "backend/backend/Dockerfile.backup" "backend/backend/Dockerfile"
    
    if [ "$BUILD_SUCCESS" = false ]; then
        exit 1
    fi
else
    # 기존 Dockerfile 사용
    if docker-compose build --no-cache backend; then
        echo "✅ Docker 이미지 빌드 성공!"
    else
        echo "❌ Docker 이미지 빌드 실패"
        exit 1
    fi
fi

# 3. 데이터베이스 확인 및 시작
echo ""
echo "💾 데이터베이스 상태 확인..."

DB_CONTAINERS=$(docker ps --filter "name=postgres" --filter "name=redis" --format "{{.Names}} {{.Status}}")
if [ -n "$DB_CONTAINERS" ]; then
    echo "데이터베이스 컨테이너: $DB_CONTAINERS"
else
    echo "데이터베이스 시작 중..."
    docker-compose up -d postgres redis 2>/dev/null
    sleep 15
fi

# 4. Backend 컨테이너 시작
echo ""
echo "🚀 Backend 컨테이너 시작..."
docker-compose up -d backend 2>/dev/null

# 5. 헬스체크 대기
echo ""
echo "⏳ Backend 헬스체크 대기..."
TIMEOUT=120
COUNTER=0
HEALTH_CHECK_PASSED=false

while [ $COUNTER -lt $TIMEOUT ] && [ "$HEALTH_CHECK_PASSED" = false ]; do
    if curl -s -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        HEALTH_CHECK_PASSED=true
        echo "✅ Backend 헬스체크 성공!"
        break
    fi
    
    COUNTER=$((COUNTER + 1))
    if [ $((COUNTER % 10)) -eq 0 ]; then
        echo "Backend 대기 중... ($COUNTER/$TIMEOUT)"
    fi
    sleep 2
done

if [ "$HEALTH_CHECK_PASSED" = false ]; then
    echo "⚠️ Backend 헬스체크 타임아웃"
    echo "Backend 로그:"
    docker-compose logs --tail=20 backend
fi

# 6. CORS 테스트
echo ""
echo "🌐 CORS 설정 테스트..."
if curl -s -X OPTIONS \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Content-Type" \
    http://localhost:8080/api/ | grep -q "Access-Control-Allow-Origin"; then
    echo "✅ CORS 설정이 올바르게 적용되었습니다"
else
    echo "⚠️ CORS 헤더 확인 필요"
fi

# 7. 최종 상태 확인
echo ""
echo "🎉 Backend 배포 완료!"
echo "======================"

echo ""
echo "📊 컨테이너 상태:"
docker-compose ps

echo ""
echo "🌐 접속 정보:"
echo "- Backend API: http://localhost:8080"
echo "- Health Check: http://localhost:8080/actuator/health"
echo "- Swagger UI: http://localhost:8080/swagger-ui/"

echo ""
echo "📋 디스크 사용량 최적화:"
echo "- 로컬 빌드로 Docker 빌드 디스크 사용량 최소화"
echo "- JRE만 포함된 최소 런타임 이미지 사용"
echo "- 빌드 캐시 및 임시 파일 정리"

echo ""
echo "🔧 유용한 명령어:"
echo "- 실시간 로그: docker-compose logs -f backend"
echo "- 컨테이너 재시작: docker-compose restart backend"
echo "- 헬스체크: curl http://localhost:8080/actuator/health"