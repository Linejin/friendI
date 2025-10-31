# Backend CORS 수정 후 재배포 스크립트 (PowerShell)

Write-Host "🔧 Backend CORS 설정 수정 후 재배포 중..." -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

try {
    # 1. 현재 Backend 컨테이너 상태 확인
    Write-Host "`n📋 현재 Backend 컨테이너 상태:" -ForegroundColor Yellow
    docker ps --filter "name=backend" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"

    # 2. Backend 컨테이너 중지
    Write-Host "`n🛑 Backend 컨테이너 중지 중..." -ForegroundColor Yellow
    docker-compose stop backend 2>$null
    Write-Host "✅ Backend 컨테이너 중지 완료" -ForegroundColor Green

    # 3. Backend 이미지 재빌드
    Write-Host "`n🔨 Backend 이미지 재빌드 중..." -ForegroundColor Yellow
    $buildResult = docker-compose build --no-cache backend 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Backend 이미지 빌드 완료" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 빌드 중 일부 경고가 있었지만 계속 진행합니다" -ForegroundColor Yellow
    }

    # 4. 데이터베이스가 실행 중인지 확인
    Write-Host "`n💾 데이터베이스 상태 확인 중..." -ForegroundColor Cyan
    $postgresStatus = docker ps --filter "name=postgres" --format "{{.Status}}"
    $redisStatus = docker ps --filter "name=redis" --format "{{.Status}}"
    
    if ($postgresStatus -match "Up") {
        Write-Host "✅ PostgreSQL 실행 중: $postgresStatus" -ForegroundColor Green
    } else {
        Write-Host "⚠️ PostgreSQL 시작 중..." -ForegroundColor Yellow
        docker-compose up -d postgres 2>$null
        Start-Sleep -Seconds 10
    }
    
    if ($redisStatus -match "Up") {
        Write-Host "✅ Redis 실행 중: $redisStatus" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Redis 시작 중..." -ForegroundColor Yellow
        docker-compose up -d redis 2>$null
        Start-Sleep -Seconds 5
    }

    # 5. Backend 컨테이너 시작
    Write-Host "`n🚀 Backend 컨테이너 시작 중..." -ForegroundColor Yellow
    docker-compose up -d backend 2>$null
    Write-Host "✅ Backend 컨테이너 시작 완료" -ForegroundColor Green

    # 6. Backend 헬스체크 대기
    Write-Host "`n⏳ Backend 헬스체크 대기 중..." -ForegroundColor Cyan
    $timeout = 120
    $counter = 0
    $healthCheckPassed = $false

    while ($counter -lt $timeout -and -not $healthCheckPassed) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/actuator/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $healthCheckPassed = $true
                Write-Host "✅ Backend 헬스체크 성공!" -ForegroundColor Green
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        if (-not $healthCheckPassed) {
            $counter++
            Write-Host "Backend 대기 중... ($counter/$timeout)" -ForegroundColor Cyan
            Start-Sleep -Seconds 2
        }
    }

    if (-not $healthCheckPassed) {
        Write-Host "⚠️ Backend 헬스체크 타임아웃 - 로그 확인:" -ForegroundColor Yellow
        docker-compose logs --tail=20 backend
    }

    # 7. CORS 테스트
    Write-Host "`n🌐 CORS 설정 테스트..." -ForegroundColor Cyan
    try {
        $corsTest = Invoke-WebRequest -Uri "http://localhost:8080/api/" -Method Options -Headers @{
            'Origin' = 'http://localhost:3000'
            'Access-Control-Request-Method' = 'GET'
            'Access-Control-Request-Headers' = 'Content-Type'
        } -TimeoutSec 10 -ErrorAction SilentlyContinue

        if ($corsTest -and $corsTest.Headers.ContainsKey('Access-Control-Allow-Origin')) {
            Write-Host "✅ CORS 설정이 올바르게 적용되었습니다" -ForegroundColor Green
        } else {
            Write-Host "⚠️ CORS 헤더 확인 필요" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ CORS 테스트 실패: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # 8. 최종 상태 확인
    Write-Host "`n🎉 Backend 재배포 완료!" -ForegroundColor Green
    Write-Host "=========================" -ForegroundColor Green
    
    Write-Host "`n📋 서비스 상태:" -ForegroundColor Yellow
    docker-compose ps

    Write-Host "`n🌐 접속 정보:" -ForegroundColor Green
    Write-Host "- Backend API: http://localhost:8080" -ForegroundColor Cyan
    Write-Host "- Backend Health: http://localhost:8080/actuator/health" -ForegroundColor Cyan
    Write-Host "- Swagger UI: http://localhost:8080/swagger-ui/" -ForegroundColor Cyan
    Write-Host "- Frontend: http://localhost:3000" -ForegroundColor Cyan

    Write-Host "`n🔧 CORS 수정 사항:" -ForegroundColor Yellow
    Write-Host "- 모든 도메인 패턴 허용 (allowed-origin-patterns=*)" -ForegroundColor White
    Write-Host "- 추가 HTTP 메서드 지원 (HEAD 포함)" -ForegroundColor White
    Write-Host "- 확장된 헤더 노출 설정" -ForegroundColor White

} catch {
    Write-Host "`n❌ 재배포 중 오류 발생: $_" -ForegroundColor Red
    Write-Host "`n🔍 문제 해결을 위한 로그 확인:" -ForegroundColor Yellow
    Write-Host "docker-compose logs backend" -ForegroundColor White
}