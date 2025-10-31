# JVM Memory Configuration Recommendations for AWS EC2

## Instance Type별 권장 설정

### t3.micro (1GB RAM) - 테스트 환경
```yaml
environment:
  - JAVA_OPTS=-Xmx384m -Xms128m -XX:+UseSerialGC -XX:MaxRAMPercentage=50
```

### t3.small (2GB RAM) - 현재 설정
```yaml
environment:
  - JAVA_OPTS=-Xmx512m -Xms128m -XX:+UseSerialGC -XX:MaxRAMPercentage=60
```

### t3.medium (4GB RAM) - 권장 환경
```yaml
environment:
  - JAVA_OPTS=-Xmx1g -Xms256m -XX:+UseG1GC -XX:MaxRAMPercentage=70
```

### t3.large (8GB RAM) - 최적 환경
```yaml
environment:
  - JAVA_OPTS=-Xmx2g -Xms512m -XX:+UseG1GC -XX:MaxRAMPercentage=75
```

## 메모리 모니터링 임계값
- CPU: 80%
- Memory: 85%
- Disk: 90%
- Load Average: 2.0 (t3.small 기준)