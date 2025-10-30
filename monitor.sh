#!/bin/bash
# EC2 모니터링 스크립트

echo "📊 FriendlyI 시스템 모니터링"
echo "=============================="

while true; do
    clear
    echo "📊 FriendlyI 시스템 모니터링 - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================="
    echo
    
    # 시스템 리소스
    echo "💻 시스템 리소스:"
    echo "   CPU: $(nproc) cores"
    MEM_TOTAL=$(free -h | grep '^Mem:' | awk '{print $2}')
    MEM_USED=$(free -h | grep '^Mem:' | awk '{print $3}')
    MEM_AVAIL=$(free -h | grep '^Mem:' | awk '{print $7}')
    echo "   메모리: $MEM_USED / $MEM_TOTAL (사용가능: $MEM_AVAIL)"
    
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
    DISK_AVAIL=$(df -h / | tail -1 | awk '{print $4}')
    echo "   디스크: $DISK_USAGE 사용 ($DISK_AVAIL 여유)"
    echo
    
    # 로드 평균
    echo "⚡ 시스템 부하:"
    uptime | sed 's/.*load average:/   부하 평균:/'
    echo
    
    # Docker 컨테이너 상태
    echo "🐳 Docker 컨테이너:"
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 | grep -q .; then
        docker ps --format "   {{.Names}}: {{.Status}}"
    else
        echo "   실행 중인 컨테이너 없음"
    fi
    echo
    
    # Docker 리소스 사용량
    echo "📈 컨테이너 리소스 사용량:"
    docker stats --no-stream --format "   {{.Name}}: CPU {{.CPUPerc}} | 메모리 {{.MemUsage}}" 2>/dev/null | head -5
    echo
    
    # 애플리케이션 상태
    echo "🏥 애플리케이션 헬스체크:"
    if curl -s http://localhost:8080/actuator/health >/dev/null 2>&1; then
        HEALTH_STATUS=$(curl -s http://localhost:8080/actuator/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "UP")
        echo "   ✅ Backend: 정상 ($HEALTH_STATUS)"
    else
        echo "   ❌ Backend: 응답 없음"
    fi
    
    # PostgreSQL 상태 확인
    if docker exec friendly-i-db pg_isready -U friendlyi_user >/dev/null 2>&1; then
        echo "   ✅ PostgreSQL: 정상"
    else
        echo "   ❌ PostgreSQL: 응답 없음"
    fi
    
    # Redis 상태 확인
    if docker exec friendly-i-redis redis-cli ping >/dev/null 2>&1; then
        echo "   ✅ Redis: 정상"
    else
        echo "   ❌ Redis: 응답 없음"
    fi
    echo
    
    # 네트워크 연결
    echo "🌐 네트워크 연결:"
    ACTIVE_CONNS=$(ss -tuln | grep -E ':(8080|5432|6379)' | wc -l)
    echo "   활성 연결: $ACTIVE_CONNS개"
    ss -tuln | grep -E ':(8080|5432|6379)' | sed 's/^/   /'
    echo
    
    # 최근 로그 (에러만)
    echo "📝 최근 에러 로그:"
    if docker-compose -f docker-compose.small.yml logs --tail=3 backend 2>/dev/null | grep -i error; then
        echo "   에러 발견됨 (상세 로그 확인 필요)"
    else
        echo "   ✅ 최근 에러 없음"
    fi
    echo
    
    # 경고 알림
    MEM_PERCENT=$(free | grep '^Mem:' | awk '{print int($3/$2*100)}')
    if [ $MEM_PERCENT -gt 85 ]; then
        echo "🔴 경고: 메모리 사용률 높음 ($MEM_PERCENT%)"
    fi
    
    DISK_PERCENT=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $DISK_PERCENT -gt 85 ]; then
        echo "🔴 경고: 디스크 사용률 높음 ($DISK_PERCENT%)"
    fi
    echo
    
    echo "💡 명령어: [Ctrl+C] 종료 | [s] 서비스 재시작 | [l] 로그 확인"
    echo "⏰ 10초 후 자동 갱신..."
    
    # 사용자 입력 대기 (10초 타임아웃)
    read -t 10 -n 1 input || true
    
    case $input in
        s|S)
            echo "🔄 서비스 재시작 중..."
            docker-compose -f docker-compose.small.yml restart 2>/dev/null || docker-compose restart
            sleep 3
            ;;
        l|L)
            echo "📋 최근 로그 (20줄):"
            docker-compose -f docker-compose.small.yml logs --tail=20 2>/dev/null || docker-compose logs --tail=20
            read -p "아무 키나 누르면 계속..."
            ;;
    esac
done