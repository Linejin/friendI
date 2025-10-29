import api from './client';
import { Member, MemberCreateRequest, MemberGrade } from '../types';

export const memberService = {
  // 모든 회원 조회
  getAllMembers: async (): Promise<Member[]> => {
    const response = await api.get('/members');
    return response.data;
  },

  // 회원 ID로 조회
  getMemberById: async (id: number): Promise<Member> => {
    const response = await api.get(`/members/${id}`);
    return response.data;
  },

  // 로그인 ID로 조회
  getMemberByLoginId: async (loginId: string): Promise<Member> => {
    const response = await api.get(`/members/login/${loginId}`);
    return response.data;
  },

  // 새 회원 생성
  createMember: async (data: MemberCreateRequest): Promise<Member> => {
    const response = await api.post('/members', data);
    return response.data;
  },

  // 회원 등급 업그레이드
  upgradeGrade: async (id: number, grade: MemberGrade): Promise<Member> => {
    const response = await api.put(`/members/${id}/grade`, null, {
      params: { grade }
    });
    return response.data;
  },

  // 회원 정보 수정
  updateMember: async (id: number, data: { name: string; email: string; phoneNumber: string; grade?: MemberGrade }): Promise<Member> => {
    const response = await api.put(`/members/${id}`, data);
    return response.data;
  },

  // 회원 삭제
  deleteMember: async (id: number): Promise<void> => {
    await api.delete(`/members/${id}`);
  },

  // 회원 검색
  searchMembers: async (keyword: string): Promise<Member[]> => {
    const response = await api.get(`/members/search`, {
      params: { keyword }
    });
    return response.data;
  },

  // 등급별 회원 조회
  getMembersByGrade: async (grade: MemberGrade): Promise<Member[]> => {
    const response = await api.get(`/members/grade/${grade}`);
    return response.data;
  },

  // 회원 활동 통계 조회
  getMemberStats: async (id: number): Promise<any> => {
    const response = await api.get(`/members/${id}/stats`);
    return response.data;
  }
};