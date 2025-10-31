#!/bin/bash

# EC2 Monitoring Script for FriendlyI
# Monitors system resources, service health, and performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LOG_FILE="./logs/monitoring.log"
ALERT_EMAIL=""  # Set your email for alerts
HEALTH_CHECK_URL="http://localhost:8080/actuator/health"
FRONTEND_URL="http://localhost:80"

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOAD_THRESHOLD=2.0

echo_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo_header() {
    echo -e "${MAGENTA}=== $1 ===${NC}"
}

# Function to log with timestamp
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to check system resources
check_system_resources() {
    echo_header "시스템 리소스 상태"
    
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        echo_error "CPU 사용률이 높습니다: ${cpu_usage}%"
        log_message "ERROR" "High CPU usage: ${cpu_usage}%"
    else
        echo_success "CPU 사용률: ${cpu_usage}%"
    fi
    
    # Memory Usage
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$(echo "scale=1; $used_mem * 100 / $total_mem" | bc 2>/dev/null || echo "0")
    
    if (( $(echo "$memory_usage > $MEMORY_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        echo_error "메모리 사용률이 높습니다: ${memory_usage}%"
        log_message "ERROR" "High memory usage: ${memory_usage}%"
    else
        echo_success "메모리 사용률: ${memory_usage}%"
    fi
    
    # Disk Usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        echo_error "디스크 사용률이 높습니다: ${disk_usage}%"
        log_message "ERROR" "High disk usage: ${disk_usage}%"
    else
        echo_success "디스크 사용률: ${disk_usage}%"
    fi
    
    # Load Average
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
    if (( $(echo "$load_avg > $LOAD_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        echo_warning "시스템 로드가 높습니다: $load_avg"
        log_message "WARNING" "High system load: $load_avg"
    else
        echo_success "시스템 로드: $load_avg"
    fi
    
    # Swap Usage
    local swap_info=$(free | grep Swap)
    if echo "$swap_info" | grep -q "0.*0.*0"; then
        echo_info "스왑이 설정되지 않았습니다."
    else
        local total_swap=$(echo $swap_info | awk '{print $2}')
        local used_swap=$(echo $swap_info | awk '{print $3}')
        if [ "$total_swap" -gt 0 ]; then
            local swap_usage=$(echo "scale=1; $used_swap * 100 / $total_swap" | bc 2>/dev/null || echo "0")
            echo_info "스왑 사용률: ${swap_usage}%"
        fi
    fi
    
    echo
}

# Function to check Docker services
check_docker_services() {
    echo_header "Docker 서비스 상태"
    
    if ! command -v docker &> /dev/null; then
        echo_error "Docker가 설치되지 않았습니다."
        return 1
    fi
    
    # Docker daemon status
    if ! docker info &> /dev/null; then
        echo_error "Docker 데몬이 실행되지 않고 있습니다."
        log_message "ERROR" "Docker daemon is not running"
        return 1
    fi
    
    echo_success "Docker 데몬이 실행 중입니다."
    
    # Container status
    local containers=$(docker-compose ps -q 2>/dev/null || echo "")
    if [ -z "$containers" ]; then
        echo_warning "실행 중인 컨테이너가 없습니다."
        return 1
    fi
    
    echo_info "컨테이너 상태:"
    docker-compose ps
    
    # Container resource usage
    echo_info "컨테이너 리소스 사용량:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    echo
}

# Function to check service health
check_service_health() {
    echo_header "서비스 Health Check"
    
    # Backend health check
    if curl -f -s "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        echo_success "백엔드 서비스가 정상입니다."
        
        # Get detailed health info
        local health_response=$(curl -s "$HEALTH_CHECK_URL" 2>/dev/null || echo "{}")
        if command -v jq &> /dev/null; then
            echo_info "Health Check 상세 정보:"
            echo "$health_response" | jq . 2>/dev/null || echo "$health_response"
        fi
    else
        echo_error "백엔드 서비스가 응답하지 않습니다."
        log_message "ERROR" "Backend service is not responding"
    fi
    
    # Frontend health check
    if curl -f -s "$FRONTEND_URL" > /dev/null 2>&1; then
        echo_success "프론트엔드 서비스가 정상입니다."
    else
        echo_error "프론트엔드 서비스가 응답하지 않습니다."
        log_message "ERROR" "Frontend service is not responding"
    fi
    
    echo
}

# Function to check logs for errors
check_logs_for_errors() {
    echo_header "최근 로그 오류 검사"
    
    # Check application logs
    if [ -f "./logs/application.log" ]; then
        local error_count=$(tail -100 ./logs/application.log | grep -i "error\|exception\|failed" | wc -l)
        if [ "$error_count" -gt 0 ]; then
            echo_warning "애플리케이션 로그에서 ${error_count}개의 오류를 발견했습니다."
            echo_info "최근 오류:"
            tail -100 ./logs/application.log | grep -i "error\|exception\|failed" | tail -5
        else
            echo_success "애플리케이션 로그에 오류가 없습니다."
        fi
    fi
    
    # Check Docker logs for errors
    if docker-compose ps -q &> /dev/null; then
        echo_info "Docker 컨테이너 로그 확인 중..."
        for container in $(docker-compose ps --services); do
            local container_errors=$(docker-compose logs --tail=50 "$container" 2>/dev/null | grep -i "error\|exception\|failed" | wc -l)
            if [ "$container_errors" -gt 0 ]; then
                echo_warning "$container 컨테이너에서 ${container_errors}개의 오류를 발견했습니다."
            else
                echo_success "$container 컨테이너 로그가 정상입니다."
            fi
        done
    fi
    
    echo
}

# Function to check network connectivity
check_network() {
    echo_header "네트워크 연결성 검사"
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo_success "인터넷 연결이 정상입니다."
    else
        echo_error "인터넷 연결에 문제가 있습니다."
        log_message "ERROR" "Internet connectivity issue"
    fi
    
    # Check DNS resolution
    if nslookup google.com &> /dev/null; then
        echo_success "DNS 해석이 정상입니다."
    else
        echo_warning "DNS 해석에 문제가 있을 수 있습니다."
    fi
    
    # Check port availability
    local ports=(80 8080 22)
    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":${port} "; then
            echo_success "포트 ${port}이 사용 중입니다."
        else
            echo_warning "포트 ${port}이 사용되지 않고 있습니다."
        fi
    done
    
    echo
}

# Function to show system information
show_system_info() {
    echo_header "시스템 정보"
    
    echo_info "서버 정보:"
    echo "  - 호스트명: $(hostname)"
    echo "  - OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || uname -s)"
    echo "  - 커널: $(uname -r)"
    echo "  - 업타임: $(uptime -p 2>/dev/null || uptime)"
    
    echo
    echo_info "하드웨어 정보:"
    echo "  - CPU: $(nproc) cores"
    echo "  - 메모리: $(free -h | grep Mem | awk '{print $2}')"
    echo "  - 디스크: $(df -h / | awk 'NR==2 {print $2}')"
    
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_c=$((temp / 1000))
        echo "  - CPU 온도: ${temp_c}°C"
    fi
    
    echo
    echo_info "Docker 정보:"
    if command -v docker &> /dev/null; then
        echo "  - Docker 버전: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
        echo "  - Docker Compose 버전: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1 2>/dev/null || echo "V2")"
        echo "  - 실행 중인 컨테이너: $(docker ps -q | wc -l)"
        echo "  - 전체 이미지: $(docker images -q | wc -l)"
    else
        echo "  - Docker: 설치되지 않음"
    fi
    
    echo
}

# Function to generate performance report
generate_performance_report() {
    local report_file="./logs/performance_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo_info "성능 리포트를 생성합니다: $report_file"
    
    {
        echo "FriendlyI Performance Report - $(date)"
        echo "================================================"
        echo
        
        echo "System Resources:"
        free -h
        echo
        
        echo "Disk Usage:"
        df -h
        echo
        
        echo "Network Statistics:"
        ss -tuln
        echo
        
        echo "Process List (Top 10 by CPU):"
        ps aux --sort=-%cpu | head -11
        echo
        
        echo "Process List (Top 10 by Memory):"
        ps aux --sort=-%mem | head -11
        echo
        
        if command -v docker &> /dev/null; then
            echo "Docker Container Stats:"
            docker stats --no-stream
            echo
            
            echo "Docker Container Processes:"
            docker-compose top 2>/dev/null || true
            echo
        fi
        
        echo "Recent System Log (Last 20 lines):"
        journalctl -n 20 --no-pager 2>/dev/null || tail -20 /var/log/syslog 2>/dev/null || echo "Log not accessible"
        
    } > "$report_file"
    
    echo_success "성능 리포트가 생성되었습니다: $report_file"
}

# Function to watch real-time monitoring
watch_monitoring() {
    echo_info "실시간 모니터링을 시작합니다. Ctrl+C로 종료하세요."
    
    while true; do
        clear
        echo_header "FriendlyI 실시간 모니터링 - $(date)"
        
        check_system_resources
        check_docker_services
        check_service_health
        
        echo_info "새로고침: 30초 후 (Ctrl+C로 종료)"
        sleep 30
    done
}

# Function to show usage
show_usage() {
    echo "사용법: $0 [옵션]"
    echo
    echo "옵션:"
    echo "  -w, --watch     실시간 모니터링 모드"
    echo "  -r, --report    성능 리포트 생성"
    echo "  -l, --logs      로그 오류 검사만 실행"
    echo "  -n, --network   네트워크 검사만 실행"
    echo "  -s, --system    시스템 정보만 표시"
    echo "  -h, --help      이 도움말 표시"
    echo
    echo "예시:"
    echo "  $0              # 전체 모니터링 실행"
    echo "  $0 --watch      # 실시간 모니터링"
    echo "  $0 --report     # 성능 리포트 생성"
}

# Main function
main() {
    # Create logs directory if not exists
    mkdir -p logs
    
    case "${1:-}" in
        "-w"|"--watch")
            watch_monitoring
            ;;
        "-r"|"--report")
            generate_performance_report
            ;;
        "-l"|"--logs")
            check_logs_for_errors
            ;;
        "-n"|"--network")
            check_network
            ;;
        "-s"|"--system")
            show_system_info
            ;;
        "-h"|"--help")
            show_usage
            ;;
        "")
            echo_header "FriendlyI EC2 모니터링 - $(date)"
            show_system_info
            check_system_resources
            check_docker_services
            check_service_health
            check_logs_for_errors
            check_network
            echo_success "모니터링 완료!"
            ;;
        *)
            echo_error "알 수 없는 옵션: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Change to script directory and run main function
cd "$SCRIPT_DIR"
main "$@"
