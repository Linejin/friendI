#!/bin/bash
# EC2 PostgreSQL 문제 해결 스크립트

echo "🔍 PostgreSQL 컨테이너 문제 진단 중..."

# 1. 현재 상태 확인
echo "=== 컨테이너 상태 ==="
docker-compose ps

# 2. PostgreSQL 로그 확인
echo -e "\n=== PostgreSQL 로그 (최근 50줄) ==="
docker-compose logs --tail=50 postgres

# 3. 시스템 리소스 확인
echo -e "\n=== 시스템 리소스 ==="
echo "메모리 사용률:"
free -h
echo -e "\n디스크 사용률:"
df -h
echo -e "\n포트 사용 확인:"
netstat -tlnp | grep -E "(5432|5433)"

# 4. Docker 볼륨 상태 확인
echo -e "\n=== Docker 볼륨 ==="
docker volume ls | grep friendlyi
echo -e "\nPostgreSQL 데이터 볼륨 정보:"
docker volume inspect friendlyi-postgres-data

# 5. 문제 해결 시도
echo -e "\n🛠️ 문제 해결 시도 중..."

# PostgreSQL 컨테이너 강제 정리
echo "PostgreSQL 컨테이너 정리 중..."
docker-compose stop postgres
docker-compose rm -f postgres

# 볼륨 권한 문제 해결
echo "볼륨 권한 설정 중..."
docker volume rm friendlyi-postgres-data 2>/dev/null || true

# 메모리 정리
echo "시스템 캐시 정리 중..."
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' || true

# PostgreSQL만 다시 시작
echo "PostgreSQL 컨테이너 재시작 중..."
docker-compose up -d postgres

# 30초 대기 후 상태 확인
echo "PostgreSQL 시작 대기 중... (30초)"
sleep 30

echo -e "\n=== PostgreSQL 헬스체크 ==="
docker-compose ps postgres
docker-compose logs --tail=20 postgres

# 헬스체크
if docker-compose ps postgres | grep -q "healthy"; then
    echo "✅ PostgreSQL이 정상적으로 시작되었습니다!"
    
    # 다른 서비스들 시작
    echo "다른 서비스들을 시작합니다..."
    docker-compose up -d
    
    echo -e "\n🎉 전체 서비스 시작 완료!"
    docker-compose ps
else
    echo "❌ PostgreSQL 시작에 실패했습니다."
    echo -e "\n최근 PostgreSQL 로그:"
    docker-compose logs --tail=30 postgres
    
    echo -e "\n💡 추가 해결 방법:"
    echo "1. EC2 인스턴스 재시작: sudo reboot"
    echo "2. Docker 재시작: sudo systemctl restart docker"
    echo "3. 메모리 부족시 swap 추가"
    echo "4. 더 큰 EC2 인스턴스로 업그레이드"
fi