# 전체 스택 (Frontend + Backend) 자동 배포 스크립트 - PowerShell 버전
# PowerShell 실행 정책: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$Help
)

# 색상 정의 (Windows PowerShell 호환)
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Log-Info($message) {
    Write-ColorOutput Blue "[INFO] $message"
}

function Log-Success($message) {
    Write-ColorOutput Green "[SUCCESS] $message"
}

function Log-Warning($message) {
    Write-ColorOutput Yellow "[WARNING] $message"
}

function Log-Error($message) {
    Write-ColorOutput Red "[ERROR] $message"
}

function Print-Banner {
    Write-ColorOutput Blue @"
==================================================
    🚀 FriendlyI Full Stack Deployment
    📦 Frontend + Backend + Database
==================================================
"@
}

# 시스템 확인
function Check-System {
    Log-Info "시스템 확인 중..."
    
    # 메모리 확인
    $totalMem = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    Log-Info "총 메모리: ${totalMem}MB"
    
    if ($totalMem -lt 2000) {
        Log-Warning "메모리 부족! 최소 2GB 권장 (현재: ${totalMem}MB)"
        $script:UseSmallConfig = $true
    } else {
        $script:UseSmallConfig = $false
    }
    
    # Docker 확인
    try {
        $null = Get-Command docker -ErrorAction Stop
    } catch {
        Log-Error "Docker가 설치되지 않았습니다."
        exit 1
    }
    
    try {
        $null = Get-Command docker-compose -ErrorAction Stop
    } catch {
        Log-Error "Docker Compose가 설치되지 않았습니다."
        exit 1
    }
    
    Log-Success "시스템 확인 완료"
}

# 저장소 업데이트
function Update-Repository {
    Log-Info "저장소 업데이트 중..."
    
    if (Test-Path ".git") {
        try {
            git fetch origin
            try {
                git pull origin master
            } catch {
                git pull origin main
            }
            Log-Success "저장소 업데이트 완료"
        } catch {
            Log-Warning "Git 업데이트 실패"
        }
    } else {
        Log-Warning "Git 저장소가 아닙니다."
    }
}

# 환경 설정
function Setup-Environment {
    Log-Info "환경 설정 중..."
    
    # Frontend 환경 설정
    if (!(Test-Path "frontend\.env")) {
        if (Test-Path "frontend\.env.production") {
            Copy-Item "frontend\.env.production" "frontend\.env"
            Log-Info "Frontend 프로덕션 환경 설정 적용"
        } elseif (Test-Path "frontend\.env.example") {
            Copy-Item "frontend\.env.example" "frontend\.env"
            Log-Info "Frontend 기본 환경 설정 적용"
        }
    }
    
    # Backend 환경 설정
    if (!(Test-Path "backend\.env")) {
        if ((Test-Path "backend\.env.small") -and $script:UseSmallConfig) {
            Copy-Item "backend\.env.small" "backend\.env"
            Log-Info "Backend EC2 Small 환경 설정 적용"
        } elseif (Test-Path "backend\.env.example") {
            Copy-Item "backend\.env.example" "backend\.env"
            Log-Info "Backend 기본 환경 설정 적용"
        }
    }
    
    Log-Success "환경 설정 완료"
}

# 포트 충돌 확인
function Check-Ports {
    Log-Info "포트 충돌 확인 중..."
    
    # 5432 포트 확인 (PostgreSQL)
    $port5432 = Get-NetTCPConnection -LocalPort 5432 -ErrorAction SilentlyContinue
    if ($port5432) {
        Log-Warning "5432 포트가 사용 중입니다. Docker Compose에서 5433 포트를 사용합니다."
        # docker-compose.yml에서 포트 변경
        if (Test-Path "docker-compose.yml") {
            (Get-Content "docker-compose.yml") -replace "5432:5432", "5433:5432" | Set-Content "docker-compose.yml"
        }
    }
    
    # 80 포트 확인 (Frontend)
    $port80 = Get-NetTCPConnection -LocalPort 80 -ErrorAction SilentlyContinue
    if ($port80) {
        Log-Warning "80 포트가 사용 중입니다. Frontend를 3000 포트로 변경합니다."
        if (Test-Path "docker-compose.yml") {
            (Get-Content "docker-compose.yml") -replace '"80:80"', '"3000:80"' | Set-Content "docker-compose.yml"
        }
        $script:FrontendPort = 3000
    } else {
        $script:FrontendPort = 80
    }
    
    # 8080 포트 확인 (Backend)
    $port8080 = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
    if ($port8080) {
        Log-Warning "8080 포트가 사용 중입니다. 기존 프로세스를 확인하세요."
        Get-NetTCPConnection -LocalPort 8080 | Format-Table -AutoSize
    }
    
    Log-Success "포트 확인 완료"
}

# Docker 정리
function Cleanup-Docker {
    Log-Info "기존 컨테이너 정리 중..."
    
    # 기존 컨테이너 중지
    try {
        docker-compose down 2>$null
    } catch {}
    
    try {
        Push-Location backend
        docker-compose down 2>$null
        Pop-Location
    } catch {}
    
    # 사용하지 않는 리소스 정리
    docker system prune -f
    
    Log-Success "Docker 정리 완료"
}

# 전체 스택 빌드 및 배포
function Deploy-FullStack {
    Log-Info "전체 스택 빌드 및 배포 중..."
    
    # Docker Compose로 전체 스택 빌드
    Log-Info "이미지 빌드 중... (시간이 소요될 수 있습니다)"
    docker-compose build --no-cache
    
    # 컨테이너 시작
    Log-Info "서비스 시작 중..."
    docker-compose up -d
    
    Log-Success "전체 스택 배포 완료"
}

# 배포 상태 확인
function Check-Deployment {
    Log-Info "배포 상태 확인 중..."
    
    # 서비스 시작 대기
    Log-Info "서비스 시작 대기 중... (60초)"
    Start-Sleep -Seconds 60
    
    # 컨테이너 상태
    Write-Output ""
    Log-Info "컨테이너 상태:"
    docker-compose ps
    
    # Backend 헬스체크
    Write-Output ""
    Log-Info "Backend 헬스체크 중..."
    for ($i = 1; $i -le 12; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/actuator/health" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Log-Success "✅ Backend 정상 동작 중"
                break
            }
        } catch {
            if ($i -eq 12) {
                Log-Warning "⚠️ Backend 헬스체크 실패"
            } else {
                Log-Info "Backend 헬스체크 재시도... ($i/12)"
                Start-Sleep -Seconds 5
            }
        }
    }
    
    # Frontend 헬스체크
    Log-Info "Frontend 헬스체크 중..."
    for ($i = 1; $i -le 6; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$($script:FrontendPort)" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Log-Success "✅ Frontend 정상 동작 중"
                break
            }
        } catch {
            if ($i -eq 6) {
                Log-Warning "⚠️ Frontend 헬스체크 실패"
            } else {
                Log-Info "Frontend 헬스체크 재시도... ($i/6)"
                Start-Sleep -Seconds 5
            }
        }
    }
}

# 배포 정보 출력
function Show-DeploymentInfo {
    Write-Output ""
    Log-Success "🎉 전체 스택 배포 완료!"
    Write-Output ""
    
    # IP 주소 확인
    try {
        $publicIP = (Invoke-WebRequest -Uri "https://ifconfig.me" -UseBasicParsing -TimeoutSec 10).Content.Trim()
    } catch {
        $publicIP = "IP확인실패"
    }
    
    $privateIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    
    Write-Output "📋 접속 정보:"
    Write-Output "   🌐 Frontend (웹사이트):"
    Write-Output "      외부: http://${publicIP}:$($script:FrontendPort)"
    Write-Output "      내부: http://${privateIP}:$($script:FrontendPort)"
    Write-Output ""
    Write-Output "   🔧 Backend API:"
    Write-Output "      외부: http://${publicIP}:8080"
    Write-Output "      내부: http://${privateIP}:8080"
    Write-Output "      헬스체크: http://${publicIP}:8080/actuator/health"
    Write-Output "      API 문서: http://${publicIP}:8080/swagger-ui.html"
    Write-Output ""
    
    Write-Output "🔐 기본 계정 정보:"
    Write-Output "   관리자: admin / admin123"
    Write-Output "   사용자: user1 / 1234"
    Write-Output ""
    
    Write-Output "📊 관리 명령어:"
    Write-Output "   전체 로그: docker-compose logs -f"
    Write-Output "   Backend 로그: docker-compose logs -f backend"
    Write-Output "   Frontend 로그: docker-compose logs -f frontend"
    Write-Output "   상태 확인: docker-compose ps"
    Write-Output "   서비스 재시작: docker-compose restart"
    Write-Output "   서비스 중지: docker-compose down"
    Write-Output ""
    
    Write-Output "⚠️ 보안 그룹 설정 확인 (AWS EC2의 경우):"
    Write-Output "   - $($script:FrontendPort) 포트 (Frontend) 인바운드 규칙 추가"
    Write-Output "   - 8080 포트 (Backend) 인바운드 규칙 추가"
    Write-Output ""
}

# 에러 처리
function Handle-Error {
    Log-Error "❌ 배포 중 오류가 발생했습니다."
    
    Write-Output "📋 문제 해결:"
    Write-Output "   1. 포트 확인: Get-NetTCPConnection -LocalPort 80,8080,5432"
    Write-Output "   2. Docker 로그: docker-compose logs"
    Write-Output "   3. 메모리 확인: Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory,TotalVisibleMemorySize"
    Write-Output "   4. 디스크 확인: Get-WmiObject -Class Win32_LogicalDisk"
    
    Write-Output ""
    Log-Info "최근 로그 (Backend):"
    try { docker-compose logs --tail=20 backend } catch {}
    
    Write-Output ""
    Log-Info "최근 로그 (Frontend):"
    try { docker-compose logs --tail=20 frontend } catch {}
}

# 도움말
function Show-Help {
    Write-Output "FriendlyI 전체 스택 배포 스크립트"
    Write-Output ""
    Write-Output "사용법: .\deploy-fullstack.ps1 [옵션]"
    Write-Output ""
    Write-Output "옵션:"
    Write-Output "  -Help           도움말 표시"
    Write-Output "  -BackendOnly    Backend만 배포"
    Write-Output "  -FrontendOnly   Frontend만 배포"
    Write-Output ""
    Write-Output "예시:"
    Write-Output "  .\deploy-fullstack.ps1          # 전체 스택 배포"
    Write-Output "  .\deploy-fullstack.ps1 -BackendOnly   # Backend만"
    Write-Output "  .\deploy-fullstack.ps1 -Help          # 도움말"
}

# 메인 실행 함수
function Main {
    $ErrorActionPreference = "Stop"
    
    try {
        if ($Help) {
            Show-Help
            return
        }
        
        if ($BackendOnly) {
            Log-Info "Backend만 배포하는 중..."
            Push-Location backend
            .\auto-deploy.ps1
            Pop-Location
            return
        }
        
        if ($FrontendOnly) {
            Log-Info "Frontend만 배포하는 중..."
            docker-compose up -d frontend
            return
        }
        
        Print-Banner
        
        Check-System
        Update-Repository
        Setup-Environment
        Check-Ports
        Cleanup-Docker
        Deploy-FullStack
        Check-Deployment
        Show-DeploymentInfo
        
        Log-Success "🚀 전체 스택 자동 배포 완료!"
        
    } catch {
        Handle-Error
        Write-Error "배포 실패: $_"
        exit 1
    }
}

# 스크립트 실행
Main