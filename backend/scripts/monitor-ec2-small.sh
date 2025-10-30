#!/bin/bash

# EC2 Small Instance Resource Monitoring Script

echo "🔍 EC2 Small Instance Resource Monitor"
echo "======================================"

# System Information
echo "📊 System Resources:"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}') total, $(free -h | grep '^Mem:' | awk '{print $3}') used, $(free -h | grep '^Mem:' | awk '{print $7}') available"
echo "Swap: $(free -h | grep '^Swap:' | awk '{print $2}') total, $(free -h | grep '^Swap:' | awk '{print $3}') used"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}') total, $(df -h / | tail -1 | awk '{print $3}') used, $(df -h / | tail -1 | awk '{print $4}') available"
echo ""

# Load Average
echo "⚡ System Load:"
uptime
echo ""

# Docker Container Stats
if docker ps -q > /dev/null 2>&1; then
    echo "🐳 Docker Container Resources:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    echo ""
else
    echo "❌ Docker containers are not running"
    echo ""
fi

# Memory Usage by Process
echo "💾 Top Memory Consumers:"
ps aux --sort=-%mem | head -6
echo ""

# Check if services are healthy
echo "🏥 Service Health Check:"
if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
    echo "✅ Backend: Healthy"
    HEALTH_STATUS=$(curl -s http://localhost:8080/actuator/health | jq -r '.status' 2>/dev/null || echo "Unknown")
    echo "   Status: $HEALTH_STATUS"
else
    echo "❌ Backend: Not responding"
fi

if docker exec friendly-i-db pg_isready -U friendlyi_user > /dev/null 2>&1; then
    echo "✅ PostgreSQL: Healthy"
else
    echo "❌ PostgreSQL: Not responding"
fi

if docker exec friendly-i-redis redis-cli ping > /dev/null 2>&1; then
    echo "✅ Redis: Healthy"
else
    echo "❌ Redis: Not responding"
fi
echo ""

# Network connections
echo "🌐 Active Connections:"
ss -tuln | grep -E ':(8080|5432|6379)'
echo ""

# Disk I/O
echo "💽 Disk I/O:"
iostat -x 1 1 | tail -n +4
echo ""

# Warning thresholds
MEM_USAGE=$(free | grep '^Mem:' | awk '{print ($3/$2)*100}')
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

echo "⚠️  Resource Warnings:"
if (( $(echo "$MEM_USAGE > 85" | bc -l) )); then
    echo "🔴 HIGH MEMORY USAGE: ${MEM_USAGE}%"
else
    echo "🟢 Memory usage OK: ${MEM_USAGE}%"
fi

if [ "$DISK_USAGE" -gt 85 ]; then
    echo "🔴 HIGH DISK USAGE: ${DISK_USAGE}%"
else
    echo "🟢 Disk usage OK: ${DISK_USAGE}%"
fi

# Recommendations for EC2 Small
echo ""
echo "💡 EC2 Small Optimization Tips:"
echo "   - Memory limit per container enforced"
echo "   - Using SerialGC for lower CPU overhead"
echo "   - Connection pools reduced to minimum"
echo "   - File upload size limited to 3MB"
echo "   - Tomcat threads limited to 30"
echo ""
echo "🔄 To restart services: make small-rebuild"
echo "📊 To watch continuously: watch -n 5 ./scripts/monitor-ec2-small.sh"