export enum MemberGrade {
  EGG = 'EGG',
  HATCHING = 'HATCHING',
  CHICK = 'CHICK',
  YOUNG_BIRD = 'YOUNG_BIRD',
  ROOSTER = 'ROOSTER'
}

export interface Member {
  id: number;
  loginId: string;
  name: string;
  email: string;
  phoneNumber: string;
  grade: MemberGrade;
  createdAt: string;
  updatedAt: string;
}

export interface MemberCreateRequest {
  loginId: string;
  password: string;
  name: string;
  email: string;
  phoneNumber: string;
}

export interface MemberResponse {
  id: number;
  loginId: string;
  name: string;
  email: string;
  phoneNumber: string;
  grade: MemberGrade;
  createdAt: string;
  updatedAt: string;
}

export enum ReservationStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  WAITING = 'WAITING',
  CANCELLED = 'CANCELLED'
}

// 예약 신청자 정보
export interface ReservationApplicant {
  applicationId: number; // 신청 ID (취소용)
  memberId: number;
  memberName: string;
  memberLoginId: string;
  status: ReservationStatus;
  appliedAt: string;
  creator: boolean;
}

// Location 관련 타입들
export interface LocationSummary {
  id: number;
  name: string;
  address?: string;
  url: string;
  isActive: boolean;
}

export interface Location {
  id: number;
  name: string;
  address?: string;
  url: string;
  description?: string;
  isActive: boolean;
  activeReservationCount?: number;
  createdAt: string;
  updatedAt: string;
}

export interface LocationCreateRequest {
  name: string;
  address: string;
  description?: string;
}

export interface Reservation {
  id: number;
  title: string;
  description: string;
  location: LocationSummary; // 장소 정보
  maxCapacity: number;
  reservationDate: string; // LocalDate as string
  reservationTime: string; // LocalTime as string
  confirmedCount: number;
  waitingCount: number;
  availableSlots: number;
  isFullyBooked: boolean;
  createdAt: string;
  updatedAt: string;
  creatorId: number;      // 예약 생성자의 member ID
  creatorName?: string;   // 선택: 백엔드에서 함께 내려줄 경우 대비
}

export interface LocationInfo {
  name: string;
  address?: string;
  url: string;
}

export interface ReservationCreateRequest {
  creatorMemberId: number;
  title: string;
  description: string;
  locations: LocationInfo[];
  maxCapacity: number;
  reservationDate: string;
  reservationTime: string;
}

export interface ReservationApplication {
  id: number;
  memberId: number;
  reservationId: number;
  status: ReservationStatus;
  appliedAt: string;
  memberName?: string;
  reservationTitle?: string;
}

export interface ReservationApplicationRequest {
  memberId: number;
  reservationId: number;
}

// 인증 관련 타입
export interface User {
  id: number;
  loginId: string;
  name: string;
  email: string;
  phoneNumber: string;
  grade: MemberGrade;
  role?: string; // 사용자 역할 (ADMIN, USER 등)
  createdAt: string;
  updatedAt: string;
}

export interface LoginRequest {
  loginId: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: User;
}

export interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  login: (loginRequest: LoginRequest) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
}

export const GRADE_INFO = {
  [MemberGrade.EGG]: {
    emoji: '🥚',
    description: '알',
    level: 1,
    color: 'grade-egg'
  },
  [MemberGrade.HATCHING]: {
    emoji: '🐣',
    description: '부화중',
    level: 2,
    color: 'grade-hatching'
  },
  [MemberGrade.CHICK]: {
    emoji: '🐥',
    description: '병아리',
    level: 3,
    color: 'grade-chick'
  },
  [MemberGrade.YOUNG_BIRD]: {
    emoji: '🐤',
    description: '어린새',
    level: 4,
    color: 'grade-young-bird'
  },
  [MemberGrade.ROOSTER]: {
    emoji: '🐔',
    description: '관리자',
    level: 5,
    color: 'grade-rooster'
  }
};

export interface MemberStats {
  totalParticipations: number;
  completedReservations: number;
  canceledReservations: number;
  waitingReservations: number;
  joinDate: string;
  participationRate: number;
}