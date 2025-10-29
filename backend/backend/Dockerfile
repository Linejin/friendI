# Backend Dockerfile - Linux 배포 최적화
FROM eclipse-temurin:21-jdk-alpine AS build

# Install required packages (Alpine Linux)
RUN apk add --no-cache curl unzip

# Set working directory
WORKDIR /app

# Copy gradle wrapper and build files
COPY gradlew ./
COPY gradle/ ./gradle/
COPY build.gradle ./
COPY settings.gradle ./

# Make gradlew executable
RUN chmod +x ./gradlew

# Copy source code
COPY src/ ./src/

# Build the application
RUN ./gradlew clean build -x test --no-daemon

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