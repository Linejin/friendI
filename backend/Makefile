# Makefile for Friendly I Backend
.PHONY: help build run test clean docker-build docker-run docker-dev docker-prod logs

# Default target
help: ## Show this help message
	@echo "Friendly I Backend - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

# Local Development
build: ## Build the application with Maven
	cd backend && ./mvnw clean package -DskipTests

build-with-tests: ## Build the application with tests
	cd backend && ./mvnw clean package

run: ## Run the application locally
	cd backend && ./mvnw spring-boot:run

run-dev: ## Run the application with dev profile
	cd backend && ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

run-prod: ## Run the application with prod profile
	cd backend && ./mvnw spring-boot:run -Dspring-boot.run.profiles=prod

test: ## Run tests
	cd backend && ./mvnw test

test-coverage: ## Run tests with coverage report
	cd backend && ./mvnw jacoco:report

clean: ## Clean build artifacts
	cd backend && ./mvnw clean

# Docker Development
docker-build: ## Build Docker image
	cd backend && docker build -t friendly-i-backend:latest .

docker-run: ## Run Docker container (standalone)
	docker run -d \
		--name friendly-i-backend \
		-p 8080:8080 \
		-e SPRING_PROFILES_ACTIVE=dev \
		friendly-i-backend:latest

docker-stop: ## Stop and remove Docker container
	docker stop friendly-i-backend || true
	docker rm friendly-i-backend || true

# Docker Compose
dev-up: ## Start development environment (PostgreSQL + Redis + Backend)
	docker-compose -f docker-compose.dev.yml up -d

dev-down: ## Stop development environment
	docker-compose -f docker-compose.dev.yml down

dev-logs: ## Show development logs
	docker-compose -f docker-compose.dev.yml logs -f

dev-rebuild: ## Rebuild and restart development environment
	docker-compose -f docker-compose.dev.yml down
	docker-compose -f docker-compose.dev.yml up -d --build

# Production
prod-up: ## Start production environment
	docker-compose up -d

prod-down: ## Stop production environment
	docker-compose down

prod-logs: ## Show production logs
	docker-compose logs -f

prod-rebuild: ## Rebuild and restart production environment
	docker-compose down
	docker-compose up -d --build

# EC2 Small Instance (2GB RAM)
small-up: ## Start EC2 small optimized environment
	docker-compose -f docker-compose.small.yml up -d

small-down: ## Stop EC2 small environment
	docker-compose -f docker-compose.small.yml down

small-logs: ## Show EC2 small environment logs
	docker-compose -f docker-compose.small.yml logs -f

small-rebuild: ## Rebuild and restart EC2 small environment
	docker-compose -f docker-compose.small.yml down
	docker-compose -f docker-compose.small.yml up -d --build

small-setup: ## Setup environment for EC2 small
	cp .env.small .env
	@echo "Environment configured for EC2 small instance (2GB RAM)"

small-monitor: ## Monitor resource usage on small instance
	docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Database
db-init: ## Initialize database with sample data
	cd backend && ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

db-backup: ## Backup production database
	docker-compose exec postgres pg_dump -U friendlyi_user friendlyi > backup_$$(date +%Y%m%d_%H%M%S).sql

db-restore: ## Restore database from backup (usage: make db-restore BACKUP_FILE=backup.sql)
	docker-compose exec -T postgres psql -U friendlyi_user -d friendlyi < $(BACKUP_FILE)

# Monitoring
logs: ## Show application logs
	docker-compose logs -f backend

logs-db: ## Show database logs
	docker-compose logs -f postgres

logs-redis: ## Show Redis logs
	docker-compose logs -f redis

health: ## Check application health
	curl -s http://localhost:8080/actuator/health | jq .

status: ## Show all services status
	docker-compose ps

# Maintenance
cleanup: ## Clean up Docker resources
	docker system prune -f
	docker volume prune -f

reset-dev: ## Reset development environment (remove volumes)
	docker-compose -f docker-compose.dev.yml down -v
	docker-compose -f docker-compose.dev.yml up -d

reset-prod: ## Reset production environment (remove volumes)
	docker-compose down -v
	docker-compose up -d

# Utilities
shell-backend: ## Access backend container shell
	docker-compose exec backend sh

shell-db: ## Access database container shell
	docker-compose exec postgres psql -U friendlyi_user -d friendlyi

shell-redis: ## Access Redis container shell
	docker-compose exec redis redis-cli

# Development helpers
debug: ## Run application in debug mode (port 5005)
	cd backend && ./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"

format: ## Format code (if formatter is configured)
	cd backend && ./mvnw spotless:apply

lint: ## Run code quality checks
	cd backend && ./mvnw spotbugs:check

# Environment setup
setup-env: ## Copy environment template
	cp .env.example .env
	@echo "Please edit .env file with your actual values"

# Quick shortcuts
up: dev-up ## Alias for dev-up
down: dev-down ## Alias for dev-down
rebuild: dev-rebuild ## Alias for dev-rebuild