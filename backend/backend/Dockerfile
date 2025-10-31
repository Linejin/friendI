# Multi-stage build optimized for disk space
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Install minimal build tools
RUN apk add --no-cache --virtual .build-deps curl

# Copy build files
COPY .mvn/ ./.mvn/
COPY mvnw pom.xml ./
RUN chmod +x ./mvnw

# Download dependencies with space optimization
RUN ./mvnw dependency:go-offline -B --quiet \
    && rm -rf ~/.m2/repository/org/springframework/boot/spring-boot-maven-plugin

# Copy and build with aggressive cleanup
COPY src/ ./src/
RUN ./mvnw clean package -DskipTests -B --quiet \
    -Dmaven.compile.fork=false \
    -Dmaven.test.skip=true \
    -Dmaven.repo.local=/tmp/.m2 \
    && rm -rf /tmp/.m2 \
    && rm -rf target/classes \
    && rm -rf target/generated-sources \
    && rm -rf target/maven-* \
    && apk del .build-deps

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