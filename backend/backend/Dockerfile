# Backend Dockerfile - Maven with Java 21
FROM eclipse-temurin:21-jdk-alpine AS build

# Install required packages (Alpine Linux)
RUN apk add --no-cache curl unzip

# Set working directory
WORKDIR /app

# 빌드 환경 최적화 - Maven용 (빌드 args로 동적 설정)
ARG MAVEN_OPTS="-Xmx768m -XX:+UseSerialGC -XX:MaxRAMPercentage=75"
ENV MAVEN_OPTS=${MAVEN_OPTS}
ENV JAVA_TOOL_OPTIONS=${MAVEN_OPTS}

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

# Build the application with optimized settings and cleanup
RUN ./mvnw clean package -DskipTests \
    -B \
    -Dmaven.compile.fork=false \
    -Dmaven.test.skip=true && \
    rm -rf ~/.m2/repository && \
    rm -rf target/classes && \
    rm -rf target/test-classes && \
    rm -rf target/maven-*

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

# Run the application with Java 21 specific optimizations
ENTRYPOINT ["java", \
    "--enable-native-access=ALL-UNNAMED", \
    "-XX:+UseContainerSupport", \
    "-XX:+UnlockExperimentalVMOptions", \
    "-jar", "/app/app.jar"]