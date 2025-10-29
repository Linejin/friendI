# .gitignore 관리 가이드

FriendlyI 프로젝트의 3단계 .gitignore 관리 시스템입니다.

## 📁 구조

```
d:\I\
├── .gitignore                    # 🌍 전체 프로젝트 공통
├── frontend/.gitignore           # ⚛️ Frontend (React) 전용
└── backend/backend/.gitignore    # ☕ Backend (Spring Boot) 전용
```

## 🎯 역할 분담

### 🌍 루트 .gitignore (전체 공통)
**책임**: 프로젝트 전체에 영향을 주는 파일들
- 환경 변수 및 민감정보
- Docker 설정 파일
- 데이터 및 업로드 파일
- 보안 인증서
- OS 생성 파일
- IDE 공통 설정
- 로그 파일

### ⚛️ Frontend .gitignore (React + TypeScript)
**책임**: 프론트엔드 개발 환경 특화
- Node.js 의존성 (node_modules)
- React 빌드 파일 (/build)
- TypeScript 캐시 (*.tsbuildinfo)
- 번들러 캐시 (.parcel-cache)
- 테스트 커버리지 (/coverage)
- ESLint 캐시 (.eslintcache)
- 프론트엔드 환경변수 (.env.local)

### ☕ Backend .gitignore (Spring Boot + Java)
**책임**: 백엔드 개발 환경 특화
- Gradle 빌드 파일 (build/, .gradle)
- Java 컴파일 파일 (*.class)
- IDE 프로젝트 파일 (.idea, .project)
- 데이터베이스 파일 (*.db, data/)
- Spring Boot 설정 (application-local.properties)
- JVM 덤프 파일 (hs_err_pid*)
- 테스트 결과 (TEST-*.xml)

## 🔄 우선순위 및 상속

Git은 다음 순서로 .gitignore를 적용합니다:

1. **Repository root** (`/.gitignore`) - 가장 높은 우선순위
2. **Subdirectory** (`/frontend/.gitignore`, `/backend/.gitignore`)
3. **Global gitignore** (사용자 전역 설정)

### 중복 처리 원칙
- 루트에서 제외된 파일은 하위에서 재정의 불가
- 하위 .gitignore는 해당 디렉토리 특화 파일만 처리
- 공통 파일은 루트에서만 정의

## 📝 사용 가이드

### 새로운 제외 파일 추가 시

#### 1. 어디에 추가할지 결정
```bash
# 전체 프로젝트에 영향 → 루트
echo "new-global-file.txt" >> .gitignore

# Frontend만 영향 → frontend/.gitignore  
echo "react-specific-file.js" >> frontend/.gitignore

# Backend만 영향 → backend/.gitignore
echo "spring-specific.properties" >> backend/backend/.gitignore
```

#### 2. 카테고리별 분류
각 .gitignore 파일에서 다음 카테고리로 분류:
- 🔐 보안 관련
- 📦 빌드/의존성
- 🛠 IDE/도구
- 🗑 임시/캐시
- 📊 테스트/분석

### 기존 제외 파일 수정

#### 파일이 이미 추적되고 있는 경우
```bash
# Git 추적 중지
git rm --cached filename

# .gitignore에 추가
echo "filename" >> .gitignore

# 커밋
git add .gitignore
git commit -m "Add filename to gitignore"
```

#### 디렉토리 전체 제외
```bash
# 디렉토리와 하위 모든 파일
directory/

# 특정 확장자만
*.log
*.tmp

# 특정 위치의 파일만
/root-only-file.txt
frontend/specific-file.js
```

## 🔍 검증 및 테스트

### 현재 제외 상태 확인
```bash
# 추적되지 않는 파일 확인
git status --ignored

# 특정 파일이 무시되는지 확인
git check-ignore -v filename

# .gitignore 패턴 테스트
git ls-files --others --ignored --exclude-standard
```

### 제외 패턴 디버깅
```bash
# 어떤 .gitignore 규칙이 적용되는지 확인
git check-ignore -v path/to/file

# 모든 무시된 파일 나열
find . -name .git -prune -o -type f -exec git check-ignore {} \; -print
```

## 🚨 주의사항

### ❌ 절대 커밋하지 말 것
- `.env` - 환경변수 (API 키, 비밀번호)
- `*.key`, `*.pem` - 보안 인증서
- `data/` - 데이터베이스 파일
- `uploads/` - 사용자 업로드 파일
- `*.log` - 로그 파일
- `node_modules/` - 의존성 패키지

### ✅ 반드시 커밋할 것
- `.env.example` - 환경변수 템플릿
- `gradle/wrapper/` - Gradle Wrapper
- `package.json` - 의존성 정의
- `*.md` - 문서 파일

### 🔄 정기 점검 항목
1. **월 1회**: 새로운 임시 파일 패턴 확인
2. **릴리즈 전**: 민감정보 누출 검사
3. **팀원 합류 시**: .gitignore 가이드 공유

## 📚 참고 자료

### 유용한 명령어
```bash
# 전체 .gitignore 효과 확인
git ls-files --others --ignored --exclude-standard

# 캐시 완전 초기화 (조심!)
git rm -r --cached .
git add .
git commit -m "Reset gitignore"

# 특정 파일 강제 추가 (gitignore 무시)
git add -f force-add-file.txt
```

### 온라인 도구
- [gitignore.io](https://gitignore.io) - 자동 .gitignore 생성
- [Git Documentation](https://git-scm.com/docs/gitignore) - 공식 문서

## 🔧 문제 해결

### 파일이 계속 추적되는 경우
```bash
# 1. Git 캐시에서 제거
git rm --cached problematic-file

# 2. .gitignore에 추가 확인
cat .gitignore | grep problematic-file

# 3. 커밋
git add .gitignore
git commit -m "Fix gitignore for problematic-file"
```

### .gitignore가 적용되지 않는 경우
```bash
# 1. 파일 경로 확인
git check-ignore -v problematic-file

# 2. 패턴 문법 확인
# 잘못된 예: /frontend*.js
# 올바른 예: /frontend/*.js

# 3. 캐시 초기화
git rm -r --cached .
git add .
```