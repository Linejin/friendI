@echo off
echo ========================================
echo       Git 상태 및 .gitignore 확인
echo ========================================
echo.

echo [Git 저장소 정보]
git remote -v
echo.
git branch -a
echo.

echo [현재 Git 상태]
git status --short
echo.

echo [추적되지 않는 파일들 (gitignore 적용)]
git ls-files --others --ignored --exclude-standard
echo.

echo [.gitignore 파일들 확인]
if exist ".gitignore" (
    echo ✓ 루트 .gitignore 존재 (라인 수: 
    find /c /v "" .gitignore
    echo )
) else (
    echo ✗ 루트 .gitignore 없음
)

if exist "frontend\.gitignore" (
    echo ✓ Frontend .gitignore 존재 (라인 수:
    find /c /v "" frontend\.gitignore
    echo )
) else (
    echo ✗ Frontend .gitignore 없음
)

if exist "backend\backend\.gitignore" (
    echo ✓ Backend .gitignore 존재 (라인 수:
    find /c /v "" backend\backend\.gitignore
    echo )
) else (
    echo ✗ Backend .gitignore 없음
)

echo.
echo [민감정보 검사]
echo 다음 파일들이 추적되고 있다면 즉시 제거해야 합니다:

git ls-files | findstr /i "\.env$"
git ls-files | findstr /i "\.key$"
git ls-files | findstr /i "\.pem$"
git ls-files | findstr /i "password"
git ls-files | findstr /i "secret"

echo.
echo [대용량 파일 검사 (1MB 이상)]
git ls-files | xargs ls -la 2>nul | findstr /r "^.........." | findstr /v "^d"

echo.
echo ========================================
echo 검사 완료! 
echo 문제가 발견되면 GITIGNORE_GUIDE.md를 참조하세요.
echo ========================================
pause