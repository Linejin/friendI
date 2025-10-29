import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { applicationService } from '../api/applications';
import { memberService } from '../api/members';
import { reservationService } from '../api/reservations';
import { ReservationApplication, ReservationStatus } from '../types';
import LoadingSpinner from '../components/LoadingSpinner';

const ApplicationsPage: React.FC = () => {
  const [selectedMemberId, setSelectedMemberId] = useState<number | ''>('');
  const [selectedReservationId, setSelectedReservationId] = useState<number | ''>('');
  const queryClient = useQueryClient();

  // 모든 데이터 조회
  const { data: members } = useQuery('members', memberService.getAllMembers);
  const { data: reservations } = useQuery('reservations', reservationService.getAllReservations);

  // 선택된 회원의 신청 내역
  const { data: memberApplications, isLoading: memberApplicationsLoading } = useQuery(
    ['member-applications', selectedMemberId],
    () => applicationService.getApplicationsByMember(selectedMemberId as number),
    { enabled: !!selectedMemberId }
  );

  // 선택된 예약의 신청 내역
  const { data: reservationApplications, isLoading: reservationApplicationsLoading } = useQuery(
    ['reservation-applications', selectedReservationId],
    () => applicationService.getApplicationsByReservation(selectedReservationId as number),
    { enabled: !!selectedReservationId }
  );

  // 신청 상태 변경
  const updateStatusMutation = useMutation(
    ({ applicationId, status }: { applicationId: number; status: ReservationStatus }) =>
      applicationService.updateApplicationStatus(applicationId, status),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['member-applications', selectedMemberId]);
        queryClient.invalidateQueries(['reservation-applications', selectedReservationId]);
        queryClient.invalidateQueries('reservations');
      }
    }
  );

  // 신청 취소
  const cancelApplicationMutation = useMutation(applicationService.cancelApplication, {
    onSuccess: () => {
      queryClient.invalidateQueries(['member-applications', selectedMemberId]);
      queryClient.invalidateQueries(['reservation-applications', selectedReservationId]);
      queryClient.invalidateQueries('reservations');
    }
  });

  const handleStatusChange = (applicationId: number, newStatus: ReservationStatus) => {
    if (window.confirm(`신청 상태를 ${getStatusText(newStatus)}로 변경하시겠습니까?`)) {
      updateStatusMutation.mutate({ applicationId, status: newStatus });
    }
  };

  const handleCancelApplication = (applicationId: number) => {
    if (window.confirm('이 신청을 취소하시겠습니까?')) {
      cancelApplicationMutation.mutate(applicationId);
    }
  };

  const getStatusText = (status: ReservationStatus): string => {
    switch (status) {
      case ReservationStatus.PENDING: return '대기중';
      case ReservationStatus.CONFIRMED: return '승인됨';
      case ReservationStatus.WAITING: return '대기열';
      case ReservationStatus.CANCELLED: return '취소됨';
      default: return status;
    }
  };

  const getStatusColor = (status: ReservationStatus): string => {
    switch (status) {
      case ReservationStatus.PENDING: return '#ffc107';
      case ReservationStatus.CONFIRMED: return '#28a745';
      case ReservationStatus.WAITING: return '#17a2b8';
      case ReservationStatus.CANCELLED: return '#dc3545';
      default: return '#6c757d';
    }
  };

  const renderApplicationCard = (
    application: ReservationApplication, 
    showMember: boolean = false, 
    showReservation: boolean = false
  ) => (
    <div key={application.id} className="card" style={{ backgroundColor: '#fafafa' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div style={{ flex: 1 }}>
          {showMember && (
            <div style={{ marginBottom: '8px' }}>
              <strong>👤 회원:</strong> {application.memberName}
            </div>
          )}
          {showReservation && (
            <div style={{ marginBottom: '8px' }}>
              <strong>📅 예약:</strong> {application.reservationTitle}
            </div>
          )}
          <div style={{ marginBottom: '8px' }}>
            <strong>📋 상태:</strong>
            <span style={{ 
              marginLeft: '8px',
              padding: '2px 8px',
              borderRadius: '12px',
              backgroundColor: getStatusColor(application.status),
              color: 'white',
              fontSize: '12px'
            }}>
              {getStatusText(application.status)}
            </span>
          </div>
          <div style={{ fontSize: '14px', color: '#6c757d' }}>
            신청일: {new Date(application.appliedAt).toLocaleString()}
          </div>
        </div>
        <div style={{ display: 'flex', gap: '5px', flexDirection: 'column' }}>
          {application.status === ReservationStatus.PENDING && (
            <>
              <button
                className="button button-success"
                style={{ fontSize: '12px', padding: '5px 10px' }}
                onClick={() => handleStatusChange(application.id, ReservationStatus.CONFIRMED)}
                disabled={updateStatusMutation.isLoading}
              >
                승인
              </button>
              <button
                className="button"
                style={{ fontSize: '12px', padding: '5px 10px', backgroundColor: '#17a2b8', color: 'white' }}
                onClick={() => handleStatusChange(application.id, ReservationStatus.WAITING)}
                disabled={updateStatusMutation.isLoading}
              >
                대기열
              </button>
            </>
          )}
          {application.status !== ReservationStatus.CANCELLED && (
            <button
              className="button button-danger"
              style={{ fontSize: '12px', padding: '5px 10px' }}
              onClick={() => handleCancelApplication(application.id)}
              disabled={cancelApplicationMutation.isLoading}
            >
              취소
            </button>
          )}
        </div>
      </div>
    </div>
  );

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">신청 관리</h1>
        <p className="page-description">
          예약 신청을 조회하고 상태를 관리할 수 있습니다.
        </p>
      </div>

      <div className="grid grid-2">
        <div className="card">
          <h3>회원별 신청 조회</h3>
          <div className="form-group">
            <label className="form-label">회원 선택</label>
            <select
              className="form-input"
              value={selectedMemberId}
              onChange={(e) => setSelectedMemberId(e.target.value ? Number(e.target.value) : '')}
            >
              <option value="">회원을 선택하세요</option>
              {members?.map((member) => (
                <option key={member.id} value={member.id}>
                  {member.name} (@{member.loginId})
                </option>
              ))}
            </select>
          </div>

          {selectedMemberId && (
            <div style={{ marginTop: '20px' }}>
              {memberApplicationsLoading ? (
                <LoadingSpinner message="신청 내역을 불러오는 중..." />
              ) : memberApplications && memberApplications.length > 0 ? (
                <div>
                  <h4>신청 내역 ({memberApplications.length}건)</h4>
                  <div style={{ marginTop: '15px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    {memberApplications.map((application) =>
                      renderApplicationCard(application, false, true)
                    )}
                  </div>
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: '20px', color: '#6c757d' }}>
                  신청 내역이 없습니다.
                </div>
              )}
            </div>
          )}
        </div>

        <div className="card">
          <h3>예약별 신청 조회</h3>
          <div className="form-group">
            <label className="form-label">예약 선택</label>
            <select
              className="form-input"
              value={selectedReservationId}
              onChange={(e) => setSelectedReservationId(e.target.value ? Number(e.target.value) : '')}
            >
              <option value="">예약을 선택하세요</option>
              {reservations?.map((reservation) => (
                <option key={reservation.id} value={reservation.id}>
                  {reservation.title} ({reservation.reservationDate})
                </option>
              ))}
            </select>
          </div>

          {selectedReservationId && (
            <div style={{ marginTop: '20px' }}>
              {reservationApplicationsLoading ? (
                <LoadingSpinner message="신청 내역을 불러오는 중..." />
              ) : reservationApplications && reservationApplications.length > 0 ? (
                <div>
                  <h4>신청 내역 ({reservationApplications.length}건)</h4>
                  <div style={{ marginTop: '15px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    {reservationApplications.map((application) =>
                      renderApplicationCard(application, true, false)
                    )}
                  </div>
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: '20px', color: '#6c757d' }}>
                  신청 내역이 없습니다.
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      <div className="card">
        <h3>💡 신청 상태 설명</h3>
        <div className="grid grid-2" style={{ marginTop: '15px' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
              <span style={{
                padding: '2px 8px',
                borderRadius: '12px',
                backgroundColor: '#ffc107',
                color: 'white',
                fontSize: '12px'
              }}>
                대기중
              </span>
              <span>관리자 승인 대기</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
              <span style={{
                padding: '2px 8px',
                borderRadius: '12px',
                backgroundColor: '#28a745',
                color: 'white',
                fontSize: '12px'
              }}>
                승인됨
              </span>
              <span>예약 확정</span>
            </div>
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
              <span style={{
                padding: '2px 8px',
                borderRadius: '12px',
                backgroundColor: '#17a2b8',
                color: 'white',
                fontSize: '12px'
              }}>
                대기열
              </span>
              <span>정원 초과로 대기</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
              <span style={{
                padding: '2px 8px',
                borderRadius: '12px',
                backgroundColor: '#dc3545',
                color: 'white',
                fontSize: '12px'
              }}>
                취소됨
              </span>
              <span>신청 취소</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ApplicationsPage;