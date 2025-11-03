#!/bin/bash

# EC2 포트 연결 테스트 스크립트
echo "🔍 EC2 포트 연결 테스트..."

# EC2 외부 IP 가져오기
EC2_IP=$(curl -s http://checkip.amazonaws.com)
echo "EC2 외부 IP: $EC2_IP"

# 내부에서 포트 테스트
echo -e "\n📡 내부 포트 연결 테스트:"

# 프론트엔드 포트 테스트
if curl -s --connect-timeout 5 http://localhost:3000 > /dev/null; then
    echo "✅ 포트 3000 (프론트엔드): 내부 연결 성공"
else
    echo "❌ 포트 3000 (프론트엔드): 내부 연결 실패"
fi

# 백엔드 포트 테스트  
if curl -s --connect-timeout 5 http://localhost:8080/actuator/health > /dev/null; then
    echo "✅ 포트 8080 (백엔드): 내부 연결 성공"
else
    echo "❌ 포트 8080 (백엔드): 내부 연결 실패"
fi

echo -e "\n🌐 외부 접속 URL:"
echo "프론트엔드: http://$EC2_IP:3000"
echo "백엔드 API: http://$EC2_IP:8080/api"
echo "헬스체크: http://$EC2_IP:8080/actuator/health"

echo -e "\n💡 만약 내부 연결은 되지만 외부 연결이 안 된다면:"
echo "   → AWS 보안 그룹에서 포트 3000, 8080 인바운드 규칙을 추가하세요!"

echo -e "\n🔧 다음 명령어로 보안 그룹 추가하기:"
echo "   AWS 콘솔 → EC2 → 보안 그룹 → 인바운드 규칙 편집"
echo "   또는 AWS CLI: aws ec2 authorize-security-group-ingress ..."