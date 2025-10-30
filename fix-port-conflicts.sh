#!/bin/bash
# 포트 충돌 자동 해결 스크립트

# 포트 사용 가능 여부 확인
check_port() {
    local port=$1
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        return 1  # 포트 사용 중
    else
        return 0  # 포트 사용 가능
    fi
}

# 사용 가능한 포트 찾기
find_available_port() {
    local base_port=$1
    local current_port=$base_port
    
    while [ $current_port -lt $((base_port + 100)) ]; do
        if check_port $current_port; then
            echo $current_port
            return 0
        fi
        current_port=$((current_port + 1))
    done
    
    echo $base_port  # 기본값 반환
}

# 환경 변수 파일 업데이트
update_env_file() {
    local key=$1
    local value=$2
    local env_file=${3:-.env}
    
    if grep -q "^$key=" "$env_file" 2>/dev/null; then
        sed -i "s/^$key=.*/$key=$value/" "$env_file"
    else
        echo "$key=$value" >> "$env_file"
    fi
}

echo "🔍 포트 충돌 검사 및 자동 해결 중..."

# PostgreSQL 포트 확인
if ! check_port 5432; then
    NEW_POSTGRES_PORT=$(find_available_port 5433)
    echo "PostgreSQL 포트 5432 사용 중 → $NEW_POSTGRES_PORT 포트로 변경"
    update_env_file "POSTGRES_PORT" "$NEW_POSTGRES_PORT"
else
    echo "PostgreSQL 포트 5432 사용 가능"
    update_env_file "POSTGRES_PORT" "5432"
fi

# Backend 포트 확인
if ! check_port 8080; then
    NEW_BACKEND_PORT=$(find_available_port 8081)
    echo "Backend 포트 8080 사용 중 → $NEW_BACKEND_PORT 포트로 변경"
    update_env_file "BACKEND_PORT" "$NEW_BACKEND_PORT"
else
    echo "Backend 포트 8080 사용 가능"
    update_env_file "BACKEND_PORT" "8080"
fi

# Frontend 포트 확인
if ! check_port 80; then
    NEW_FRONTEND_PORT=$(find_available_port 3000)
    echo "Frontend 포트 80 사용 중 → $NEW_FRONTEND_PORT 포트로 변경"
    update_env_file "FRONTEND_HTTP_PORT" "$NEW_FRONTEND_PORT"
else
    echo "Frontend 포트 80 사용 가능"
    update_env_file "FRONTEND_HTTP_PORT" "80"
fi

# Redis 포트 확인
if ! check_port 6379; then
    NEW_REDIS_PORT=$(find_available_port 6380)
    echo "Redis 포트 6379 사용 중 → $NEW_REDIS_PORT 포트로 변경"
    update_env_file "REDIS_PORT" "$NEW_REDIS_PORT"
else
    echo "Redis 포트 6379 사용 가능"
    update_env_file "REDIS_PORT" "6379"
fi

echo "✅ 포트 충돌 해결 완료!"
echo "📋 최종 포트 설정:"
grep -E "(POSTGRES_PORT|BACKEND_PORT|FRONTEND_HTTP_PORT|REDIS_PORT)" .env 2>/dev/null || echo "환경 파일을 확인하세요."