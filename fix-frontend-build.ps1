# Frontend 문제 해결 및 재빌드 스크립트 (PowerShell)

Write-Host "🔧 Frontend npm 의존성 문제 해결 및 재빌드" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

try {
    # 1. 현재 상태 확인
    Write-Host "`n📋 현재 Docker 상태:" -ForegroundColor Yellow
    docker ps -a --filter "name=frontend" --format "table {{.Names}}\t{{.Status}}"

    # 2. 기존 이미지와 컨테이너 완전 정리
    Write-Host "`n🧹 기존 Frontend 리소스 정리 중..." -ForegroundColor Yellow
    
    # 컨테이너 중지 및 제거
    docker stop friendlyi-frontend-friendi 2>$null
    docker rm friendlyi-frontend-friendi 2>$null
    
    # 이미지 제거 (강제)
    $frontendImages = docker images --filter "reference=*frontend*" --format "{{.ID}}"
    if ($frontendImages) {
        Write-Host "기존 Frontend 이미지 제거 중..." -ForegroundColor Cyan
        $frontendImages | ForEach-Object { docker rmi -f $_ 2>$null }
    }
    
    # 빌드 캐시 정리
    Write-Host "Docker 빌드 캐시 정리 중..." -ForegroundColor Cyan
    docker builder prune -f 2>$null
    
    Write-Host "✅ 리소스 정리 완료" -ForegroundColor Green

    # 3. Frontend 디렉토리로 이동 및 npm 캐시 정리 (로컬에서)
    Write-Host "`n📦 로컬 npm 캐시 정리..." -ForegroundColor Yellow
    Push-Location "frontend"
    
    if (Test-Path "node_modules") {
        Remove-Item -Recurse -Force "node_modules" -ErrorAction SilentlyContinue
        Write-Host "node_modules 폴더 제거됨" -ForegroundColor Cyan
    }
    
    if (Test-Path "package-lock.json") {
        Remove-Item "package-lock.json" -ErrorAction SilentlyContinue
        Write-Host "package-lock.json 제거됨" -ForegroundColor Cyan
    }
    
    Pop-Location
    Write-Host "✅ 로컬 캐시 정리 완료" -ForegroundColor Green

    # 4. 새로운 이미지 빌드 시도
    Write-Host "`n🔨 Frontend 이미지 새로 빌드 중..." -ForegroundColor Yellow
    Write-Host "이 과정은 몇 분이 소요될 수 있습니다..." -ForegroundColor Gray
    
    $buildOutput = docker-compose build --no-cache --pull frontend 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Frontend 이미지 빌드 성공!" -ForegroundColor Green
    } else {
        Write-Host "❌ 빌드 실패. 세부 내용:" -ForegroundColor Red
        Write-Host $buildOutput -ForegroundColor Red
        
        # 대체 빌드 방법 시도
        Write-Host "`n🔄 대체 빌드 방법 시도 중..." -ForegroundColor Yellow
        
        # Dockerfile을 더 간단한 버전으로 임시 수정
        $tempDockerfile = @"
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --legacy-peer-deps --no-optional
COPY . .
ENV CI=false
ENV GENERATE_SOURCEMAP=false
RUN npm run build:safe

FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
"@
        
        $tempDockerfile | Out-File -FilePath "frontend/Dockerfile.temp" -Encoding UTF8
        
        # 임시 Dockerfile로 빌드
        Push-Location "frontend"
        $simpleBuild = docker build -f Dockerfile.temp -t friendlyi-frontend . 2>&1
        Pop-Location
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 간단한 빌드 성공!" -ForegroundColor Green
            
            # docker-compose.yml에서 이미지 태그 업데이트
            $composeContent = Get-Content "docker-compose.yml" -Raw
            $composeContent = $composeContent -replace "build:\s*\.\s*/frontend", "image: friendlyi-frontend"
            $composeContent | Out-File -FilePath "docker-compose.yml" -Encoding UTF8
            
        } else {
            Write-Host "❌ 대체 빌드도 실패" -ForegroundColor Red
            Write-Host $simpleBuild -ForegroundColor Red
            throw "모든 빌드 방법 실패"
        }
    }

    # 5. 컨테이너 시작
    Write-Host "`n🚀 Frontend 컨테이너 시작 중..." -ForegroundColor Yellow
    $startResult = docker-compose up -d frontend 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Frontend 컨테이너 시작 성공!" -ForegroundColor Green
    } else {
        Write-Host "❌ 컨테이너 시작 실패:" -ForegroundColor Red
        Write-Host $startResult -ForegroundColor Red
        throw "컨테이너 시작 실패"
    }

    # 6. 헬스체크 대기
    Write-Host "`n⏳ Frontend 서비스 헬스체크 중..." -ForegroundColor Cyan
    
    $timeout = 120
    $counter = 0
    $healthCheckPassed = $false
    
    while ($counter -lt $timeout -and -not $healthCheckPassed) {
        Start-Sleep -Seconds 3
        $counter += 3
        
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $healthCheckPassed = $true
                Write-Host "✅ Frontend 헬스체크 성공!" -ForegroundColor Green
                break
            }
        } catch {
            # 아직 준비되지 않음
        }
        
        Write-Host "헬스체크 대기 중... ($counter/$timeout 초)" -ForegroundColor Cyan
        
        # 중간에 로그 체크
        if ($counter % 30 -eq 0) {
            Write-Host "현재 로그 상태:" -ForegroundColor Gray
            docker logs friendlyi-frontend-friendi --tail 5 2>$null | Write-Host -ForegroundColor Gray
        }
    }
    
    if (-not $healthCheckPassed) {
        Write-Host "⚠️ 헬스체크 타임아웃 - 수동 확인 필요" -ForegroundColor Yellow
        Write-Host "컨테이너 로그:" -ForegroundColor Gray
        docker logs friendlyi-frontend-friendi --tail 20
    }

    # 7. 최종 상태 확인
    Write-Host "`n📊 최종 상태 확인:" -ForegroundColor Green
    Write-Host "===================" -ForegroundColor Green
    
    docker ps --filter "name=frontend" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    Write-Host "`n🌐 접속 정보:" -ForegroundColor Cyan
    Write-Host "- Frontend: http://localhost:3000" -ForegroundColor White
    Write-Host "- Health Check: curl http://localhost:3000" -ForegroundColor White
    
    Write-Host "`n✅ Frontend 재빌드 완료!" -ForegroundColor Green

} catch {
    Write-Host "`n❌ 재빌드 중 오류 발생: $_" -ForegroundColor Red
    Write-Host "`n🔍 추가 디버깅:" -ForegroundColor Yellow
    Write-Host "1. docker logs friendlyi-frontend-friendi" -ForegroundColor White
    Write-Host "2. docker-compose logs frontend" -ForegroundColor White
    Write-Host "3. docker images | grep frontend" -ForegroundColor White
}