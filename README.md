# FriendlyI 예약 관리 시스템 🐤

Spring Boot 백엔드와 React 프론트엔드로 구성된 예약 관리 시스템입니다.

## 프로젝트 구조

```
I/
├── backend/           # Spring Boot API 서버
│   ├── backend/
│   │   ├── src/
│   │   ├── build.gradle
│   │   └── ...
└── frontend/          # React 웹 애플리케이션
    ├── src/
    │   ├── components/
    │   ├── pages/
    │   ├── api/
    │   └── types/
    ├── package.json
    └── ...
```

## 기능

### 🏆 회원 등급 시스템
- 🥚 알 (EGG) - 기본 등급
- 🐣 부화중 (HATCHING)
- 🐥 병아리 (CHICK)
- 🐤 어린새 (YOUNG_BIRD)
- 🐔 관리자 (ROOSTER)

### 📋 주요 기능
1. **회원 관리**: 회원 등록, 조회, 등급 관리
2. **예약 관리**: 달력 기반 예약 생성, 수정, 삭제
   - 📅 **달력 인터페이스**: 직관적인 달력 UI로 예약 관리
   - 🖱️ **클릭으로 예약 생성**: 달력의 빈 시간대 클릭으로 즉시 예약 생성
   - 👀 **예약 현황 시각화**: 예약 상태를 색상으로 구분 (가능/마감)
   - 📱 **반응형 달력**: 월/주/일 단위 보기 전환 가능
3. **신청 관리**: 예약 신청, 승인, 대기열 관리

## 실행 방법

### 백엔드 (Spring Boot)
```bash
cd backend/backend
./gradlew bootRun
```
백엔드 서버는 `http://localhost:8080`에서 실행됩니다.

### 프론트엔드 (React)
```bash
cd frontend
npm install  # 처음 실행 시에만
npm start
```
프론트엔드 서버는 `http://localhost:3000`에서 실행됩니다.

## API 문서

백엔드 서버 실행 후 Swagger UI에서 API 문서를 확인할 수 있습니다:
- URL: `http://localhost:8080/swagger-ui.html`

### 주요 API 엔드포인트

#### 회원 관리
- `GET /api/members` - 모든 회원 조회
- `POST /api/members` - 새 회원 생성
- `PUT /api/members/{id}/grade` - 회원 등급 변경
- `DELETE /api/members/{id}` - 회원 삭제

#### 예약 관리
- `GET /api/reservations` - 모든 예약 조회
- `POST /api/reservations` - 새 예약 생성
- `GET /api/reservations/available` - 예약 가능한 슬롯 조회
- `DELETE /api/reservations/{id}` - 예약 삭제

#### 신청 관리
- `POST /api/reservation-applications` - 예약 신청
- `GET /api/reservation-applications/member/{memberId}` - 회원별 신청 조회
- `PUT /api/reservation-applications/{id}/status` - 신청 상태 변경

## 기술 스택

### 백엔드
- **Spring Boot 3.x**
- **Java 17+**
- **JPA/Hibernate**
- **H2 Database** (개발용)
- **Swagger/OpenAPI 3**

### 프론트엔드
- **React 18**
- **TypeScript**
- **React Router**
- **React Query** (데이터 페칭)
- **React Hook Form** (폼 관리)
- **React Big Calendar** (달력 UI)
- **Moment.js** (날짜 처리)
- **Yup** (유효성 검증)
- **Axios** (HTTP 클라이언트)

## 개발 환경 설정

### 필수 요구사항
- **Java 17 이상**
- **Node.js 16 이상**
- **npm 또는 yarn**

### 환경 설정
1. 백엔드와 프론트엔드를 각각 별도의 터미널에서 실행
2. 프론트엔드는 `proxy` 설정으로 백엔드 API에 자동 연결
3. 개발 시 핫 리로드 지원

## 프로젝트 특징

### 🎨 UI/UX
- 반응형 디자인
- 직관적인 사용자 인터페이스
- 이모지를 활용한 친근한 디자인
- **📅 달력 기반 예약 시스템**
  - 월/주/일 단위 보기 전환
  - 드래그로 시간 선택
  - 예약 상태 색상 구분
  - 마우스 호버 효과

### 🔧 개발 편의성
- TypeScript로 타입 안전성 보장
- React Query로 서버 상태 관리
- Form 유효성 검증
- 에러 처리 및 로딩 상태 관리

### 🚀 확장 가능성
- 컴포넌트 기반 아키텍처
- 재사용 가능한 API 서비스
- 확장 가능한 상태 관리

## 트러블슈팅

### 자주 발생하는 문제
1. **포트 충돌**: 백엔드(8080), 프론트엔드(3000) 포트 확인
2. **CORS 오류**: 백엔드 CORS 설정 확인
3. **패키지 설치 오류**: `npm install` 또는 `yarn install` 재실행

### 개발 팁
- 백엔드를 먼저 실행한 후 프론트엔드 실행
- API 변경 시 타입 정의 업데이트
- React Query DevTools 활용 권장

## 라이선스

이 프로젝트는 학습 목적으로 제작되었습니다.