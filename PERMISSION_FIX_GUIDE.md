# Linux 파일 권한 문제 해결 가이드

## 🚨 문제 상황
```
./build-alternative.sh: line 51: ./gradlew: Permission denied
```

## 🔧 즉시 해결 방법

### 1단계: 권한 수정 스크립트 실행
```bash
chmod +x fix-permissions.sh
./fix-permissions.sh
```

### 2단계: 수동 권한 부여 (필요시)
```bash
# Gradle wrapper 권한 부여
chmod +x backend/backend/gradlew

# 모든 스크립트 권한 부여
chmod +x *.sh

# Git에 권한 정보 업데이트
git update-index --chmod=+x backend/backend/gradlew
git update-index --chmod=+x *.sh
```

### 3단계: 다시 실행
```bash
./build-alternative.sh
# 또는
./deploy-ec2.sh
```

## 🔍 문제 원인 분석

### Windows → Linux 권한 문제
- Windows에서 작업한 파일을 Linux로 가져올 때 실행 권한 손실
- Git의 `core.filemode` 설정에 따른 권한 무시
- 파일 시스템 간 권한 매핑 문제

### Git 권한 관리
```bash
# 현재 Git 파일 모드 설정 확인
git config core.filemode

# 파일 모드 활성화 (권한 추적)
git config core.filemode true

# 특정 파일 권한 확인
git ls-files --stage backend/backend/gradlew

# 권한 업데이트
git update-index --chmod=+x backend/backend/gradlew
```

## 🛠 예방 방법

### .gitattributes 설정
프로젝트에 `.gitattributes` 파일이 추가되어 파일별 처리 방식을 정의:

```gitattributes
# Gradle wrapper는 항상 실행 권한 유지
**/gradlew text eol=lf

# Shell 스크립트들은 LF 라인 엔딩 사용
*.sh text eol=lf
```

### 자동 권한 체크
배포 스크립트에 권한 확인 로직 추가:
```bash
# deploy-ec2.sh에서 자동으로 권한 확인 및 수정
if [ ! -x "backend/backend/gradlew" ]; then
    chmod +x backend/backend/gradlew
fi
```

## 🔄 완전 해결 절차

### 개발자 (Windows)
```bash
# 1. 권한 설정 후 커밋
git update-index --chmod=+x backend/backend/gradlew
git update-index --chmod=+x *.sh
git add .gitattributes
git commit -m "Fix file permissions for Linux deployment"
git push

# 2. 팀원들에게 안내
echo "Linux 배포 시 권한 문제 해결됨. git pull 후 사용"
```

### 서버 관리자 (Linux)
```bash
# 1. 최신 코드 받기
git pull origin master

# 2. 권한 확인 및 수정
./fix-permissions.sh

# 3. 배포
./deploy-ec2.sh
```

## 📋 권한 확인 체크리스트

### 실행 전 확인사항
- [ ] `ls -la backend/backend/gradlew` 에서 `x` 권한 있는지 확인
- [ ] `ls -la *.sh` 에서 모든 스크립트 `x` 권한 확인
- [ ] `git config core.filemode` 가 `true` 인지 확인

### 문제 발생 시 진단
```bash
# 파일 권한 상세 확인
ls -la backend/backend/gradlew

# Git 저장 권한 확인
git ls-files --stage backend/backend/gradlew

# 실행 테스트
backend/backend/gradlew --version
```

### 예상 출력값
```bash
# 올바른 권한 (실행 가능)
-rwxr-xr-x 1 user user 5764 Oct 29 12:00 gradlew

# 잘못된 권한 (실행 불가)  
-rw-r--r-- 1 user user 5764 Oct 29 12:00 gradlew
```

## 🔧 고급 문제 해결

### Docker 빌드 중 권한 문제
```dockerfile
# Dockerfile에서 명시적 권한 부여
COPY gradlew ./
RUN chmod +x ./gradlew && ls -la ./gradlew
```

### 지속적인 권한 문제 (극단적 해결책)
```bash
# Git에서 권한 추적 비활성화 (권장하지 않음)
git config core.filemode false

# 빌드 전 항상 권한 부여하는 스크립트 생성
echo '#!/bin/bash
find . -name "gradlew" -exec chmod +x {} \;
find . -name "*.sh" -exec chmod +x {} \;' > fix-all-permissions.sh

chmod +x fix-all-permissions.sh
```

## 📞 추가 지원

### 로그 수집
```bash
# 권한 문제 진단 정보 수집
echo "=== File Permissions ===" > permission-debug.log
ls -la backend/backend/gradlew >> permission-debug.log
ls -la *.sh >> permission-debug.log

echo "=== Git Config ===" >> permission-debug.log
git config --list | grep filemode >> permission-debug.log

echo "=== Git File Mode ===" >> permission-debug.log  
git ls-files --stage | grep -E "(gradlew|\.sh)" >> permission-debug.log
```

이 정보를 가지고 GitHub Issues나 기술 지원에 문의하세요.