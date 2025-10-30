# Friendly I Backend Service

Spring Boot 기반의 백엔드 서비스입니다. 회원 관리, 예약 시스템, 인증/인가 기능을 제공합니다.

## 🏗️ 기술 스택

- **Java 21** - LTS 버전
- **Spring Boot 3.2.10** - 최신 Spring Framework
- **Spring Security** - 인증/인가 시스템
- **Spring Data JPA** - 데이터 접근 계층
- **PostgreSQL** - 메인 데이터베이스 (프로덕션)
- **H2 Database** - 개발/테스트용 인메모리 DB
- **Redis** - 캐시 및 세션 저장소
- **JWT** - 토큰 기반 인증
- **Swagger/OpenAPI 3** - API 문서화
- **Maven** - 빌드 도구
- **Docker & Docker Compose** - 컨테이너화

## 📋 필수 요구사항

### 로컬 개발
- Java 21 이상
- Maven 3.9+ (또는 프로젝트 내 Maven Wrapper 사용)
- Docker & Docker Compose (옵션)

### 프로덕션 배포
- Docker & Docker Compose
- PostgreSQL 15+
- Redis 7+

## 🚀 빠른 시작

### 1. 저장소 클론
```bash
git clone <repository-url>
cd backend
```

### 2. 로컬 개발 실행

#### Option A: H2 인메모리 DB 사용 (권장)
```bash
cd backend
./mvnw spring-boot:run
```
- 애플리케이션이 http://localhost:8080 에서 실행됩니다
- H2 콘솔: http://localhost:8080/h2-console
- Swagger UI: http://localhost:8080/swagger-ui/index.html

#### Option B: Docker Compose 개발 환경
```bash
# 개발용 환경 시작 (PostgreSQL + Redis 포함)
docker-compose -f docker-compose.dev.yml up -d

# 로그 확인
docker-compose -f docker-compose.dev.yml logs -f
```

### 3. 프로덕션 배포

#### 환경변수 설정
```bash
cp .env.example .env
# .env 파일을 편집하여 실제 값으로 변경
```

#### Docker Compose로 전체 스택 실행
```bash
docker-compose up -d
```

#### 서비스 상태 확인
```bash
# 모든 서비스 상태 확인
docker-compose ps

# 애플리케이션 로그 확인
docker-compose logs -f backend

# 헬스체크
curl http://localhost/actuator/health
```

## 🏃‍♂️ 실행 방법 상세

### Maven 명령어

```bash
# 의존성 다운로드
./mvnw dependency:resolve

# 컴파일
./mvnw compile

# 테스트 실행
./mvnw test

# 패키지 빌드 (테스트 포함)
./mvnw package

# 패키지 빌드 (테스트 스킵)
./mvnw package -DskipTests

# 애플리케이션 실행
./mvnw spring-boot:run

# 특정 프로파일로 실행
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

### JAR 실행

```bash
# 빌드 후 JAR 실행
java -jar target/backend-0.0.1-SNAPSHOT.jar

# 프로파일 지정
java -jar target/backend-0.0.1-SNAPSHOT.jar --spring.profiles.active=prod

# JVM 옵션과 함께 실행
java -Xms512m -Xmx1g -jar target/backend-0.0.1-SNAPSHOT.jar
```

## 🐳 Docker 사용법

### 이미지 빌드
```bash
cd backend
docker build -t friendly-i-backend .
```

### 단독 컨테이너 실행
```bash
docker run -d \
  --name friendly-i-backend \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=dev \
  friendly-i-backend
```

### Docker Compose 명령어

#### 개발 환경
```bash
# 시작
docker-compose -f docker-compose.dev.yml up -d

# 중지
docker-compose -f docker-compose.dev.yml down

# 로그 보기
docker-compose -f docker-compose.dev.yml logs -f backend-dev

# 볼륨까지 삭제
docker-compose -f docker-compose.dev.yml down -v
```

#### 프로덕션 환경
```bash
# 시작
docker-compose up -d

# 중지
docker-compose down

# 이미지 재빌드 후 시작
docker-compose up -d --build

# 특정 서비스만 재시작
docker-compose restart backend

# 볼륨과 네트워크까지 완전 삭제
docker-compose down -v --remove-orphans
```

## 📊 데이터베이스 설정

### 개발 환경 (H2)
```properties
# application-dev.properties
spring.datasource.url=jdbc:h2:mem:testdb
spring.h2.console.enabled=true
```
- H2 콘솔: http://localhost:8080/h2-console
- JDBC URL: `jdbc:h2:mem:testdb`
- Username: `sa`
- Password: (비어있음)

### 프로덕션 환경 (PostgreSQL)
```properties
# application-prod.properties
spring.datasource.url=jdbc:postgresql://postgres:5432/friendlyi
spring.datasource.username=friendlyi_user
spring.datasource.password=${DB_PASSWORD}
```

## 🔐 기본 계정 정보

애플리케이션 시작 시 자동으로 생성되는 계정들:

### 관리자 계정
- **로그인 ID**: `admin`
- **비밀번호**: `admin123`
- **권한**: ADMIN

### 샘플 사용자들
- **김테이 (user1)**: 비밀번호 `1234`
- **이데브 (user2)**: 비밀번호 `1234` 
- **최시니어 (user3)**: 비밀번호 `1234`

⚠️ **보안 주의**: 프로덕션에서는 반드시 기본 비밀번호를 변경하세요!

## 📡 API 문서

### Swagger UI
개발 환경에서 Swagger UI를 통해 API를 테스트할 수 있습니다:
- URL: http://localhost:8080/swagger-ui/index.html
- 프로덕션에서는 보안상 비활성화됩니다

### 주요 엔드포인트

```bash
# 헬스체크
GET /actuator/health

# 인증
POST /api/auth/login
POST /api/auth/register
POST /api/auth/refresh

# 회원 관리
GET    /api/members
POST   /api/members
GET    /api/members/{id}
PUT    /api/members/{id}
DELETE /api/members/{id}

# 예약 관리  
GET    /api/reservations
POST   /api/reservations
GET    /api/reservations/{id}
PUT    /api/reservations/{id}
DELETE /api/reservations/{id}

# 예약 신청
GET    /api/reservation-applications
POST   /api/reservation-applications
```

## 🌍 환경별 설정

### 프로파일별 설정 파일
- `application.properties` - 공통 설정
- `application-dev.properties` - 개발 환경
- `application-prod.properties` - 프로덕션 환경
- `application-test.properties` - 테스트 환경

### 환경변수
주요 환경변수들은 `.env.example` 파일을 참조하세요.

```bash
# 프로파일 설정
SPRING_PROFILES_ACTIVE=prod

# 데이터베이스
DB_HOST=localhost
DB_PORT=5432
DB_NAME=friendlyi
DB_USERNAME=friendlyi_user
DB_PASSWORD=your_password

# JWT 설정
JWT_SECRET=your-secret-key
JWT_EXPIRATION=86400000
```

## 🔧 개발 도구

### IDE 설정
프로젝트는 Maven 기반으로 구성되어 있어 IntelliJ IDEA, Eclipse, VS Code 등에서 바로 import 가능합니다.

#### IntelliJ IDEA
1. `File > Open` 선택
2. `backend/pom.xml` 파일 선택
3. "Open as Project" 클릭
4. Maven 프로젝트로 자동 인식

#### VS Code
1. Java Extension Pack 설치
2. 폴더 열기로 backend 디렉토리 선택
3. Java 프로젝트로 자동 인식

### 디버깅
```bash
# 디버그 모드로 실행 (포트 5005)
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"

# Docker 개발환경에서는 자동으로 5005 포트가 열려있음
docker-compose -f docker-compose.dev.yml up -d
```

## 🧪 테스트

### 단위 테스트 실행
```bash
./mvnw test
```

### 통합 테스트 실행
```bash
./mvnw verify
```

### 테스트 커버리지
```bash
./mvnw jacoco:report
# 리포트 위치: target/site/jacoco/index.html
```

## 📦 빌드 및 배포

### 로컬 빌드
```bash
# JAR 파일 생성
./mvnw package

# 생성된 파일 확인
ls -la target/*.jar
```

### Docker 이미지 빌드
```bash
# 멀티스테이지 빌드로 최적화된 이미지 생성
docker build -t friendly-i-backend:latest .

# 이미지 크기 확인
docker images friendly-i-backend:latest
```

### 프로덕션 배포 체크리스트

1. **환경변수 설정**
   - [ ] 데이터베이스 연결 정보
   - [ ] JWT 시크릿 키 (32자 이상)
   - [ ] 관리자 비밀번호
   - [ ] Redis 비밀번호

2. **보안 설정**
   - [ ] 기본 비밀번호 변경
   - [ ] HTTPS 인증서 설정
   - [ ] 방화벽 규칙 설정

3. **데이터베이스**
   - [ ] PostgreSQL 설치 및 설정
   - [ ] 백업 전략 수립
   - [ ] 연결 풀 설정 최적화

4. **모니터링**
   - [ ] 헬스체크 엔드포인트 확인
   - [ ] 로그 수집 시스템 설정
   - [ ] 메트릭 모니터링 설정

## 🔍 모니터링 및 로그

### Actuator 엔드포인트
```bash
# 애플리케이션 상태
curl http://localhost:8080/actuator/health

# 시스템 정보
curl http://localhost:8080/actuator/info

# 메트릭 (프로덕션)
curl http://localhost:8080/actuator/metrics
```

### 로그 레벨 설정
```properties
# 개발환경
logging.level.com.friendlyI.backend=DEBUG

# 프로덕션환경  
logging.level.com.friendlyI.backend=INFO
logging.level.org.springframework.security=WARN
```

### Docker 로그 확인
```bash
# 실시간 로그 확인
docker-compose logs -f backend

# 최근 100줄 로그
docker-compose logs --tail=100 backend

# 특정 시간대 로그
docker-compose logs --since="2023-01-01T00:00:00" backend
```

## 🏗️ EC2 Small Instance 배포 (2GB RAM 최적화)

EC2 t3.small 인스턴스 (2GB RAM, 2 vCPU)에 최적화된 설정을 제공합니다.

### 리소스 할당 계획
- **PostgreSQL**: 512MB (컨테이너 제한)
- **Redis**: 128MB (컨테이너 제한)
- **Backend**: 768MB (JVM 최대 448MB)
- **시스템 + 여유분**: 512MB

### EC2 Small 전용 명령어

```bash
# EC2 Small용 환경 설정
make small-setup

# EC2 Small 최적화 환경 시작
make small-up

# 리소스 모니터링
make small-monitor

# 시스템 설정 (EC2에서 실행)
./scripts/setup-ec2-small.sh

# 지속적 모니터링
watch -n 5 ./scripts/monitor-ec2-small.sh
```

### 최적화 특징
- **JVM**: SerialGC 사용으로 CPU 오버헤드 최소화
- **연결 풀**: PostgreSQL 연결 수 8개로 제한
- **Tomcat**: 최대 스레드 30개로 제한
- **캐시**: Redis 메모리 128MB로 제한
- **파일 업로드**: 3MB로 제한

### 성능 모니터링
```bash
# 컨테이너별 리소스 사용량
docker stats

# 상세 모니터링
./scripts/monitor-ec2-small.sh

# 시스템 부하 확인
htop
```

## 🚨 문제 해결

### 자주 발생하는 문제들

#### 1. 포트 충돌
```bash
# 8080 포트 사용 중인 프로세스 확인 (Windows)
netstat -ano | findstr :8080

# 프로세스 종료
taskkill /PID <PID> /F
```

#### 2. Docker 메모리 부족
```bash
# Docker 메모리 설정 확인
docker system info

# 불필요한 컨테이너/이미지 정리
docker system prune -a
```

#### 3. 데이터베이스 연결 실패
- 환경변수 설정 확인
- 네트워크 연결 상태 확인
- 데이터베이스 서비스 상태 확인

```bash
# PostgreSQL 연결 테스트
docker-compose exec postgres psql -U friendlyi_user -d friendlyi -c "SELECT 1;"
```

#### 4. Maven 빌드 실패
```bash
# 의존성 강제 업데이트
./mvnw dependency:purge-local-repository

# 클린 빌드
./mvnw clean compile
```

## 🤝 기여 가이드

1. Feature 브랜치 생성
2. 변경사항 구현
3. 테스트 작성 및 실행
4. Pull Request 생성

### 코드 스타일
- Java 코드는 Google Java Style Guide 준수
- 커밋 메시지는 Conventional Commits 형식 사용

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

---

## 📞 지원 및 문의

문제가 발생하거나 궁금한 점이 있으시면 이슈를 등록해 주세요.

**Happy Coding! 🚀**