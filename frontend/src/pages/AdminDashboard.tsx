import React, { useEffect } from 'react';
import { useQuery } from 'react-query';
import { Link } from 'react-router-dom';
import { memberService } from '../api/members';
import { reservationService } from '../api/reservations';
import { useAuth } from '../contexts/AuthContext';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';

const AdminDashboard: React.FC = () => {
  const { user } = useAuth();

  // 컴포넌트 마운트 시 관리자 권한 재확인
  useEffect(() => {
    if (user?.grade !== 'ROOSTER') {
      console.error('🚨 [Security] Admin dashboard accessed by non-admin user:', {
        userId: user?.id,
        userGrade: user?.grade,
        userName: user?.name,
        timestamp: new Date().toISOString()
      });
    } else {
      console.log('✅ [Security] Admin dashboard accessed by authorized user:', user.name);
    }
  }, [user]);

  const { data: members, isLoading: membersLoading, error: membersError } = useQuery(
    'members',
    memberService.getAllMembers
  );

  const { data: reservations, isLoading: reservationsLoading, error: reservationsError } = useQuery(
    'available-reservations',
    reservationService.getAvailableReservations
  );

  if (membersLoading || reservationsLoading) {
    return <LoadingSpinner message="대시보드 데이터를 불러오는 중..." />;
  }

  if (membersError || reservationsError) {
    return <ErrorMessage message="대시보드 데이터를 불러오는데 실패했습니다." />;
  }

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">🔧 관리자 대시보드</h1>
        <p className="page-description">
          회원들의 예약을 효율적으로 관리하고 등급 시스템으로 더 나은 서비스를 제공합니다.
        </p>
      </div>

      {/* 주요 관리 기능 */}
      <div className="grid grid-2" style={{ marginBottom: '40px' }}>
        <div className="management-card">
          <h3>👥 회원 관리</h3>
          <p>회원 등록, 정보 조회, 등급 관리를 통해<br />체계적인 회원 운영을 지원합니다</p>
          <button 
            className="management-button management-button-primary"
            onClick={() => alert('회원 관리 페이지는 개발 중입니다.')}
          >
            회원 관리하기
          </button>
        </div>

        <div className="management-card">
          <h3>📅 예약 관리</h3>
          <p>예약 생성, 수정, 삭제와 달력 뷰를 통해<br />효율적인 예약 시스템을 제공합니다</p>
          <Link to="/reservations" className="management-button management-button-success">
            예약 관리하기
          </Link>
        </div>
      </div>

      {/* 시스템 현황 */}
      <div className="grid grid-3">
        <div className="card">
          <h3>📊 시스템 현황</h3>
          <div style={{ marginTop: '20px' }}>
            <div style={{ marginBottom: '10px' }}>
              <strong>총 회원 수:</strong> {members?.length || 0}명
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>예약 가능한 슬롯:</strong> {reservations?.length || 0}개
            </div>
          </div>
        </div>

        <div className="card">
          <h3>🏆 회원 등급 현황</h3>
          <div style={{ marginTop: '15px' }}>
            {members && members.length > 0 ? (
              <>
                <div style={{ marginBottom: '8px', display: 'flex', justifyContent: 'space-between' }}>
                  <span>🥚 알:</span> <strong>{members.filter(m => m.grade === 'EGG').length}명</strong>
                </div>
                <div style={{ marginBottom: '8px', display: 'flex', justifyContent: 'space-between' }}>
                  <span>🐣 부화중:</span> <strong>{members.filter(m => m.grade === 'HATCHING').length}명</strong>
                </div>
                <div style={{ marginBottom: '8px', display: 'flex', justifyContent: 'space-between' }}>
                  <span>🐥 병아리:</span> <strong>{members.filter(m => m.grade === 'CHICK').length}명</strong>
                </div>
                <div style={{ marginBottom: '8px', display: 'flex', justifyContent: 'space-between' }}>
                  <span>🐤 어린새:</span> <strong>{members.filter(m => m.grade === 'YOUNG_BIRD').length}명</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span>🐔 관리자:</span> <strong>{members.filter(m => m.grade === 'ROOSTER').length}명</strong>
                </div>
              </>
            ) : (
              <p style={{ color: '#6c757d' }}>등록된 회원이 없습니다.</p>
            )}
          </div>
        </div>

        <div className="card">
          <h3>⚡ 빠른 액션</h3>
          <div style={{ marginTop: '15px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
            <button 
              className="button button-primary" 
              style={{ textAlign: 'center' }}
              onClick={() => alert('신규 회원 등록 기능은 개발 중입니다.')}
            >
              신규 회원 등록
            </button>
            <button 
              className="button button-success" 
              style={{ textAlign: 'center' }}
              onClick={() => alert('지원서 관리 기능은 개발 중입니다.')}
            >
              지원서 관리
            </button>
          </div>
        </div>
      </div>

      {/* 최근 활동 현황 */}
      <div className="grid grid-2">
        <div className="card">
          <h3>🔥 최근 예약 현황</h3>
          {reservations && reservations.length > 0 ? (
            <div style={{ marginTop: '15px' }}>
              {reservations.slice(0, 3).map((reservation) => (
                <div key={reservation.id} style={{ 
                  padding: '12px', 
                  border: '1px solid #e9ecef', 
                  borderRadius: '8px',
                  marginBottom: '12px',
                  backgroundColor: '#f8f9fa'
                }}>
                  <strong style={{ color: '#495057' }}>{reservation.title}</strong>
                  <div style={{ fontSize: '14px', color: '#6c757d', marginTop: '4px' }}>
                    📅 {reservation.reservationDate}
                  </div>
                  <div style={{ fontSize: '14px', marginTop: '4px' }}>
                    👥 {reservation.confirmedCount}/{reservation.maxCapacity}명 신청
                    {reservation.waitingCount > 0 && (
                      <span style={{ color: '#ffc107', marginLeft: '8px' }}>
                        대기 {reservation.waitingCount}명
                      </span>
                    )}
                  </div>
                </div>
              ))}
              <Link to="/reservations" style={{ 
                fontSize: '14px', 
                color: '#667eea',
                textDecoration: 'none',
                fontWeight: '500'
              }}>
                더 보기 →
              </Link>
            </div>
          ) : (
            <p style={{ marginTop: '15px', color: '#6c757d' }}>
              예약 가능한 슬롯이 없습니다.
            </p>
          )}
        </div>

        <div className="card">
          <h3>📈 시스템 활용도</h3>
          <div style={{ marginTop: '15px' }}>
            <div style={{ marginBottom: '15px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px' }}>
                <span>예약 활용률</span>
                <strong>75%</strong>
              </div>
              <div style={{ 
                height: '8px', 
                backgroundColor: '#e9ecef', 
                borderRadius: '4px',
                overflow: 'hidden'
              }}>
                <div style={{ 
                  height: '100%', 
                  width: '75%', 
                  backgroundColor: '#28a745',
                  borderRadius: '4px'
                }}></div>
              </div>
            </div>
            <div style={{ marginBottom: '15px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px' }}>
                <span>회원 활성도</span>
                <strong>68%</strong>
              </div>
              <div style={{ 
                height: '8px', 
                backgroundColor: '#e9ecef', 
                borderRadius: '4px',
                overflow: 'hidden'
              }}>
                <div style={{ 
                  height: '100%', 
                  width: '68%', 
                  backgroundColor: '#007bff',
                  borderRadius: '4px'
                }}></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;