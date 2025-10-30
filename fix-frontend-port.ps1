# Frontend 포트 충돌 해결 스크립트 (PowerShell)

param(
    [int]$NewPort = 3000,
    [int]$NewHttpsPort = 3443
)

Write-Host "🛠️ Frontend 포트 충돌 해결 중..." -ForegroundColor Cyan
Write-Host "새 HTTP 포트: $NewPort" -ForegroundColor Yellow
Write-Host "새 HTTPS 포트: $NewHttpsPort" -ForegroundColor Yellow

try {
    # 1. 현재 컨테이너 상태 확인
    Write-Host "`n📋 현재 컨테이너 상태:" -ForegroundColor Yellow
    $containers = docker ps -a --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" 2>$null
    if ($containers) {
        Write-Host $containers -ForegroundColor White
    }

    # 2. Frontend 컨테이너 중지 및 제거
    Write-Host "`n🛑 Frontend 컨테이너 중지 중..." -ForegroundColor Yellow
    docker stop i-frontend 2>$null
    docker rm i-frontend 2>$null
    Write-Host "✅ Frontend 컨테이너 정리 완료" -ForegroundColor Green

    # 3. docker-compose.yml 파일 백업
    if (Test-Path "docker-compose.yml") {
        $backupFile = "docker-compose.yml.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item "docker-compose.yml" $backupFile
        Write-Host "✅ docker-compose.yml 백업: $backupFile" -ForegroundColor Green
    }

    # 4. docker-compose.yml에서 포트 변경
    Write-Host "`n🔧 docker-compose.yml 포트 설정 변경 중..." -ForegroundColor Yellow
    if (Test-Path "docker-compose.yml") {
        $content = Get-Content "docker-compose.yml" -Raw
        
        # 포트 교체
        $content = $content -replace '"80:80"', "`"$NewPort`:80`""
        $content = $content -replace "'80:80'", "'$NewPort`:80'"
        $content = $content -replace "80:80", "$NewPort`:80"
        
        $content = $content -replace '"443:443"', "`"$NewHttpsPort`:443`""
        $content = $content -replace "'443:443'", "'$NewHttpsPort`:443'"
        $content = $content -replace "443:443", "$NewHttpsPort`:443"
        
        # 파일에 저장
        $content | Set-Content "docker-compose.yml" -Encoding UTF8
        Write-Host "✅ 포트 설정 변경 완료" -ForegroundColor Green
    } else {
        Write-Host "❌ docker-compose.yml 파일을 찾을 수 없습니다" -ForegroundColor Red
        exit 1
    }

    # 5. Frontend 이미지 다시 빌드
    Write-Host "`n🔨 Frontend 이미지 빌드 중..." -ForegroundColor Yellow
    $buildResult = docker-compose build frontend 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Frontend 이미지 빌드 완료" -ForegroundColor Green
    } else {
        Write-Host "❌ Frontend 이미지 빌드 실패:" -ForegroundColor Red
        Write-Host $buildResult -ForegroundColor Red
    }

    # 6. Frontend 컨테이너 시작
    Write-Host "`n🚀 Frontend 컨테이너 시작 중..." -ForegroundColor Yellow
    $startResult = docker-compose up -d frontend 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Frontend 컨테이너 시작 완료" -ForegroundColor Green
    } else {
        Write-Host "❌ Frontend 컨테이너 시작 실패:" -ForegroundColor Red
        Write-Host $startResult -ForegroundColor Red
    }

    # 7. 헬스체크 대기
    Write-Host "`n⏳ Frontend 헬스체크 대기 중..." -ForegroundColor Yellow
    $timeout = 60
    $counter = 0
    $healthCheckPassed = $false

    while ($counter -lt $timeout -and -not $healthCheckPassed) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$NewPort" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $healthCheckPassed = $true
                Write-Host "✅ Frontend 헬스체크 성공!" -ForegroundColor Green
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        if (-not $healthCheckPassed) {
            $counter++
            Write-Host "Frontend 대기 중... ($counter/$timeout)" -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
    }

    if (-not $healthCheckPassed) {
        Write-Host "⚠️ Frontend 헬스체크 타임아웃 - 로그 확인:" -ForegroundColor Yellow
        docker logs i-frontend --tail 10 2>$null
    }

    # 8. 최종 상태 확인
    Write-Host "`n🎉 포트 충돌 해결 완료!" -ForegroundColor Green
    Write-Host "══════════════════════════════" -ForegroundColor Green
    
    $finalContainers = docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" 2>$null
    if ($finalContainers) {
        Write-Host "`n📋 현재 컨테이너 상태:" -ForegroundColor Yellow
        Write-Host $finalContainers -ForegroundColor White
    }

    Write-Host "`n🌐 접속 정보:" -ForegroundColor Green
    Write-Host "- Frontend: http://localhost:$NewPort" -ForegroundColor Cyan
    Write-Host "- Frontend HTTPS: https://localhost:$NewHttpsPort" -ForegroundColor Cyan
    Write-Host "- Backend API: http://localhost:8080" -ForegroundColor Cyan
    Write-Host "- Swagger UI: http://localhost:8080/swagger-ui.html" -ForegroundColor Cyan

    Write-Host "`n📝 추가 작업 필요:" -ForegroundColor Yellow
    Write-Host "- AWS EC2 보안 그룹에서 포트 $NewPort 인바운드 규칙 추가" -ForegroundColor White
    Write-Host "- 기존 80 포트 규칙은 제거 가능" -ForegroundColor White

} catch {
    Write-Host "`n❌ 오류 발생: $_" -ForegroundColor Red
    Write-Host "백업 파일을 사용하여 복구하세요." -ForegroundColor Yellow
}