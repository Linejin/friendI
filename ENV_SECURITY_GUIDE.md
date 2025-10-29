# 🔐 환경변수 보안 가이드

## ⚠️ 중요: .env 파일 보안 관리

### 📋 파일별 Git 정책

| 파일 유형 | Git 포함 | 용도 | 민감정보 |
|-----------|----------|------|----------|
| `.env.example` | ✅ **포함** | 템플릿 | ❌ 없음 |
| `.env.development` | ⚠️ **조건부** | 개발 기본값 | ❌ 제거 필요 |
| `.env.production` | ⚠️ **조건부** | 운영 기본값 | ❌ 제거 필요 |
| `.env` | ❌ **제외** | 개인 로컬 | ✅ 포함 가능 |
| `.env.local` | ❌ **제외** | 로컬 오버라이드 | ✅ 포함 가능 |
| `.env.*.local` | ❌ **제외** | 환경별 로컬 | ✅ 포함 가능 |

## 🔒 민감정보 기준

### ❌ Git에 절대 올리면 안 되는 정보
- API 키: `API_KEY=`, `SECRET_KEY=`
- 비밀번호: `PASSWORD=`, `DB_PASSWORD=`
- JWT 시크릿: `JWT_SECRET=`
- 인증 토큰: `TOKEN=`, `ACCESS_TOKEN=`
- 개인 인증정보: 실제 이메일, 전화번호
- 운영 데이터베이스 접속정보
- 외부 서비스 인증 정보

### ✅ Git에 올려도 되는 정보
- 기본 포트 번호: `PORT=3000`
- 개발용 URL: `API_URL=http://localhost`
- 기능 플래그: `ENABLE_DEBUG=true`
- 로그 레벨: `LOG_LEVEL=INFO`
- 앱 이름/버전: `APP_NAME=FriendlyI`

## 🛠 올바른 설정 방법

### 1. 개발 환경 설정
```bash
# .env.development (Git 포함, 기본값만)
REACT_APP_API_BASE_URL=http://localhost:8080/api
REACT_APP_ENVIRONMENT=development
JWT_SECRET=please_set_in_local_env_file
ADMIN_PASSWORD=please_set_in_local_env_file

# .env.local (Git 제외, 실제 값)
JWT_SECRET=actual_development_secret_key_here
ADMIN_PASSWORD=dev123
```

### 2. 운영 환경 설정
```bash
# .env.production (Git 포함, 기본값만)
REACT_APP_API_BASE_URL=/api
REACT_APP_ENVIRONMENT=production
JWT_SECRET=please_set_in_production_env
DB_PASSWORD=please_set_in_production_env

# 운영 서버 환경변수 (Git 제외)
export JWT_SECRET="production_secret_key"
export DB_PASSWORD="secure_production_password"
```

## 🔄 마이그레이션 가이드

### 이미 민감정보가 Git에 있는 경우

#### 1단계: 즉시 파일 수정
```bash
# 민감정보를 placeholder로 교체
JWT_SECRET=actual_secret → JWT_SECRET=please_set_in_local_env_file
```

#### 2단계: 로컬 환경 파일 생성
```bash
# Frontend
cp .env.development .env.local
# 실제 값으로 수정

# Backend  
cp .env.development .env.local
# 실제 값으로 수정
```

#### 3단계: Git 히스토리에서 완전 제거 (필요시)
```bash
# ⚠️ 주의: 이 명령은 Git 히스토리를 변경합니다
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch .env.development' \
  --prune-empty --tag-name-filter cat -- --all

# 또는 최신 도구 사용
git filter-repo --invert-paths --path .env.development
```

## 🎯 현재 프로젝트 적용

### FriendlyI 프로젝트 현황
- ✅ `.env.example` 파일들: 안전 (템플릿만)
- ⚠️ `.env.development`: **수정 완료** (민감정보 제거)
- ✅ `.env.production`: 안전 (기본값만)
- ✅ `.gitignore`: 개인 환경 파일들 제외 설정

### 개발자 체크리스트
- [ ] `.env.local` 파일 생성 (Frontend)
- [ ] `.env.local` 파일 생성 (Backend)  
- [ ] 실제 JWT_SECRET 설정
- [ ] 실제 ADMIN_PASSWORD 설정
- [ ] 외부 API 키 설정 (필요시)

## 🚨 보안 점검

### 정기 검사 명령어
```bash
# 민감정보 패턴 검사
git ls-files | xargs grep -l "password\|secret\|key\|token" --ignore-case

# .env 파일 상태 확인
git ls-files | grep "\.env"

# 무시된 파일 확인
git status --ignored
```

### 자동화 도구
```bash
# git-check.bat 실행으로 종합 점검
git-check.bat
```

## 📚 참고 자료

- [12-Factor App: Config](https://12factor.net/config)
- [OWASP: Secrets Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)
- [GitHub: Removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)