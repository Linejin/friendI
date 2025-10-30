# 포트 80 충돌 확인 및 해결 스크립트 (PowerShell)

Write-Host "🔍 포트 80 사용 프로세스 확인 중..." -ForegroundColor Cyan

# 1. 80 포트 사용 프로세스 확인
Write-Host "`n80 포트 사용 상황:" -ForegroundColor Yellow
try {
    $port80 = netstat -ano | Select-String ":80 " | Select-String "LISTENING"
    if ($port80) {
        Write-Host $port80 -ForegroundColor Red
        # PID 추출하여 프로세스 정보 표시
        $port80 | ForEach-Object {
            $pid = ($_ -split '\s+')[-1]
            $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "Process: $($process.ProcessName) (PID: $pid)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "✅ 80 포트 사용 중인 프로세스 없음" -ForegroundColor Green
    }
} catch {
    Write-Host "포트 확인 중 오류: $_" -ForegroundColor Red
}

# 2. 모든 웹 관련 포트 확인
Write-Host "`n모든 웹 관련 포트 확인 (80, 443, 8080, 3000):" -ForegroundColor Yellow
$webPorts = @(80, 443, 8080, 3000)
foreach ($port in $webPorts) {
    $portCheck = netstat -ano | Select-String ":$port " | Select-String "LISTENING"
    if ($portCheck) {
        Write-Host "Port $port in use:" -ForegroundColor Red
        Write-Host $portCheck -ForegroundColor Red
    } else {
        Write-Host "Port $port available" -ForegroundColor Green
    }
}

# 3. Windows 서비스 확인
Write-Host "`n웹 서버 서비스 상태 확인:" -ForegroundColor Yellow
$webServices = @("W3SVC", "HTTP", "Apache", "nginx")
foreach ($serviceName in $webServices) {
    try {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "$serviceName 서비스: $($service.Status)" -ForegroundColor $(if($service.Status -eq "Running") {"Red"} else {"Green"})
            if ($service.Status -eq "Running") {
                Write-Host "  중지 방법: Stop-Service -Name $serviceName -Force" -ForegroundColor Yellow
            }
        }
    } catch {
        # 서비스가 없으면 무시
    }
}

# 4. Docker 컨테이너 확인
Write-Host "`nDocker 컨테이너 확인:" -ForegroundColor Yellow
try {
    $dockerContainers = docker ps --format "table {{.Names}}`t{{.Ports}}" 2>$null
    if ($dockerContainers) {
        Write-Host $dockerContainers -ForegroundColor Cyan
    } else {
        Write-Host "실행 중인 Docker 컨테이너 없음" -ForegroundColor Green
    }
} catch {
    Write-Host "Docker 명령 실행 실패" -ForegroundColor Red
}

# 5. 해결 옵션 제시
Write-Host "`n🛠️ 해결 방법 옵션:" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
Write-Host "1. [권장] Frontend를 3000 포트로 사용" -ForegroundColor Cyan
Write-Host "   .\fix-frontend-port.ps1" -ForegroundColor White
Write-Host ""
Write-Host "2. 80 포트 사용 서비스 중지 후 Frontend 80 포트 사용" -ForegroundColor Cyan
Write-Host "   Stop-Service -Name W3SVC -Force  # IIS 중지" -ForegroundColor White
Write-Host "   docker-compose restart frontend" -ForegroundColor White
Write-Host ""
Write-Host "3. 80 포트 사용 프로세스 직접 종료" -ForegroundColor Cyan
Write-Host "   netstat -ano | Select-String ':80'  # PID 확인" -ForegroundColor White
Write-Host "   Stop-Process -Id [PID] -Force  # 프로세스 종료" -ForegroundColor White
Write-Host ""

# 6. 자동 해결 옵션
$choice = Read-Host "`nFrontend를 3000 포트로 변경하시겠습니까? (y/N)"
if ($choice -match "^[yY]") {
    Write-Host "Frontend 포트를 3000으로 변경합니다..." -ForegroundColor Green
    if (Test-Path ".\fix-frontend-port.ps1") {
        & ".\fix-frontend-port.ps1"
    } else {
        Write-Host "fix-frontend-port.ps1 파일을 찾을 수 없습니다" -ForegroundColor Red
    }
} else {
    Write-Host "수동으로 해결하세요." -ForegroundColor Yellow
}