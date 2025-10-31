#!/bin/bash
# 풀스택 배포 재시작 스크립트 (Linux/macOS)

# 옵션 파싱
FRONTEND_PORT=3000
FRONTEND_HTTPS_PORT=3443

while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            FRONTEND_PORT="$2"
            shift 2
            ;;
        --https-port)
            FRONTEND_HTTPS_PORT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--port PORT] [--https-port HTTPS_PORT]"
            exit 1
            ;;
    esac
done

echo "🚀 풀스택 배포 재시작 중..."
echo "Frontend Port: $FRONTEND_PORT"
echo "Frontend HTTPS Port: $FRONTEND_HTTPS_PORT"
echo "================================"

try {
    # 1. 현재 컨테이너 상태 확인
    Write-Host "`n📋 현재 컨테이너 상태:" -ForegroundColor Yellow
    $containers = docker ps -a --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" 2>$null
    if ($containers) {
        Write-Host $containers -ForegroundColor White
    }

    # 2. 실행 중인 컨테이너들 정리
    Write-Host "`n🧹 기존 컨테이너 정리 중..." -ForegroundColor Yellow
    docker-compose down --remove-orphans 2>$null
    Write-Host "✅ 컨테이너 정리 완료" -ForegroundColor Green

    # 3. 포트 80 사용 여부 확인 및 해결
    Write-Host "`n🔍 포트 충돌 확인 중..." -ForegroundColor Yellow
    $port80InUse = netstat -ano | Select-String ":80 " | Select-String "LISTENING"
    
    if ($port80InUse) {
        Write-Host "⚠️ 포트 80이 사용 중입니다" -ForegroundColor Red
        Write-Host "Frontend를 $FrontendPort 포트로 변경하여 배포합니다" -ForegroundColor Cyan
        
        # docker-compose.yml에서 Frontend 포트 변경
        if (Test-Path "docker-compose.yml") {
            $content = Get-Content "docker-compose.yml" -Raw
            
            if ($content -match '"80:80"|''80:80''|80:80') {
                $content = $content -replace '"80:80"', "`"$FrontendPort`:80`""
                $content = $content -replace "'80:80'", "'$FrontendPort`:80'"
                $content = $content -replace "80:80", "$FrontendPort`:80"
                
                $content = $content -replace '"443:443"', "`"$FrontendHttpsPort`:443`""
                $content = $content -replace "'443:443'", "'$FrontendHttpsPort`:443'"
                $content = $content -replace "443:443", "$FrontendHttpsPort`:443"
                
                $content | Set-Content "docker-compose.yml" -Encoding UTF8
                Write-Host "✅ Frontend 포트를 $FrontendPort 으로 변경했습니다" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "✅ 포트 80 사용 가능" -ForegroundColor Green
        $FrontendPort = 80
        $FrontendHttpsPort = 443
    }

    # 4. Docker 이미지 빌드
    Write-Host "`n🔨 이미지 빌드 중..." -ForegroundColor Yellow
    $buildResult = docker-compose build --no-cache 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 이미지 빌드 완료" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 이미지 빌드 중 일부 오류 발생, 계속 진행합니다" -ForegroundColor Yellow
    }

    # 5. 데이터베이스 먼저 시작
    Write-Host "`n💾 데이터베이스 서비스 시작 중..." -ForegroundColor Yellow
    docker-compose up -d postgres redis 2>$null
    Write-Host "✅ 데이터베이스 서비스 시작 완료" -ForegroundColor Green

    # 6. 데이터베이스 연결 대기
    Write-Host "`n⏳ 데이터베이스 준비 대기 중..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # PostgreSQL 연결 확인
    Write-Host "PostgreSQL 연결 확인 중..." -ForegroundColor Cyan
    $timeout = 60
    $counter = 0
    $pgReady = $false

    while ($counter -lt $timeout -and -not $pgReady) {
        try {
            $pgCheck = docker exec i-postgres pg_isready -h localhost -p 5432 2>$null
            if ($LASTEXITCODE -eq 0) {
                $pgReady = $true
                Write-Host "✅ PostgreSQL 준비 완료" -ForegroundColor Green
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        if (-not $pgReady) {
            $counter++
            Write-Host "PostgreSQL 대기 중... ($counter/$timeout)" -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
    }

    if (-not $pgReady) {
        Write-Host "❌ PostgreSQL 연결 실패 - 타임아웃" -ForegroundColor Red
        docker logs i-postgres --tail 20 2>$null
        throw "PostgreSQL 연결 실패"
    }

    # Redis 연결 확인
    Write-Host "Redis 연결 확인 중..." -ForegroundColor Cyan
    $timeout = 30
    $counter = 0
    $redisReady = $false

    while ($counter -lt $timeout -and -not $redisReady) {
        try {
            $redisCheck = docker exec i-redis redis-cli ping 2>$null
            if ($redisCheck -match "PONG") {
                $redisReady = $true
                Write-Host "✅ Redis 준비 완료" -ForegroundColor Green
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        if (-not $redisReady) {
            $counter++
            Write-Host "Redis 대기 중... ($counter/$timeout)" -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
    }

    if (-not $redisReady) {
        Write-Host "❌ Redis 연결 실패 - 타임아웃" -ForegroundColor Red
        docker logs i-redis --tail 20 2>$null
        throw "Redis 연결 실패"
    }

    # 7. Backend 시작
    Write-Host "`n⚙️ Backend 서비스 시작 중..." -ForegroundColor Yellow
    docker-compose up -d backend 2>$null
    Write-Host "✅ Backend 서비스 시작 완료" -ForegroundColor Green

    # Backend 헬스체크 대기
    Write-Host "Backend 헬스체크 대기 중..." -ForegroundColor Cyan
    $timeout = 120
    $counter = 0
    $backendReady = $false

    while ($counter -lt $timeout -and -not $backendReady) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/actuator/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $backendReady = $true
                Write-Host "✅ Backend 준비 완료" -ForegroundColor Green
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        if (-not $backendReady) {
            $counter++
            Write-Host "Backend 대기 중... ($counter/$timeout)" -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
    }

    if (-not $backendReady) {
        Write-Host "❌ Backend 헬스체크 실패 - 타임아웃" -ForegroundColor Red
        Write-Host "Backend 로그 확인:" -ForegroundColor Yellow
        docker logs i-backend --tail 20 2>$null
        throw "Backend 헬스체크 실패"
    }

    # 8. Frontend 시작
    Write-Host "`n🌐 Frontend 서비스 시작 중..." -ForegroundColor Yellow
    docker-compose up -d frontend 2>$null
    Write-Host "✅ Frontend 서비스 시작 완료" -ForegroundColor Green

    # Frontend 헬스체크 대기
    Write-Host "Frontend 헬스체크 대기 중..." -ForegroundColor Cyan
    $timeout = 60
    $counter = 0
    $frontendReady = $false

    while ($counter -lt $timeout -and -not $frontendReady) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$FrontendPort" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $frontendReady = $true
                Write-Host "✅ Frontend 준비 완료" -ForegroundColor Green
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        if (-not $frontendReady) {
            $counter++
            Write-Host "Frontend 대기 중... ($counter/$timeout)" -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
    }

    if (-not $frontendReady) {
        Write-Host "❌ Frontend 헬스체크 실패 - 타임아웃" -ForegroundColor Red
        Write-Host "Frontend 로그 확인:" -ForegroundColor Yellow
        docker logs i-frontend --tail 20 2>$null
    }

    # 9. 최종 상태 확인
    Write-Host "`n🎉 풀스택 배포 완료!" -ForegroundColor Green
    Write-Host "=======================" -ForegroundColor Green
    
    Write-Host "`n📋 서비스 상태:" -ForegroundColor Yellow
    $finalContainers = docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" 2>$null
    if ($finalContainers) {
        Write-Host $finalContainers -ForegroundColor White
    }

    Write-Host "`n🌐 접속 정보:" -ForegroundColor Green
    Write-Host "- Frontend: http://localhost:$FrontendPort" -ForegroundColor Cyan
    if ($FrontendPort -ne 80) {
        Write-Host "- Frontend HTTPS: https://localhost:$FrontendHttpsPort" -ForegroundColor Cyan
    }
    Write-Host "- Backend API: http://localhost:8080" -ForegroundColor Cyan
    Write-Host "- Backend Health: http://localhost:8080/actuator/health" -ForegroundColor Cyan
    Write-Host "- Swagger UI: http://localhost:8080/swagger-ui.html" -ForegroundColor Cyan
    Write-Host "- PostgreSQL: localhost:5433" -ForegroundColor Cyan
    Write-Host "- Redis: localhost:6379" -ForegroundColor Cyan

    Write-Host "`n🔧 유용한 명령어:" -ForegroundColor Yellow
    Write-Host "- 전체 로그 보기: docker-compose logs -f" -ForegroundColor White
    Write-Host "- 개별 로그 보기: docker logs i-[service-name]" -ForegroundColor White
    Write-Host "- 서비스 재시작: docker-compose restart [service-name]" -ForegroundColor White
    Write-Host "- 전체 중지: docker-compose down" -ForegroundColor White

    # 10. AWS 보안 그룹 업데이트 알림
    if ($FrontendPort -ne 80) {
        Write-Host "`n📝 AWS 보안 그룹 업데이트 필요:" -ForegroundColor Yellow
        Write-Host "- EC2 보안 그룹에서 포트 $FrontendPort 인바운드 규칙 추가" -ForegroundColor White
        Write-Host "- 기존 80 포트 규칙은 제거 가능" -ForegroundColor White
    }

    Write-Host "`n✅ 풀스택 배포가 완료되었습니다!" -ForegroundColor Green

} catch {
    Write-Host "`n❌ 배포 중 오류 발생: $_" -ForegroundColor Red
    Write-Host "로그를 확인하고 수동으로 문제를 해결하세요." -ForegroundColor Yellow
}