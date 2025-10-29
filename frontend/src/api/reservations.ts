import api from './client';
import { Reservation, ReservationCreateRequest, ReservationApplicant } from '../types';

export const reservationService = {
  // 모든 예약 조회
  getAllReservations: async (): Promise<Reservation[]> => {
    const response = await api.get('/reservations');
    return response.data;
  },

  // 예약 ID로 조회
  getReservationById: async (id: number): Promise<Reservation> => {
    const response = await api.get(`/reservations/${id}`);
    return response.data;
  },

  // 날짜별 예약 조회
  getReservationsByDate: async (date: string): Promise<Reservation[]> => {
    const response = await api.get(`/reservations/date/${date}`);
    return response.data;
  },

  // 예약 가능한 예약 조회
  getAvailableReservations: async (): Promise<Reservation[]> => {
    const response = await api.get('/reservations/available');
    return response.data;
  },

  // 미래 예약 조회
  getFutureReservations: async (): Promise<Reservation[]> => {
    const response = await api.get('/reservations/future');
    return response.data;
  },

  // 새 예약 생성
  createReservation: async (data: ReservationCreateRequest): Promise<Reservation> => {
    const response = await api.post('/reservations', data);
    return response.data;
  },

  // 예약 수정
  updateReservation: async (id: number, data: ReservationCreateRequest): Promise<Reservation> => {
    const response = await api.put(`/reservations/${id}`, data);
    return response.data;
  },

  // 예약 삭제
  deleteReservation: async (id: number): Promise<void> => {
    await api.delete(`/reservations/${id}`);
  },

  // 예약 신청자 목록 조회
  getReservationApplicants: async (id: number): Promise<ReservationApplicant[]> => {
    const response = await api.get(`/reservations/${id}/applicants`);
    return response.data;
  },

  // 예약 참가 신청
  applyForReservation: async (reservationId: number, memberId: number): Promise<any> => {
    const response = await api.post('/reservation-applications', {
      reservationId,
      memberId
    });
    return response.data;
  },

  // 예약 참가 취소
  cancelReservationApplication: async (applicationId: number): Promise<void> => {
    await api.delete(`/reservation-applications/${applicationId}`);
  }
};