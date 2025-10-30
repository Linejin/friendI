# Backend Dockerfile - Maven with Java 21
FROM eclipse-temurin:21-jdk-alpine AS build

# Install required packages (Alpine Linux)
RUN apk add --no-cache curl unzip

# Set working directory
WORKDIR /app

# 빌드 환경 최적화 - Maven용
ENV MAVEN_OPTS="-Xmx1g -XX:+UseSerialGC"
ENV JAVA_TOOL_OPTIONS="-Xmx1g -XX:+UseSerialGC"

# Maven 캐시 최적화를 위한 단계별 복사
COPY .mvn/ ./.mvn/
COPY mvnw ./
COPY mvnw.cmd ./
COPY pom.xml ./

# Make mvnw executable and verify
RUN chmod +x ./mvnw && ls -la ./mvnw

# 의존성 다운로드 (소스코드 변경과 분리)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src/ ./src/

# Build the application with optimized settings
RUN ./mvnw clean package -DskipTests \
    -B \
    -Dmaven.compile.fork=false \
    -Dmaven.test.skip=true

# Production stage - 안정적인 JRE 이미지 사용
FROM eclipse-temurin:21-jre-alpine

# Install curl for health checks (Alpine Linux)
RUN apk add --no-cache curl

# Create app user (Alpine Linux 방식)
RUN addgroup -g 1000 app && adduser -D -u 1000 -G app app

# Set working directory
WORKDIR /app

# Copy jar file from build stage
COPY --from=build /app/target/*.jar app.jar

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