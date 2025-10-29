// React Query 설정
export const queryConfig = {
  // 예약 관련 쿼리 설정
  reservations: {
    staleTime: 30 * 1000, // 30초 후 stale로 간주
    cacheTime: 5 * 60 * 1000, // 5분간 캐시 유지
    refetchOnWindowFocus: true, // 윈도우 포커스 시 자동 refetch
    refetchOnMount: true, // 마운트 시 자동 refetch
  },
  
  // 예약 신청자 관련 쿼리 설정
  applicants: {
    staleTime: 10 * 1000, // 10초 후 stale로 간주 (더 자주 업데이트)
    cacheTime: 2 * 60 * 1000, // 2분간 캐시 유지
    refetchOnWindowFocus: true,
    refetchOnMount: true,
  }
};

// 캐시 키 상수
export const CACHE_KEYS = {
  reservations: 'reservations',
  availableReservations: 'available-reservations',
  futureReservations: 'future-reservations',
  reservationApplicants: (reservationId: number) => ['reservation-applicants', reservationId],
  members: 'members',
  memberStats: (memberId: number) => ['member-stats', memberId],
} as const;