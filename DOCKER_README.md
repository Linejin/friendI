# FriendlyI - 예약 관리 시스템 🏢

Docker를 사용한 완전한 예약 관리 솔루션입니다. React + TypeScript 프론트엔드와 Spring Boot 백엔드로 구성된 현대적인 웹 애플리케이션입니다.

## 🎯 프로젝트 개요

FriendlyI는 기업이나 조직의 시설 예약을 효율적으로 관리할 수 있는 웹 애플리케이션입니다.

### 주요 기능
- 📅 **달력 기반 예약 시스템**: 직관적인 달력 인터페이스로 예약 현황 확인
- 👥 **사용자 관리**: 멤버 등록 및 권한 관리
- 📍 **장소 관리**: 다중 예약 공간 설정 및 관리
- 📊 **예약 현황 대시보드**: 실시간 예약 통계 및 현황 모니터링
- 🔐 **보안**: JWT 기반 인증 및 역할별 접근 제어
- 📱 **반응형 디자인**: 모바일, 태블릿, 데스크톱 지원

### 기술 스택
- **Frontend**: React 18, TypeScript, React Query, React Router
- **Backend**: Spring Boot 3, Java 21, Spring Security, JPA/Hibernate
- **Database**: H2 (개발), MySQL/PostgreSQL (운영 권장)
- **Containerization**: Docker, Docker Compose
- **UI/UX**: Modern CSS, Glassmorphism Design

## 📋 시스템 요구사항

### Docker 환경
- Docker Engine 20.10.0 이상
- Docker Compose 2.0.0 이상
- 최소 4GB RAM
- 최소 10GB 여유 디스크 공간

### 지원 OS
- Linux (Ubuntu 18.04+, CentOS 7+)
- macOS 10.14+
- Windows 10+ (Docker Desktop)

## 🚀 빠른 배포

### 1단계: 자동 배포 (권장)

#### Windows
```batch
start.bat
```

#### Linux/macOS
```bash
chmod +x start.sh
./start.sh
```

### 2단계: 수동 배포
```bash
# 1. 저장소 클론
git clone <repository-url>
cd FriendlyI

# 2. 환경 변수 설정 (선택사항)
cp docker-compose.override.yml.example docker-compose.override.yml
# docker-compose.override.yml 편집

# 3. 컨테이너 빌드 및 실행
docker-compose up --build -d

# 4. 상태 확인
docker-compose ps
```

### 3단계: 서비스 확인
```bash
# 헬스체크
curl http://localhost:8080/actuator/health

# 로그 확인
docker-compose logs -f
```

## � 서비스 접속

배포 완료 후 다음 URL에서 서비스에 접속할 수 있습니다:

| 서비스 | URL | 용도 | 상태 확인 |
|--------|-----|------|----------|
| **메인 애플리케이션** | http://localhost | 사용자 인터페이스 | ✅ 즉시 사용 가능 |
| **API 서버** | http://localhost:8080/api | REST API 엔드포인트 | ⚡ Backend 연동 |
| **서버 상태** | http://localhost:8080/actuator/health | 헬스체크 | 🔍 모니터링용 |
| **데이터베이스 관리** | http://localhost:8080/h2-console | DB 관리 도구 | 🛠 개발/디버깅용 |

### 기본 계정 정보
```
관리자 계정:
- Username: admin
- Password: admin123

데이터베이스 접속 (H2 Console):
- JDBC URL: jdbc:h2:file:/app/data/friendlyi
- Username: sa  
- Password: (비어있음)
```

## 🔧 고급 설정

### 개발 모드 (디버깅 포함)
```bash
# 개발용 구성으로 실행 (디버그 포트 5005 포함)
docker-compose -f docker-compose.dev.yml up --build -d

# 디버거 연결
# IDE에서 localhost:5005로 Remote Debug 연결
```

### 환경별 배포
```bash
# 운영 환경
docker-compose -f docker-compose.yml up --build -d

# 개발 환경  
docker-compose -f docker-compose.dev.yml up --build -d

# 사용자 정의 환경
docker-compose -f docker-compose.yml -f docker-compose.override.yml up --build -d
```

## 🛠 운영 및 관리

### 서비스 관리
```bash
# 전체 상태 확인
docker-compose ps

# 실시간 로그 모니터링
docker-compose logs -f

# 특정 서비스 로그만 확인
docker-compose logs -f backend    # 백엔드 로그
docker-compose logs -f frontend   # 프론트엔드 로그

# 서비스 재시작 (무중단)
docker-compose restart backend
docker-compose restart frontend

# 서비스 중지
docker-compose stop

# 완전 종료 (컨테이너 삭제)
docker-compose down
```

### 컨테이너 접근 및 디버깅
```bash
# Backend 컨테이너 내부 접근
docker-compose exec backend bash

# Frontend 컨테이너 내부 접근 (Nginx)
docker-compose exec frontend sh

# 컨테이너 리소스 사용량 확인
docker stats

# 특정 컨테이너 상세 정보
docker inspect friendlyi-backend
docker inspect friendlyi-frontend
```

### 데이터 관리
```bash
# 데이터 백업 (볼륨 백업)
docker run --rm -v friendlyi_backend_data:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz /data

# 데이터 복원
docker run --rm -v friendlyi_backend_data:/data -v $(pwd):/backup alpine tar xzf /backup/backup.tar.gz -C /

# 데이터베이스 파일 확인
docker-compose exec backend ls -la /app/data/
```

### 이미지 및 정리
```bash
# 이미지 강제 재빌드
docker-compose build --no-cache --pull

# 미사용 이미지 정리
docker image prune -f

# 미사용 볼륨 정리  
docker volume prune -f

# 전체 시스템 정리 (⚠️ 주의: 모든 데이터 삭제)
docker-compose down -v --remove-orphans
docker system prune -af --volumes
```

### 성능 모니터링
```bash
# 컨테이너 리소스 실시간 모니터링
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# 디스크 사용량 확인
docker system df

# 네트워크 상태 확인
docker network ls
docker network inspect friendlyi-network
```

## 📁 Docker 배포 구조

```
FriendlyI/
├── 🐳 Docker 설정
│   ├── docker-compose.yml              # 운영 환경 구성
│   ├── docker-compose.dev.yml          # 개발 환경 구성  
│   ├── docker-compose.override.yml.example  # 로컬 설정 템플릿
│   ├── start.bat / start.sh             # 원클릭 배포 스크립트
│   └── .env 관련 파일들                  # 환경 변수 관리
│
├── 🎨 Frontend (React + TypeScript)
│   ├── Dockerfile                       # 멀티스테이지 React 빌드
│   ├── nginx.conf                       # Nginx 웹서버 + API 프록시
│   ├── .dockerignore                    # 빌드 최적화
│   ├── src/                            # React 소스코드
│   │   ├── components/                  # 재사용 가능한 컴포넌트
│   │   ├── pages/                      # 페이지 컴포넌트
│   │   ├── api/                        # API 클라이언트
│   │   └── styles/                     # CSS 및 스타일링
│   └── package.json                    # 의존성 및 스크립트
│
├── ⚙️ Backend (Spring Boot + Java 21)
│   └── backend/
│       ├── Dockerfile                   # OpenJDK 기반 Spring Boot
│       ├── .dockerignore               # 빌드 최적화
│       ├── build.gradle                # Gradle 빌드 설정
│       └── src/main/
│           ├── java/com/friendlyI/backend/
│           │   ├── controller/         # REST API 컨트롤러
│           │   ├── service/           # 비즈니스 로직
│           │   ├── repository/        # 데이터 액세스 레이어
│           │   ├── entity/           # JPA 엔티티
│           │   └── config/           # 설정 클래스
│           └── resources/
│               ├── application*.properties  # 환경별 설정
│               └── static/           # 정적 리소스
│
└── 📚 문서 및 가이드
    ├── DOCKER_README.md               # Docker 배포 가이드 (현재 파일)
    ├── DEVELOPMENT_GUIDE.md           # 로컬 개발 가이드
    ├── ENVIRONMENT_SETUP.md           # 환경 변수 설정 가이드
    └── API 문서                       # Swagger/OpenAPI 문서
```

### 컨테이너 아키텍처
```
┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │
│   (Nginx)       │────│  (Spring Boot)  │
│   Port: 80      │    │   Port: 8080    │
└─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         └──────────────│   Shared Net    │
                        │ friendlyi-net   │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │  Persistent     │
                        │  Volume         │
                        │ (Database)      │
                        └─────────────────┘
```

## ⚙️ 환경 설정 및 커스터마이징

### 포트 설정 변경
운영 환경에 맞게 포트를 변경할 수 있습니다:

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  frontend:
    ports:
      - "8080:80"      # HTTP 웹서버
      - "8443:443"     # HTTPS (SSL 설정 시)
  
  backend:
    ports:
      - "9090:8080"    # API 서버
      - "5005:5005"    # 원격 디버깅 (개발용)
```

### 환경 변수 커스터마이징
```yaml
# docker-compose.override.yml  
services:
  backend:
    environment:
      - SPRING_PROFILES_ACTIVE=prod,custom
      - SERVER_PORT=8080
      - JWT_SECRET=your-production-secret-here
      - DB_URL=jdbc:postgresql://your-db-server:5432/friendlyi
      - DB_USERNAME=friendlyi_user
      - DB_PASSWORD=secure_password
      
  frontend:
    environment:
      - REACT_APP_API_BASE_URL=https://api.yourdomain.com
      - REACT_APP_ENVIRONMENT=production
```

### 데이터 지속성 및 백업
```yaml
# 외부 볼륨 마운트로 데이터 보호
volumes:
  backend_data:
    driver: local
    driver_opts:
      o: bind
      type: none
      device: /opt/friendlyi/data  # 호스트 경로
```

### SSL/HTTPS 설정 (운영 권장)
```yaml
# docker-compose.prod.yml
services:
  frontend:
    volumes:
      - ./ssl/nginx-ssl.conf:/etc/nginx/nginx.conf:ro
      - ./ssl/certificates:/etc/ssl/certificates:ro
    ports:
      - "443:443"
      - "80:80"
```

## 🚨 문제 해결 가이드

### 🔧 일반적인 문제들

#### 1. 포트 충돌 해결
```bash
# Windows
netstat -ano | findstr :80
netstat -ano | findstr :8080
taskkill /PID [PID] /F

# Linux/macOS  
sudo lsof -i :80
sudo lsof -i :8080
sudo kill -9 [PID]

# Docker에서 다른 포트 사용
docker-compose down
# docker-compose.yml에서 포트 변경 후
docker-compose up -d
```

#### 2. 컨테이너 시작 실패
```bash
# 단계별 진단
docker-compose ps                    # 컨테이너 상태 확인
docker-compose logs backend         # 백엔드 로그 확인
docker-compose logs frontend        # 프론트엔드 로그 확인

# 상세 진단
docker inspect friendlyi-backend    # 컨테이너 상세 정보
docker inspect friendlyi-frontend

# 헬스체크 상태
docker-compose exec backend curl -f http://localhost:8080/actuator/health
```

#### 3. 네트워크 연결 문제
```bash
# 네트워크 진단
docker network ls
docker network inspect friendlyi-network

# 컨테이너 간 통신 테스트
docker-compose exec frontend ping backend
docker-compose exec backend ping frontend

# DNS 해결 테스트
docker-compose exec frontend nslookup backend
```

#### 4. 메모리/성능 문제
```bash
# 리소스 사용량 확인
docker stats --no-stream

# 메모리 부족 시 Docker Desktop 설정에서 메모리 증가
# 또는 docker-compose.yml에서 메모리 제한 설정
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### 🔄 복구 절차

#### 완전 초기화 (데이터 손실 주의!)
```bash
# 1단계: 모든 컨테이너 중지 및 삭제
docker-compose down -v --remove-orphans

# 2단계: 이미지 삭제 (선택사항)
docker rmi $(docker images -q "friendlyi*")

# 3단계: 시스템 정리
docker system prune -f

# 4단계: 새로 시작
docker-compose up --build -d
```

#### 데이터 보존 복구
```bash
# 컨테이너만 재생성 (볼륨 보존)
docker-compose down
docker-compose up --build -d

# 특정 서비스만 재시작
docker-compose restart backend
docker-compose restart frontend
```

### 📊 모니터링 및 로그

#### 실시간 모니터링
```bash
# 통합 로그 모니터링
docker-compose logs -f --tail=50

# 에러만 필터링
docker-compose logs -f | grep -i error

# 특정 시간대 로그
docker-compose logs --since="2023-01-01T10:00:00" --until="2023-01-01T11:00:00"
```

#### 성능 모니터링
```bash
# 실시간 성능 지표
watch -n 2 'docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"'

# 디스크 사용량
docker system df -v
```

### 🛡️ 보안 점검

#### 컨테이너 보안 스캔
```bash
# 이미지 취약점 스캔 (Docker Desktop Pro)
docker scan friendlyi-backend:latest
docker scan friendlyi-frontend:latest

# 실행 중인 컨테이너 보안 점검
docker-compose exec backend ps aux
docker-compose exec frontend ps aux
```

### 📞 지원 및 문의

문제가 지속되는 경우:
1. **로그 수집**: `docker-compose logs > debug.log`
2. **시스템 정보**: `docker version && docker-compose version`
3. **환경 정보**: OS, Docker Desktop 버전, 할당된 리소스
4. **재현 단계**: 문제 발생까지의 정확한 단계

이 정보와 함께 GitHub Issues 또는 기술 지원팀에 문의해주세요.

## � 업데이트 및 배포 절차

### 애플리케이션 업데이트
```bash
# 1. 소스코드 업데이트
git pull origin main

# 2. 컨테이너 재빌드 및 배포
docker-compose up --build -d

# 3. 헬스체크 확인
curl http://localhost:8080/actuator/health
```

### 롤링 업데이트 (무중단 배포)
```bash
# 백엔드 먼저 업데이트
docker-compose up --build -d --no-deps backend
sleep 30  # 헬스체크 대기

# 프론트엔드 업데이트
docker-compose up --build -d --no-deps frontend

# 전체 상태 확인
docker-compose ps
```

### 특정 서비스만 업데이트
```bash
# 백엔드만 재빌드
docker-compose build --no-cache backend
docker-compose up -d backend

# 프론트엔드만 재빌드  
docker-compose build --no-cache frontend
docker-compose up -d frontend
```

## 🏗️ 운영 환경 권장사항

### 프로덕션 배포 체크리스트
- [ ] **환경 변수**: 운영용 시크릿 키 설정
- [ ] **HTTPS**: SSL 인증서 적용
- [ ] **데이터베이스**: 외부 DB 서버 연결 (MySQL/PostgreSQL)
- [ ] **모니터링**: 로그 수집 및 알림 설정
- [ ] **백업**: 데이터 자동 백업 스케줄 설정
- [ ] **방화벽**: 불필요한 포트 차단
- [ ] **리소스**: CPU/Memory 리밋 설정

### 성능 최적화
```yaml
# docker-compose.prod.yml 예시
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'  
          memory: 1G
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        
  frontend:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### 모니터링 및 로깅
```yaml
# 로그 로테이션 설정
services:
  backend:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
```

## 📚 기술 스택 상세정보

### 🎨 Frontend Stack
- **React 18**: 최신 React with Concurrent Features
- **TypeScript 4.9**: 타입 안정성 및 개발자 경험
- **React Query 3**: 서버 상태 관리 및 캐싱
- **React Router 6**: SPA 라우팅
- **Styled Components**: CSS-in-JS 스타일링
- **React Hook Form + Yup**: 폼 관리 및 검증
- **React Big Calendar**: 달력 컴포넌트
- **Axios**: HTTP 클라이언트

### ⚙️ Backend Stack  
- **Spring Boot 3.2**: 최신 Spring Framework
- **Java 21**: LTS 버전의 최신 Java
- **Spring Security**: 인증 및 권한 관리
- **Spring Data JPA**: 데이터 액세스 추상화
- **Hibernate**: ORM 및 데이터베이스 매핑
- **H2 Database**: 개발용 인메모리 DB
- **Gradle**: 빌드 도구 및 의존성 관리
- **Swagger/OpenAPI**: API 문서화

### 🐳 Infrastructure
- **Docker Engine**: 컨테이너화
- **Docker Compose**: 멀티 컨테이너 오케스트레이션  
- **Nginx**: 웹서버 및 리버스 프록시
- **Alpine Linux**: 경량 베이스 이미지

## 📄 라이선스 및 저작권

이 프로젝트는 [라이선스 명시] 하에 배포됩니다. 자세한 내용은 LICENSE 파일을 참조하세요.

---

## 📞 지원 및 기여

### 기술 지원
- 📧 이메일: [지원 이메일]
- 🐛 버그 리포트: GitHub Issues
- 💬 커뮤니티: [커뮤니티 링크]

### 기여하기
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

**🚀 FriendlyI와 함께 효율적인 예약 관리를 시작하세요!**

> ⭐ 이 프로젝트가 도움이 되셨다면 GitHub에서 Star를 눌러주세요!