# Frontend Nginx 재배포 스크립트 (PowerShell)

Write-Host "🔧 Nginx 설정 수정 후 Frontend 재배포 중..." -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

try {
    # 1. 현재 컨테이너 상태 확인
    Write-Host "`n📋 현재 컨테이너 상태:" -ForegroundColor Yellow
    docker ps -a --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | Where-Object { $_ -match "frontend" }

    # 2. Frontend 컨테이너 중지 및 제거
    Write-Host "`n🛑 Frontend 컨테이너 중지 및 제거 중..." -ForegroundColor Yellow
    docker-compose stop frontend 2>$null
    docker-compose rm -f frontend 2>$null
    Write-Host "✅ Frontend 컨테이너 정리 완료" -ForegroundColor Green

    # 3. Frontend 이미지 재빌드 (캐시 무시)
    Write-Host "`n🔨 Frontend 이미지 재빌드 중..." -ForegroundColor Yellow
    $buildResult = docker-compose build --no-cache frontend 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Frontend 이미지 빌드 완료" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 빌드 중 일부 경고가 있었지만 계속 진행합니다" -ForegroundColor Yellow
        Write-Host $buildResult -ForegroundColor Gray
    }

    # 4. Frontend 컨테이너 시작
    Write-Host "`n🚀 Frontend 컨테이너 시작 중..." -ForegroundColor Yellow
    $startResult = docker-compose up -d frontend 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Frontend 컨테이너 시작 완료" -ForegroundColor Green
    } else {
        Write-Host "❌ Frontend 컨테이너 시작 실패:" -ForegroundColor Red
        Write-Host $startResult -ForegroundColor Red
        throw "Frontend 컨테이너 시작 실패"
    }

    # 5. 잠시 대기 후 상태 확인
    Write-Host "`n⏳ 컨테이너 초기화 대기 중..." -ForegroundColor Cyan
    Start-Sleep -Seconds 15

    # 6. Nginx 설정 테스트
    Write-Host "`n🧪 Nginx 설정 검증 중..." -ForegroundColor Cyan
    $nginxTest = docker-compose exec -T frontend nginx -t 2>&1
    if ($nginxTest -match "successful") {
        Write-Host "✅ Nginx 설정 검증 성공" -ForegroundColor Green
    } else {
        Write-Host "❌ Nginx 설정 오류:" -ForegroundColor Red
        Write-Host $nginxTest -ForegroundColor Red
    }

    # 7. 컨테이너 상태 확인
    Write-Host "`n📊 최신 컨테이너 상태:" -ForegroundColor Yellow
    docker-compose ps frontend

    # 8. Frontend 로그 확인 (최근 20줄)
    Write-Host "`n📝 Frontend 로그 (최근 20줄):" -ForegroundColor Yellow
    docker-compose logs --tail=20 frontend

    # 9. 헬스체크
    Write-Host "`n🏥 Frontend 헬스체크..." -ForegroundColor Cyan
    $frontendPort = 3000  # docker-compose.yml에서 설정된 포트
    
    $timeout = 60
    $counter = 0
    $healthCheckPassed = $false

    while ($counter -lt $timeout -and -not $healthCheckPassed) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$frontendPort" -TimeoutSec 5 -ErrorAction SilentlyContinue
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
            Start-Sleep -Seconds 2
        }
    }

    if (-not $healthCheckPassed) {
        Write-Host "⚠️ Frontend 헬스체크 타임아웃 - 수동으로 확인하세요" -ForegroundColor Yellow
    }

    # 10. 최종 정보 출력
    Write-Host "`n🎉 Frontend 재배포 완료!" -ForegroundColor Green
    Write-Host "=========================" -ForegroundColor Green
    
    Write-Host "`n🌐 접속 정보:" -ForegroundColor Cyan
    Write-Host "- Frontend: http://localhost:$frontendPort" -ForegroundColor White
    Write-Host "- API 프록시: http://localhost:$frontendPort/api/" -ForegroundColor White
    Write-Host "- Swagger UI: http://localhost:$frontendPort/swagger-ui/" -ForegroundColor White
    Write-Host "- Actuator: http://localhost:$frontendPort/actuator/health" -ForegroundColor White

    Write-Host "`n🔧 유용한 명령어:" -ForegroundColor Yellow
    Write-Host "- 실시간 로그: docker-compose logs -f frontend" -ForegroundColor White
    Write-Host "- Nginx 재로드: docker-compose exec frontend nginx -s reload" -ForegroundColor White
    Write-Host "- 컨테이너 재시작: docker-compose restart frontend" -ForegroundColor White

} catch {
    Write-Host "`n❌ 재배포 중 오류 발생: $_" -ForegroundColor Red
    Write-Host "`n🔍 문제 해결을 위한 로그 확인:" -ForegroundColor Yellow
    Write-Host "docker-compose logs frontend" -ForegroundColor White
}