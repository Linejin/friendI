# EC2 보안 그룹 설정 가이드

## 🚨 ERR_CONNECTION_REFUSED 해결 방법

### 1. AWS 콘솔에서 보안 그룹 설정 (가장 중요!)

1. **AWS 콘솔 접속** → EC2 → 인스턴스 선택
2. **보안 탭** → 보안 그룹 클릭
3. **인바운드 규칙** → 편집 클릭
4. **다음 규칙들을 추가**:

```
포트 범위    프로토콜    소스        설명
22          TCP        0.0.0.0/0   SSH 접속
3000        TCP        0.0.0.0/0   프론트엔드 (React)
8080        TCP        0.0.0.0/0   백엔드 API (Spring Boot)
5432        TCP        VPC 내부     PostgreSQL (선택사항)
6379        TCP        VPC 내부     Redis (선택사항)
```

### 2. EC2에서 진단 스크립트 실행

```bash
# 진단 스크립트 실행 권한 부여
chmod +x diagnose-ec2.sh

# 진단 실행
./diagnose-ec2.sh
```

### 3. 컨테이너가 죽어있는 경우 재시작

```bash
# 모든 컨테이너 재시작
sudo docker-compose -f docker-compose.minimal.yml down
sudo docker-compose -f docker-compose.minimal.yml up -d

# 또는 강제 재빌드
./rebuild-ec2.sh
```

### 4. 방화벽 설정 확인 및 해제 (필요시)

```bash
# 방화벽 상태 확인
sudo ufw status

# 방화벽이 활성화되어 있다면 포트 허용
sudo ufw allow 3000
sudo ufw allow 8080

# 또는 방화벽 완전 비활성화 (테스트용)
sudo ufw disable
```

### 5. 일반적인 문제 해결 순서

1. **보안 그룹 설정** (가장 중요!)
2. **컨테이너 상태 확인** (`docker ps`)  
3. **포트 바인딩 확인** (`netstat -tulpn`)
4. **컨테이너 로그 확인** (`docker logs`)
5. **메모리 부족 확인** (`free -h`)

### 6. 접속 URL

수정 후 접속 주소:
- **프론트엔드**: `http://3.37.213.198:3000`
- **백엔드 API**: `http://3.37.213.198:8080/api`
- **헬스체크**: `http://3.37.213.198:8080/actuator/health`

---

## 🔧 빠른 해결 체크리스트

- [ ] AWS 보안 그룹에 포트 3000, 8080 인바운드 규칙 추가
- [ ] `docker ps`로 컨테이너 실행 상태 확인
- [ ] `./diagnose-ec2.sh`로 종합 진단 실행
- [ ] 필요시 `./rebuild-ec2.sh`로 컨테이너 재빌드
- [ ] 브라우저에서 `http://3.37.213.198:3000` 접속 테스트