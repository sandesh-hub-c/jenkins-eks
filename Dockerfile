# ============================================================
# Multi-stage Dockerfile for Spring Boot Application
# Stage 1: Build the JAR using Maven
# Stage 2: Run the JAR using a lightweight JDK image
# ============================================================

# ---------- Stage 1: Build ----------
FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /app

# Copy POM first for dependency caching (Docker layer optimization)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests -B

# ---------- Stage 2: Run ----------
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy the built JAR from the builder stage
COPY --from=builder /app/target/devops-demo.jar app.jar

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Expose the application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
