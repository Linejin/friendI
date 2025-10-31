# FriendlyI 프로젝트 🐤

> EC2 t3.small 최적화된 Spring Boot + React 풀스택 애플리케이션

Spring Boot 백엔드와 React 프론트엔드로 구성된 예약 관리 시스템입니다.

## 🏗️ 프로젝트 구조

```
├── backend/backend/           # Spring Boot 백엔드 (Maven)
│   ├── src/                   # Java 소스 코드
│   ├── pom.xml               # Maven 설정 (Gradle에서 전환)
│   └── Dockerfile            # 백엔드 Docker 이미지
├── frontend/                 # React 프론트엔드
│   ├── src/                  # React 소스 코드
│   ├── package.json         # npm 설정
│   ├── nginx.conf           # nginx 설정
│   └── Dockerfile           # 프론트엔드 Docker 이미지
├── docker-compose.yml       # 메인 Docker Compose 설정
└── 배포 스크립트들/
    ├── deploy-initial.sh         # 초기 배포 (DB 데이터 보존)
    ├── redeploy-zero-downtime.sh # 무중단 재배포
    ├── monitor-ec2.sh           # EC2 리소스 모니터링
    ├── cleanup-resources.sh     # 시스템 리소스 정리
    └── setup-permissions.sh     # 스크립트 권한 설정
```

## 🛠️ 기술 스택

### Backend
- **Java 21** + **Spring Boot 3.2.10**
- **Maven 3.9.6** (Gradle에서 완전 전환)
- **PostgreSQL 15** (포트 5433)
- **Redis 7** (포트 6379)
- **Spring Security** + **JWT**
- **Spring Boot Actuator** (헬스체크)

### Frontend
- **React 18** + **TypeScript**
- **Nginx** (리버스 프록시)

### DevOps
- **Docker** + **Docker Compose**
- **Alpine Linux** 기반 경량 이미지
- **EC2 t3.small** 최적화 (2GB RAM, 2 vCPU)

## 기능

### 🏆 회원 등급 시스템
- 🥚 알 (EGG) - 기본 등급
- 🐣 부화중 (HATCHING)
- 🐥 병아리 (CHICK)
- 🐤 어린새 (YOUNG_BIRD)
- 🐔 관리자 (ROOSTER)

### 📋 주요 기능
1. **회원 관리**: 회원 등록, 조회, 등급 관리
2. **예약 관리**: 달력 기반 예약 생성, 수정, 삭제
   - 📅 **달력 인터페이스**: 직관적인 달력 UI로 예약 관리
   - 🖱️ **클릭으로 예약 생성**: 달력의 빈 시간대 클릭으로 즉시 예약 생성
   - 👀 **예약 현황 시각화**: 예약 상태를 색상으로 구분 (가능/마감)
   - 📱 **반응형 달력**: 월/주/일 단위 보기 전환 가능
3. **신청 관리**: 예약 신청, 승인, 대기열 관리

## 🚀 배포 가이드

### 1. 첫 배포 (Linux)
```bash
./setup-permissions.sh      # 실행 권한 부여
./deploy-initial.sh         # 초기 배포 (DB 데이터 보존)
```

### 2. 코드 업데이트
```bash
./redeploy-zero-downtime.sh  # 무중단 재배포
```

### 3. 상태 모니터링
```bash
./monitor-ec2.sh            # 리소스 및 서비스 상태 확인
```

### 4. 개발 환경 (로컬)

#### Backend 개발
```bash
cd backend/backend
./mvnw spring-boot:run      # Maven 사용
```

#### Frontend 개발
```bash
cd frontend
npm install
npm start
```

## 🌐 서비스 접근

| 서비스 | URL | 설명 |
|--------|-----|------|
| Frontend | http://localhost:3000 | React 앱 |
| Backend API | http://localhost:8080 | REST API |
| Health Check | http://localhost:8080/actuator/health | 서비스 상태 |
| Swagger UI | http://localhost:8080/swagger-ui/ | API 문서 |
| PostgreSQL | localhost:5433 | 데이터베이스 |
| Redis | localhost:6379 | 캐시 서버 |

## 📊 EC2 t3.small 최적화

### 배포 방식 비교

| 구분 | 초기 배포 | 무중단 재배포 |
|------|-----------|---------------|
| **PostgreSQL 데이터** | ✅ 보존 | ✅ 보존 |
| **Redis 데이터** | ✅ 보존 | ✅ 보존 |
| **애플리케이션** | 🔄 재생성 | 🔄 Blue-Green 교체 |
| **다운타임** | ⚠️ 앱만 중단 | ✅ 무중단 |
| **사용 시기** | 첫 배포, 문제 해결 | 일반 업데이트 |

### 메모리 최적화 설정
```bash
# Node.js 메모리 제한
NODE_OPTIONS="--max-old-space-size=1024"

# Java JVM 최적화
JAVA_OPTS="-Xms256m -Xmx1024m -XX:+UseSerialGC -XX:MaxRAMPercentage=50.0"

# Maven 빌드 최적화
MAVEN_OPTS="-Xmx512m -XX:+UseSerialGC"
```

### 데이터베이스 최적화
- **PostgreSQL**: shared_buffers=64MB, max_connections=50
- **Redis**: maxmemory=128mb, LRU 정책

## 🧹 프로젝트 정리 내역

### 제거된 파일들
- ❌ **25개+ 중복 배포 스크립트** (build-*, deploy-*, fix-*, 등)
- ❌ **Gradle 관련 파일** 완전 제거 (Maven 전용)
- ❌ **중복 Docker Compose** 파일들
- ❌ **중복 Dockerfile** 파일들
- ❌ **빌드 아티팩트** (target/, build/, node_modules/)

### 유지된 핵심 파일들
- ✅ **5개 핵심 스크립트**만 유지
- ✅ **단일 docker-compose.yml**
- ✅ **최적화된 Dockerfile** 각 1개씩
- ✅ **Maven pom.xml** (Gradle 완전 제거)

## 🔧 유지보수

### 정기 정리
```bash
./cleanup-resources.sh      # 주간 실행 권장
```

### 로그 확인
```bash
docker-compose logs -f backend
docker-compose logs -f frontend
```

### 데이터베이스 백업
```bash
# PostgreSQL 백업
docker exec friendi-postgres pg_dump -U friendlyi_user friendlyi > backup.sql

# Redis 백업 (자동 RDB 저장됨)
docker exec friendi-redis redis-cli BGSAVE
```

## 📈 성능 최적화

- **메모리 사용량**: < 1.5GB (t3.small 2GB 중)
- **빌드 시간**: 초기 ~3분, 무중단 ~1분
- **이미지 크기**: Backend ~200MB, Frontend ~50MB
- **시작 시간**: Backend ~30초, Frontend ~10초

## 🎯 배포 모범 사례

1. **개발 → 테스트 → 배포** 순서 준수
2. **무중단 재배포** 우선 사용
3. **정기적 리소스 정리** (주 1회)
4. **모니터링** 지속 확인
5. **백업** 중요 데이터 보존

---

> **Note**: 이 프로젝트는 EC2 t3.small 환경에 최적화되어 있으며, 더 큰 인스턴스에서는 메모리 제한을 조정할 수 있습니다.