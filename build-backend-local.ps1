# Backend 로컬 빌드 후 Docker 배포 스크립트 (PowerShell)

param(
    [switch]$SkipBuild = $false,
    [switch]$UseMinimal = $true
)

Write-Host "🔧 Backend 로컬 빌드 후 Docker 배포" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

try {
    # 현재 위치 확인
    $currentLocation = Get-Location
    Write-Host "현재 위치: $currentLocation" -ForegroundColor Gray

    # Backend 디렉토리로 이동
    if (-not (Test-Path "backend\backend\pom.xml")) {
        Write-Host "❌ backend/backend/pom.xml을 찾을 수 없습니다. 올바른 디렉토리에서 실행하세요." -ForegroundColor Red
        exit 1
    }

    Set-Location "backend\backend"
    Write-Host "✅ Backend 디렉토리로 이동: $(Get-Location)" -ForegroundColor Green

    if (-not $SkipBuild) {
        # 1. 로컬에서 Maven 빌드
        Write-Host "`n🔨 로컬 Maven 빌드 시작..." -ForegroundColor Yellow
        
        # JAVA_HOME 설정
        $env:JAVA_HOME = "C:\Users\linej\.jdks\ms-21.0.8"
        Write-Host "JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Gray
        
        # Maven 빌드 실행
        $buildCmd = ".\mvnw.cmd clean package -DskipTests -Dmaven.test.skip=true --quiet"
        Write-Host "빌드 명령: $buildCmd" -ForegroundColor Gray
        
        Invoke-Expression $buildCmd
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 로컬 Maven 빌드 성공!" -ForegroundColor Green
        } else {
            Write-Host "❌ 로컬 Maven 빌드 실패" -ForegroundColor Red
            Set-Location $currentLocation
            exit 1
        }

        # JAR 파일 확인
        $jarFile = Get-ChildItem "target\backend-*.jar" | Select-Object -First 1
        if ($jarFile) {
            Write-Host "✅ JAR 파일 생성됨: $($jarFile.Name) (크기: $([math]::Round($jarFile.Length/1MB, 1)) MB)" -ForegroundColor Green
        } else {
            Write-Host "❌ JAR 파일을 찾을 수 없습니다" -ForegroundColor Red
            Set-Location $currentLocation
            exit 1
        }
    } else {
        Write-Host "⏩ 빌드 건너뜀 (-SkipBuild 옵션)" -ForegroundColor Yellow
    }

    # 2. Docker 이미지 빌드
    Write-Host "`n🐳 Docker 이미지 빌드..." -ForegroundColor Yellow
    
    # 루트 디렉토리로 돌아가기
    Set-Location $currentLocation
    
    # 컨테이너 중지
    Write-Host "기존 Backend 컨테이너 중지 중..." -ForegroundColor Cyan
    docker-compose stop backend 2>$null
    docker-compose rm -f backend 2>$null

    if ($UseMinimal) {
        # 최소 Dockerfile 사용
        Write-Host "최소 Dockerfile 사용 중..." -ForegroundColor Cyan
        
        # 임시로 Dockerfile 교체
        if (Test-Path "backend\backend\Dockerfile.backup") {
            Remove-Item "backend\backend\Dockerfile.backup" -Force
        }
        Move-Item "backend\backend\Dockerfile" "backend\backend\Dockerfile.backup"
        Copy-Item "backend\backend\Dockerfile.minimal" "backend\backend\Dockerfile"
        
        # Docker 빌드
        $dockerBuild = docker-compose build --no-cache backend 2>&1
        
        # Dockerfile 복원
        Remove-Item "backend\backend\Dockerfile" -Force
        Move-Item "backend\backend\Dockerfile.backup" "backend\backend\Dockerfile"
        
    } else {
        # 기존 Dockerfile 사용
        $dockerBuild = docker-compose build --no-cache backend 2>&1
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker 이미지 빌드 성공!" -ForegroundColor Green
    } else {
        Write-Host "❌ Docker 이미지 빌드 실패:" -ForegroundColor Red
        Write-Host $dockerBuild -ForegroundColor Red
        exit 1
    }

    # 3. 데이터베이스 확인 및 시작
    Write-Host "`n💾 데이터베이스 상태 확인..." -ForegroundColor Cyan
    
    $dbContainers = docker ps --filter "name=postgres" --filter "name=redis" --format "{{.Names}} {{.Status}}"
    if ($dbContainers) {
        Write-Host "데이터베이스 컨테이너: $dbContainers" -ForegroundColor Gray
    } else {
        Write-Host "데이터베이스 시작 중..." -ForegroundColor Yellow
        docker-compose up -d postgres redis 2>$null
        Start-Sleep -Seconds 15
    }

    # 4. Backend 컨테이너 시작
    Write-Host "`n🚀 Backend 컨테이너 시작..." -ForegroundColor Yellow
    docker-compose up -d backend 2>$null

    # 5. 헬스체크 대기
    Write-Host "`n⏳ Backend 헬스체크 대기..." -ForegroundColor Cyan
    $timeout = 120
    $counter = 0
    $healthCheckPassed = $false

    while ($counter -lt $timeout -and -not $healthCheckPassed) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/actuator/health" -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $healthCheckPassed = $true
                Write-Host "✅ Backend 헬스체크 성공!" -ForegroundColor Green
                break
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        $counter++
        if ($counter % 10 -eq 0) {
            Write-Host "Backend 대기 중... ($counter/$timeout)" -ForegroundColor Cyan
        }
        Start-Sleep -Seconds 2
    }

    if (-not $healthCheckPassed) {
        Write-Host "⚠️ Backend 헬스체크 타임아웃" -ForegroundColor Yellow
        Write-Host "Backend 로그:" -ForegroundColor Yellow
        docker-compose logs --tail=20 backend
    }

    # 6. 최종 상태 확인
    Write-Host "`n🎉 Backend 배포 완료!" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    
    Write-Host "`n📊 컨테이너 상태:" -ForegroundColor Yellow
    docker-compose ps

    Write-Host "`n🌐 접속 정보:" -ForegroundColor Green
    Write-Host "- Backend API: http://localhost:8080" -ForegroundColor Cyan
    Write-Host "- Health Check: http://localhost:8080/actuator/health" -ForegroundColor Cyan
    Write-Host "- Swagger UI: http://localhost:8080/swagger-ui/" -ForegroundColor Cyan

    Write-Host "`n📋 디스크 사용량 최적화:" -ForegroundColor Yellow
    Write-Host "- 로컬 빌드로 Docker 빌드 디스크 사용량 최소화" -ForegroundColor White
    Write-Host "- JRE만 포함된 최소 런타임 이미지 사용" -ForegroundColor White
    Write-Host "- 빌드 캐시 및 임시 파일 정리" -ForegroundColor White

} catch {
    Write-Host "`n❌ 배포 중 오류 발생: $_" -ForegroundColor Red
} finally {
    # 원래 위치로 복귀
    Set-Location $currentLocation
}