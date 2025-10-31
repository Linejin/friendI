# Frontend 서비스 테스트 스크립트 (PowerShell)

param(
    [int]$Port = 3000
)

Write-Host "🧪 Frontend 서비스 종합 테스트" -ForegroundColor Green
Write-Host "포트: $Port" -ForegroundColor Yellow
Write-Host "=============================" -ForegroundColor Green

function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Description,
        [int]$ExpectedStatus = 200
    )
    
    Write-Host "`n📡 $Description" -ForegroundColor Cyan
    Write-Host "URL: $Url" -ForegroundColor Gray
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "✅ 성공 (Status: $($response.StatusCode))" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ 예상하지 못한 상태 코드: $($response.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ 실패: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-ApiEndpoint {
    param(
        [string]$Url,
        [string]$Description
    )
    
    Write-Host "`n🔗 $Description" -ForegroundColor Cyan
    Write-Host "URL: $Url" -ForegroundColor Gray
    
    try {
        # OPTIONS 요청으로 CORS 헤더 확인
        $headers = @{
            'Access-Control-Request-Method' = 'GET'
            'Access-Control-Request-Headers' = 'Content-Type'
        }
        
        $response = Invoke-WebRequest -Uri $Url -Method Options -Headers $headers -TimeoutSec 10 -ErrorAction SilentlyContinue
        
        if ($response) {
            Write-Host "✅ API 엔드포인트 접근 가능" -ForegroundColor Green
            
            # CORS 헤더 확인
            $corsHeaders = $response.Headers | Where-Object { $_.Key -match "Access-Control" }
            if ($corsHeaders) {
                Write-Host "✅ CORS 헤더 설정됨" -ForegroundColor Green
            }
            return $true
        } else {
            # GET 요청으로 재시도
            $getResponse = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -ErrorAction SilentlyContinue
            if ($getResponse) {
                Write-Host "✅ API 엔드포인트 접근 가능 (GET)" -ForegroundColor Green
                return $true
            }
        }
    } catch {
        Write-Host "❌ 실패: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

try {
    # 1. 컨테이너 상태 확인
    Write-Host "`n🐳 Docker 컨테이너 상태" -ForegroundColor Yellow
    $containers = docker ps --filter "name=frontend" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    if ($containers -and $containers.Count -gt 1) {
        Write-Host $containers -ForegroundColor White
        Write-Host "✅ Frontend 컨테이너 실행 중" -ForegroundColor Green
    } else {
        Write-Host "❌ Frontend 컨테이너를 찾을 수 없습니다" -ForegroundColor Red
        Write-Host "docker-compose up -d frontend 를 먼저 실행하세요" -ForegroundColor Yellow
        exit 1
    }

    # 2. 기본 웹 서비스 테스트
    $results = @()
    $results += Test-Endpoint "http://localhost:$Port/" "Frontend 메인 페이지"
    
    # 3. 정적 파일 테스트 (존재할 가능성이 있는 파일들)
    $staticFiles = @(
        "/favicon.ico",
        "/manifest.json",
        "/static/css/",
        "/static/js/"
    )
    
    foreach ($file in $staticFiles) {
        $results += Test-Endpoint "http://localhost:$Port$file" "정적 파일: $file" -ExpectedStatus 200
    }

    # 4. API 프록시 테스트
    Write-Host "`n🔌 API 프록시 테스트" -ForegroundColor Yellow
    $results += Test-ApiEndpoint "http://localhost:$Port/api/" "API 기본 엔드포인트"
    
    # 5. 백엔드 서비스 프록시 테스트
    $backendEndpoints = @(
        "/actuator/health",
        "/swagger-ui/",
        "/v3/api-docs"
    )
    
    foreach ($endpoint in $backendEndpoints) {
        $results += Test-Endpoint "http://localhost:$Port$endpoint" "Backend 프록시: $endpoint"
    }

    # 6. Nginx 설정 검증
    Write-Host "`n⚙️ Nginx 설정 검증" -ForegroundColor Yellow
    try {
        $nginxTest = docker-compose exec -T frontend nginx -t 2>&1
        if ($nginxTest -match "successful") {
            Write-Host "✅ Nginx 설정 문법 검증 성공" -ForegroundColor Green
            $results += $true
        } else {
            Write-Host "❌ Nginx 설정 오류:" -ForegroundColor Red
            Write-Host $nginxTest -ForegroundColor Red
            $results += $false
        }
    } catch {
        Write-Host "❌ Nginx 설정 검증 실패: $_" -ForegroundColor Red
        $results += $false
    }

    # 7. 로그 상태 확인
    Write-Host "`n📋 최근 로그 확인" -ForegroundColor Yellow
    try {
        $logs = docker-compose logs --tail=10 frontend 2>&1
        $errorLogs = $logs | Select-String -Pattern "error|emerg|alert|crit" -CaseSensitive:$false
        
        if ($errorLogs) {
            Write-Host "⚠️ 로그에서 오류 발견:" -ForegroundColor Yellow
            $errorLogs | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            $results += $false
        } else {
            Write-Host "✅ 로그에 심각한 오류 없음" -ForegroundColor Green
            $results += $true
        }
    } catch {
        Write-Host "⚠️ 로그 확인 중 오류 발생" -ForegroundColor Yellow
    }

    # 8. 결과 요약
    Write-Host "`n📊 테스트 결과 요약" -ForegroundColor Green
    Write-Host "====================" -ForegroundColor Green
    
    $successCount = ($results | Where-Object { $_ -eq $true }).Count
    $totalCount = $results.Count
    $successRate = if ($totalCount -gt 0) { [math]::Round(($successCount / $totalCount) * 100, 1) } else { 0 }
    
    Write-Host "성공: $successCount / $totalCount ($successRate%)" -ForegroundColor $(if($successRate -ge 80) {"Green"} elseif($successRate -ge 60) {"Yellow"} else {"Red"})
    
    if ($successRate -ge 80) {
        Write-Host "🎉 Frontend 서비스가 정상적으로 작동 중입니다!" -ForegroundColor Green
    } elseif ($successRate -ge 60) {
        Write-Host "⚠️ 일부 기능에 문제가 있을 수 있습니다" -ForegroundColor Yellow
    } else {
        Write-Host "❌ 심각한 문제가 있습니다. 로그를 확인하세요" -ForegroundColor Red
    }

    # 9. 추가 정보
    Write-Host "`n🔗 유용한 링크:" -ForegroundColor Cyan
    Write-Host "- Frontend: http://localhost:$Port" -ForegroundColor White
    Write-Host "- API Health: http://localhost:$Port/actuator/health" -ForegroundColor White
    Write-Host "- Swagger UI: http://localhost:$Port/swagger-ui/" -ForegroundColor White
    
    Write-Host "`n🛠️ 문제 해결 명령어:" -ForegroundColor Yellow
    Write-Host "- 실시간 로그: docker-compose logs -f frontend" -ForegroundColor White
    Write-Host "- 컨테이너 재시작: docker-compose restart frontend" -ForegroundColor White
    Write-Host "- 전체 재배포: .\redeploy-frontend.ps1" -ForegroundColor White

} catch {
    Write-Host "`n❌ 테스트 실행 중 오류 발생: $_" -ForegroundColor Red
}