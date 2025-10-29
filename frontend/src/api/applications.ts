import api from './client';
import { ReservationApplication, ReservationApplicationRequest, ReservationStatus } from '../types';

export const applicationService = {
  // 예약 신청
  applyForReservation: async (data: ReservationApplicationRequest): Promise<ReservationApplication> => {
    const response = await api.post('/reservation-applications', data);
    return response.data;
  },

  // 회원별 신청 조회
  getApplicationsByMember: async (memberId: number): Promise<ReservationApplication[]> => {
    const response = await api.get(`/reservation-applications/member/${memberId}`);
    return response.data;
  },

  // 예약별 신청 조회
  getApplicationsByReservation: async (reservationId: number): Promise<ReservationApplication[]> => {
    const response = await api.get(`/reservation-applications/reservation/${reservationId}`);
    return response.data;
  },

  // 신청 취소
  cancelApplication: async (applicationId: number): Promise<void> => {
    await api.delete(`/reservation-applications/${applicationId}`);
  },

  // 신청 상태 변경 (관리자)
  updateApplicationStatus: async (applicationId: number, status: ReservationStatus): Promise<ReservationApplication> => {
    const response = await api.put(`/reservation-applications/${applicationId}/status`, null, {
      params: { status }
    });
    return response.data;
  }
};