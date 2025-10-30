# Multi-stage build for optimized production image
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Install curl and tar for build utilities
RUN apk add --no-cache curl tar

# Copy Maven wrapper and pom.xml for dependency caching
COPY .mvn/ ./.mvn/
COPY mvnw ./
COPY mvnw.cmd ./
COPY pom.xml ./

# Make mvnw executable
RUN chmod +x ./mvnw

# Download dependencies (for better layer caching)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src/ ./src/

# Build the application (skip tests for faster build)
RUN ./mvnw clean package -DskipTests -B \
    -Dmaven.compile.fork=false \
    -Dmaven.test.skip=true

# Production stage
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Create app user for security
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Copy the JAR from builder stage
COPY --from=builder /app/target/backend-*.jar app.jar

# Create directories for uploads and logs
RUN mkdir -p /app/uploads /app/logs && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Expose port
EXPOSE 8080

# Environment variables with defaults (EC2 small optimized)
ENV SPRING_PROFILES_ACTIVE=prod
ENV SERVER_PORT=8080
ENV JAVA_OPTS="-Xms128m -Xmx512m -XX:+UseSerialGC -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]