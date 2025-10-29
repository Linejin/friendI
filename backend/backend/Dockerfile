# Backend Dockerfile - EC2 최적화 (메모리 효율성 개선)
FROM eclipse-temurin:21-jdk-alpine AS build

# Install required packages (Alpine Linux)
RUN apk add --no-cache curl unzip

# Set working directory
WORKDIR /app

# 빌드 환경 최적화
ENV GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=false -Dorg.gradle.workers.max=1 -Xmx1g -XX:+UseSerialGC"
ENV JAVA_TOOL_OPTIONS="-Xmx1g -XX:+UseSerialGC"

# Gradle 캐시 최적화를 위한 단계별 복사
COPY gradle/ ./gradle/
COPY gradlew ./
COPY gradle.properties* ./
COPY build.gradle ./
COPY settings.gradle ./

# Make gradlew executable and verify
RUN chmod +x ./gradlew && ls -la ./gradlew

# 의존성 다운로드 (소스코드 변경과 분리)
RUN ./gradlew dependencies --no-daemon || true

# Copy source code
COPY src/ ./src/

# Build the application with optimized settings
RUN ./gradlew clean build -x test \
    --no-daemon \
    --no-parallel \
    --max-workers=1 \
    -Dorg.gradle.jvmargs="-Xmx1g -XX:+UseSerialGC" \
    --info

# Production stage - 안정적인 JRE 이미지 사용
FROM eclipse-temurin:21-jre-alpine

# Install curl for health checks (Alpine Linux)
RUN apk add --no-cache curl

# Create app user (Alpine Linux 방식)
RUN addgroup -g 1000 app && adduser -D -u 1000 -G app app

# Set working directory
WORKDIR /app

# Copy jar file from build stage
COPY --from=build /app/build/libs/*.jar app.jar

# Change ownership to app user
RUN chown -R app:app /app
USER app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]