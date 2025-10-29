# Environment Configuration Guide

이 문서는 FriendlyI 프로젝트의 환경 설정 관리 방법을 설명합니다.

## 📋 파일 구조

```
├── .gitignore                          # 루트 레벨 Git 제외 파일
├── docker-compose.override.yml.example # Docker 로컬 개발 설정 예제
├── frontend/
│   ├── .env.example                   # Frontend 환경변수 템플릿
│   ├── .env.development               # 개발 환경 설정 (Git 포함)
│   ├── .env.production                # 운영 환경 설정 (Git 포함)
│   └── .gitignore                     # Frontend Git 제외 파일
└── backend/backend/
    ├── .env.example                   # Backend 환경변수 템플릿
    ├── .env.development               # 개발 환경 설정 (Git 포함)
    ├── .env.production                # 운영 환경 설정 (Git 포함)
    └── .gitignore                     # Backend Git 제외 파일
```

## 🔐 Git에 포함되는 파일 vs 제외되는 파일

### ✅ Git에 포함 (공유)
- `.env.example` - 환경변수 템플릿
- `.env.development` - 개발 환경 기본값
- `.env.production` - 운영 환경 기본값
- `.gitignore` - Git 제외 설정

### ❌ Git에서 제외 (개인/민감정보)
- `.env` - 개인 로컬 설정
- `.env.local` - 로컬 오버라이드
- `.env.*.local` - 환경별 로컬 오버라이드
- `docker-compose.override.yml` - Docker 로컬 설정

## 🚀 설정 방법

### 1. 초기 설정

#### Frontend
```bash
cd frontend
cp .env.example .env.local
# .env.local 파일을 편집하여 개인 설정 추가
```

#### Backend
```bash
cd backend/backend
cp .env.example .env
# .env 파일을 편집하여 개인 설정 추가
```

### 2. Docker 로컬 개발
```bash
cp docker-compose.override.yml.example docker-compose.override.yml
# docker-compose.override.yml 파일을 편집하여 로컬 설정 추가
```

## 🔧 환경변수 우선순위

### Frontend (React)
1. `.env.local` (최고 우선순위)
2. `.env.development` / `.env.production`
3. `.env`
4. 기본값

### Backend (Spring Boot)
1. 시스템 환경변수
2. `.env` 파일
3. `application-{profile}.properties`
4. `application.properties`

## 📝 주요 환경변수

### Frontend
```bash
# API 설정
REACT_APP_API_BASE_URL=http://localhost:8080/api
REACT_APP_API_TIMEOUT=10000

# 기능 플래그
REACT_APP_ENABLE_DEBUG=true
REACT_APP_ENABLE_ANALYTICS=false

# 외부 서비스
REACT_APP_GOOGLE_MAPS_API_KEY=your_api_key
```

### Backend
```bash
# 서버 설정
SERVER_PORT=8080
SERVER_ADDRESS=0.0.0.0

# 데이터베이스
DB_URL=jdbc:h2:file:./data/friendlyi
DB_USERNAME=sa
DB_PASSWORD=

# 보안
JWT_SECRET=your_secure_jwt_secret
ADMIN_USERNAME=admin
ADMIN_PASSWORD=secure_password

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000
```

## 🛡️ 보안 고려사항

### 절대 Git에 커밋하지 말 것
- API 키와 시크릿
- 데이터베이스 비밀번호
- JWT 비밀키
- 개인 인증 정보
- 운영 환경 설정

### 안전한 관리 방법
- `.env.example` 파일로 필요한 변수 문서화
- 민감한 정보는 `.env.local` 파일에만 저장
- 운영 환경에서는 환경변수나 시크릿 관리 도구 사용
- 정기적으로 시크릿 키 갱신

## 📚 환경별 설정 가이드

### 개발 환경
```bash
# Frontend
REACT_APP_API_BASE_URL=http://localhost:8080/api
REACT_APP_ENVIRONMENT=development
REACT_APP_ENABLE_DEBUG=true

# Backend
SPRING_PROFILES_ACTIVE=dev
LOG_LEVEL=DEBUG
JPA_SHOW_SQL=true
```

### 운영 환경
```bash
# Frontend
REACT_APP_API_BASE_URL=/api
REACT_APP_ENVIRONMENT=production
REACT_APP_ENABLE_DEBUG=false

# Backend
SPRING_PROFILES_ACTIVE=prod
LOG_LEVEL=INFO
JPA_SHOW_SQL=false
JPA_HIBERNATE_DDL_AUTO=validate
```

### Docker 환경
```bash
# Backend
SPRING_PROFILES_ACTIVE=docker
DB_URL=jdbc:h2:file:/app/data/friendlyi
```

## 🔄 설정 변경 시 주의사항

1. **개발팀 공유 설정**
   - `.env.development`, `.env.production` 파일 수정
   - 변경사항을 팀과 공유

2. **개인 설정**
   - `.env.local`, `.env` 파일 수정
   - Git에 커밋하지 않음

3. **Docker 설정**
   - `docker-compose.override.yml` 수정
   - 컨테이너 재시작 필요

## 🧪 환경변수 테스트

### Frontend에서 확인
```javascript
console.log('API Base URL:', process.env.REACT_APP_API_BASE_URL);
console.log('Environment:', process.env.REACT_APP_ENVIRONMENT);
```

### Backend에서 확인
```java
@Value("${SERVER_PORT:8080}")
private String serverPort;

@Value("${SPRING_PROFILES_ACTIVE:dev}")
private String activeProfile;
```

## 🚨 문제 해결

### 환경변수가 적용되지 않을 때
1. 파일명 확인 (`.env.local`, `.env`)
2. 변수명 확인 (`REACT_APP_` 접두사 필수 for React)
3. 애플리케이션 재시작
4. Docker 사용 시 컨테이너 재빌드

### Git에 민감정보가 커밋된 경우
```bash
# 파일을 Git 히스토리에서 완전히 제거
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch .env' \
  --prune-empty --tag-name-filter cat -- --all

# 또는 최신 방법
git filter-repo --invert-paths --path .env
```