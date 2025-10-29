# FriendlyI 개발 환경 가이드

개발 중에는 Docker 대신 직접 실행하여 빠른 개발과 디버깅을 할 수 있습니다.

## 🚀 빠른 시작

### 1. 초기 설정 (최초 1회만)
```bash
# Windows
dev-setup.bat

# 또는 수동으로:
cd frontend
copy .env.example .env.local
npm install

cd ../backend/backend
copy .env.example .env
```

### 2. 개발 서버 실행

#### 전체 실행 (추천)
```bash
# Windows
dev-start.bat

# Linux/Mac
chmod +x dev-start.sh
./dev-start.sh
```

#### 개별 실행
```bash
# Backend만 (Windows)
backend-start.bat

# Frontend만 (Windows)  
frontend-start.bat

# Linux/Mac
cd backend/backend && ./gradlew bootRun
cd frontend && npm start
```

## 📡 개발 서버 URL

| 서비스 | URL | 포트 |
|--------|-----|------|
| Frontend | http://localhost:3000 | 3000 |
| Backend API | http://localhost:8080 | 8080 |
| Backend Health | http://localhost:8080/actuator/health | 8080 |

## 🛠 개발 도구

### 환경 설정 확인
```bash
# Windows
dev-check.bat
```

### 로그 확인
- **Frontend**: 브라우저 개발자 도구 콘솔
- **Backend**: 터미널/CMD 창에서 실시간 로그 확인

### 핫 리로드
- **Frontend**: 파일 저장 시 자동 리로드
- **Backend**: Spring Boot DevTools로 자동 재시작

## 📁 개발 환경 구조

```
d:\I\
├── dev-start.bat           # 전체 개발 서버 시작
├── dev-setup.bat           # 초기 환경 설정
├── dev-check.bat           # 환경 설정 확인
├── backend-start.bat       # Backend만 시작
├── frontend-start.bat      # Frontend만 시작
├── frontend/
│   ├── .env.local          # 개인 환경 설정
│   ├── .env.development    # 개발 환경 기본값
│   └── package.json
└── backend/backend/
    ├── .env                # 개인 환경 설정
    ├── .env.development    # 개발 환경 기본값
    └── build.gradle
```

## ⚙️ 환경 설정

### Frontend (.env.local)
```bash
REACT_APP_API_BASE_URL=http://localhost:8080/api
REACT_APP_ENVIRONMENT=development
REACT_APP_ENABLE_DEBUG=true
```

### Backend (.env)
```bash
SERVER_PORT=8080
SPRING_PROFILES_ACTIVE=dev
LOG_LEVEL=DEBUG
JPA_SHOW_SQL=true
```

## 🔧 개발 팁

### 1. 빠른 재시작
- **Frontend**: `Ctrl+C` 후 `npm start`
- **Backend**: `Ctrl+C` 후 `./gradlew bootRun`

### 2. 포트 변경
- Frontend: `.env.local`에서 `PORT=3001` 추가
- Backend: `.env`에서 `SERVER_PORT=8081` 변경

### 3. API 테스트
```bash
# Health Check
curl http://localhost:8080/actuator/health

# API 테스트 (예시)
curl http://localhost:8080/api/reservations
```

### 4. 데이터베이스 확인
- H2 Console: http://localhost:8080/h2-console
- JDBC URL: `jdbc:h2:file:./data/friendlyi-dev`

## 🚨 문제 해결

### 포트 충돌
```bash
# Windows에서 포트 사용 확인
netstat -ano | findstr :3000
netstat -ano | findstr :8080

# 프로세스 종료
taskkill /PID [PID번호] /F
```

### 의존성 오류
```bash
# Frontend
cd frontend
rm -rf node_modules package-lock.json
npm install

# Backend
cd backend/backend
./gradlew clean build
```

### 환경변수 적용 안됨
1. 서버 재시작
2. .env 파일 경로 확인
3. 변수명 확인 (React: `REACT_APP_` 접두사 필요)

## 🔄 개발 워크플로우

1. **코드 변경**
2. **자동 리로드 확인** (Frontend)
3. **Backend 재시작** (필요시)
4. **브라우저에서 테스트**
5. **API 테스트** (필요시)
6. **Git 커밋**

## 📦 배포는 언제?

개발이 완료되면 Docker를 사용하여 배포:

```bash
# 배포용 (Docker)
docker-compose up --build -d

# 개발용 (직접 실행)
dev-start.bat
```

**개발 중에는 Docker 없이 직접 실행하는 것이 더 빠르고 편리합니다!** 🚀