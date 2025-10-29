#!/bin/bash

# Gradle wrapper 권한 수정 스크립트
echo "=========================================="
echo "    Gradle Wrapper 권한 수정"
echo "=========================================="
echo ""

# Backend gradlew 권한 확인 및 수정
if [ -f "backend/backend/gradlew" ]; then
    echo "[Backend Gradle Wrapper 확인]"
    
    CURRENT_PERMS=$(ls -la backend/backend/gradlew | cut -d' ' -f1)
    echo "현재 권한: $CURRENT_PERMS"
    
    if [ ! -x "backend/backend/gradlew" ]; then
        echo "실행 권한이 없습니다. 권한을 부여합니다..."
        chmod +x backend/backend/gradlew
        echo "✓ 실행 권한 부여 완료"
    else
        echo "✓ 실행 권한이 이미 있습니다"
    fi
    
    # 권한 확인
    NEW_PERMS=$(ls -la backend/backend/gradlew | cut -d' ' -f1)
    echo "수정된 권한: $NEW_PERMS"
else
    echo "❌ backend/backend/gradlew 파일을 찾을 수 없습니다"
fi

echo ""

# Git에서 파일 모드 설정 확인
echo "[Git 파일 모드 설정 확인]"
GIT_FILEMODE=$(git config core.filemode)
echo "Git filemode: $GIT_FILEMODE"

if [ "$GIT_FILEMODE" != "true" ]; then
    echo "Git에서 파일 권한을 추적하지 않도록 설정되어 있습니다."
    echo "권한 문제 해결을 위해 filemode를 활성화합니다..."
    git config core.filemode true
    echo "✓ Git filemode 활성화 완료"
fi

echo ""

# gradlew 파일을 Git에 올바른 권한으로 추가
echo "[Git에 올바른 권한으로 추가]"
if [ -f "backend/backend/gradlew" ]; then
    git add backend/backend/gradlew
    
    # Git에서 파일 권한 확인
    GIT_PERMS=$(git ls-files --stage backend/backend/gradlew | cut -d' ' -f1)
    echo "Git 저장 권한: $GIT_PERMS"
    
    if [ "$GIT_PERMS" = "100644" ]; then
        echo "⚠️ Git에 실행 권한 없이 저장되어 있습니다. 수정합니다..."
        git update-index --chmod=+x backend/backend/gradlew
        echo "✓ Git 실행 권한 설정 완료"
    else
        echo "✓ Git에 올바른 실행 권한으로 저장되어 있습니다"
    fi
fi

echo ""

# 다른 스크립트 파일들도 확인
echo "[기타 실행 파일 권한 확인]"
SCRIPTS=("setup-ec2.sh" "deploy-ec2.sh" "build-alternative.sh" "git-check.bat")

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            echo "권한 부여: $script"
            chmod +x "$script"
        else
            echo "✓ $script"
        fi
    fi
done

echo ""
echo "=========================================="
echo "권한 수정 완료!"
echo ""
echo "이제 다음 명령으로 재시도하세요:"
echo "./build-alternative.sh"
echo "또는"
echo "./deploy-ec2.sh"
echo "=========================================="