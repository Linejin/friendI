import React from 'react';
import { useQuery } from 'react-query';
import { Link } from 'react-router-dom';
import { reservationService } from '../api/reservations';
import { useAuth } from '../contexts/AuthContext';
import { queryConfig, CACHE_KEYS } from '../config/queryConfig';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';

const HomePage: React.FC = () => {
  const { user } = useAuth();
  
  const { data: availableReservations, isLoading: availableLoading, error: availableError } = useQuery(
    CACHE_KEYS.availableReservations,
    reservationService.getAvailableReservations,
    queryConfig.reservations
  );

  const { data: futureReservations, isLoading: futureLoading, error: futureError } = useQuery(
    CACHE_KEYS.futureReservations,
    reservationService.getFutureReservations,
    queryConfig.reservations
  );

  // 관리자 권한 확인
  const isAdmin = user?.grade === 'ROOSTER';

  if (availableLoading || futureLoading) {
    return <LoadingSpinner message="데이터를 불러오는 중..." />;
  }

  if (availableError || futureError) {
    return <ErrorMessage message="데이터를 불러오는데 실패했습니다." />;
  }

  // 사용자 등급에 따른 이모지
  const getGradeEmoji = (grade: string) => {
    switch (grade) {
      case 'EGG': return '🥚';
      case 'HATCHING': return '🐣';
      case 'CHICK': return '🐥';
      case 'YOUNG_BIRD': return '🐤';
      case 'ROOSTER': return '🐔';
      default: return '👤';
    }
  };

  // 사용자 등급에 따른 한글명
  const getGradeName = (grade: string) => {
    switch (grade) {
      case 'EGG': return '알';
      case 'HATCHING': return '부화중';
      case 'CHICK': return '병아리';
      case 'YOUNG_BIRD': return '어린새';
      case 'ROOSTER': return '관리자';
      default: return '회원';
    }
  };

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">
          안녕하세요, {getGradeEmoji(user?.grade || '')} {user?.name}님!
        </h1>
        <p className="page-description">
          현재 등급: <strong style={{ color: '#007bff' }}>{getGradeName(user?.grade || '')}</strong> · 
          친아이 예약 시스템에 오신 것을 환영합니다! 🎉
          {isAdmin && (
            <span>
              {' '}· <Link to="/admin" style={{ color: '#dc3545', textDecoration: 'none' }}>
                🔧 관리자 페이지로 이동
              </Link>
            </span>
          )}
        </p>
      </div>

      {/* 주요 기능 */}
      <div className="grid grid-2" style={{ marginBottom: '40px' }}>
        <div className="management-card">
          <h3>📅 예약 참가하기</h3>
          <p>다양한 예약에 참가하고<br />새로운 경험을 만들어보세요!</p>
          <Link to="/reservations" className="management-button management-button-primary">
            예약 둘러보기
          </Link>
        </div>

        <div className="management-card">
          <h3>👤 내 정보</h3>
          <p>프로필을 확인하고<br />참가한 예약을 관리해보세요</p>
          <Link to="/profile" className="management-button management-button-success">
            내 정보 보기
          </Link>
        </div>
      </div>

      {/* 개발 도구 (개발 환경에서만 표시) */}
      {process.env.NODE_ENV === 'development' && (
        <div className="card" style={{ marginBottom: '30px', backgroundColor: '#fff3cd', border: '1px solid #ffeaa7' }}>
          <h3>🛠️ 개발 도구</h3>
          <div style={{ marginTop: '15px' }}>
            <Link 
              to="/security-test" 
              className="button button-warning"
              style={{ marginRight: '10px' }}
            >
              🔐 보안 테스트
            </Link>
            <small style={{ color: '#856404', fontSize: '12px' }}>
              권한 시스템이 올바르게 작동하는지 테스트할 수 있습니다.
            </small>
          </div>
        </div>
      )}

      {/* 예약 현황 */}
      <div className="grid grid-2">
        <div className="card">
          <h3>🔥 참가 가능한 예약</h3>
          {availableReservations && availableReservations.length > 0 ? (
            <div style={{ marginTop: '15px' }}>
              {availableReservations.slice(0, 3).map((reservation) => (
                <div key={reservation.id} style={{ 
                  padding: '12px', 
                  border: '1px solid #e9ecef', 
                  borderRadius: '8px',
                  marginBottom: '12px',
                  backgroundColor: '#f8f9fa',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}>
                  <strong style={{ color: '#495057' }}>{reservation.title}</strong>
                  <div style={{ fontSize: '14px', color: '#6c757d', marginTop: '4px' }}>
                    📅 {reservation.reservationDate} {reservation.reservationTime}
                  </div>
                  <div style={{ fontSize: '14px', marginTop: '4px' }}>
                    📍 {reservation.location.name}
                  </div>
                  <div style={{ fontSize: '14px', marginTop: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span>
                      👥 {reservation.confirmedCount}/{reservation.maxCapacity}명
                      {reservation.waitingCount > 0 && (
                        <span style={{ color: '#ffc107', marginLeft: '8px' }}>
                          (대기 {reservation.waitingCount}명)
                        </span>
                      )}
                    </span>
                    <span style={{ 
                      backgroundColor: reservation.confirmedCount >= reservation.maxCapacity ? '#ffc107' : '#28a745',
                      color: 'white',
                      padding: '2px 8px',
                      borderRadius: '12px',
                      fontSize: '12px'
                    }}>
                      {reservation.confirmedCount >= reservation.maxCapacity ? '대기 가능' : '참가 가능'}
                    </span>
                  </div>
                </div>
              ))}
              <Link to="/reservations" style={{ 
                fontSize: '14px', 
                color: '#667eea',
                textDecoration: 'none',
                fontWeight: '500'
              }}>
                더 많은 예약 보기 →
              </Link>
            </div>
          ) : (
            <div style={{ marginTop: '15px', textAlign: 'center', color: '#6c757d' }}>
              <p>현재 참가 가능한 예약이 없습니다.</p>
              <p style={{ fontSize: '14px' }}>곧 새로운 예약이 등록될 예정입니다! 😊</p>
            </div>
          )}
        </div>

        <div className="card">
          <h3>📋 내 활동 요약</h3>
          <div style={{ marginTop: '15px' }}>
            <div style={{ 
              padding: '15px',
              backgroundColor: '#f8f9fa',
              borderRadius: '8px',
              marginBottom: '15px',
              textAlign: 'center'
            }}>
              <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#007bff' }}>
                {getGradeEmoji(user?.grade || '')}
              </div>
              <div style={{ fontSize: '16px', fontWeight: 'bold', marginTop: '5px' }}>
                {getGradeName(user?.grade || '')} 등급
              </div>
              <div style={{ fontSize: '14px', color: '#6c757d', marginTop: '5px' }}>
                {user?.loginId}
              </div>
            </div>
            
            <div style={{ marginBottom: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span>📅 예정된 예약</span>
                <strong style={{ color: '#007bff' }}>
                  {futureReservations?.length || 0}개
                </strong>
              </div>
            </div>
            
            <div style={{ marginBottom: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span>⭐ 총 참가 횟수</span>
                <strong style={{ color: '#28a745' }}>-</strong>
              </div>
            </div>

            <Link 
              to="/profile" 
              className="button button-primary" 
              style={{ width: '100%', textAlign: 'center', marginTop: '15px' }}
            >
              상세 정보 보기
            </Link>
          </div>
        </div>
      </div>

      {/* 도움말 및 안내 */}
      <div className="card" style={{ marginTop: '30px' }}>
        <h3>💡 이용 안내</h3>
        <div style={{ marginTop: '15px' }}>
          <div style={{ marginBottom: '15px' }}>
            <h4 style={{ margin: '0 0 8px 0', fontSize: '16px', color: '#495057' }}>
              📋 예약 참가 방법
            </h4>
            <p style={{ margin: 0, fontSize: '14px', color: '#6c757d', lineHeight: '1.5' }}>
              1. "예약 둘러보기"에서 관심있는 예약을 찾아보세요<br />
              2. 예약 상세 페이지에서 "참가 신청" 버튼을 클릭하세요<br />
              3. 정원이 꽉 찬 경우 대기열에 등록됩니다
            </p>
          </div>
          
          <div style={{ marginBottom: '15px' }}>
            <h4 style={{ margin: '0 0 8px 0', fontSize: '16px', color: '#495057' }}>
              🏆 등급 시스템
            </h4>
            <p style={{ margin: 0, fontSize: '14px', color: '#6c757d', lineHeight: '1.5' }}>
              참가 횟수와 활동에 따라 등급이 상승합니다: 알 → 부화중 → 병아리 → 어린새 → 관리자
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default HomePage;