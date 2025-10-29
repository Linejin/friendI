import { LoginRequest, LoginResponse } from '../types';
import { apiClient } from './client';

export const authService = {
  // 로그인
  login: async (loginRequest: LoginRequest): Promise<LoginResponse> => {
    const response = await apiClient.post<LoginResponse>('/auth/login', loginRequest);
    return response.data;
  },

  // 로그아웃 (서버에 알림)
  logout: async (): Promise<void> => {
    await apiClient.post('/auth/logout');
  },

  // 토큰 검증
  validateToken: async (): Promise<boolean> => {
    try {
      await apiClient.get('/auth/validate');
      return true;
    } catch {
      return false;
    }
  },

  // 현재 사용자 정보 조회
  getCurrentUser: async (): Promise<LoginResponse> => {
    const response = await apiClient.get<LoginResponse>('/auth/me');
    return response.data;
  }
};