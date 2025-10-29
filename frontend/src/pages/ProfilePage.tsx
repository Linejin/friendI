import React, { useState, useEffect } from 'react';
import { useQuery } from 'react-query';
import { reservationService } from '../api/reservations';
import { memberService } from '../api/members';
import { useAuth } from '../contexts/AuthContext';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';

const ProfilePage: React.FC = () => {
  const { user } = useAuth();
  const [screenSize, setScreenSize] = useState({
    width: window.innerWidth,
    height: window.innerHeight
  });

  // 화면 크기 변경 감지
  useEffect(() => {
    const handleResize = () => {
      setScreenSize({
        width: window.innerWidth,
        height: window.innerHeight
      });
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // 반응형 스타일 계산
  const getResponsiveStyles = () => {
    const isMobile = screenSize.width < 768;
    const isTablet = screenSize.width >= 768 && screenSize.width < 1024;

    return {
      containerPadding: isMobile ? '10px' : isTablet ? '20px' : '24px',
      titleSize: isMobile ? '20px' : '24px',
      headerSize: isMobile ? '14px' : '16px',
      bodySize: isMobile ? '12px' : '14px',
      cardPadding: isMobile ? '15px' : '20px',
      marginBottom: isMobile ? '15px' : '20px',
      gap: isMobile ? '8px' : '12px',
      gridColumns: isMobile ? '1fr' : 'repeat(auto-fit, minmax(300px, 1fr))'
    };
  };

  const styles = getResponsiveStyles();

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

  // 등급별 설명
  const getGradeDescription = (grade: string) => {
    switch (grade) {
      case 'EGG': return '이제 막 시작한 새로운 멤버입니다!';
      case 'HATCHING': return '활동을 시작하며 성장하고 있는 멤버입니다!';
      case 'CHICK': return '적극적으로 활동하는 활발한 멤버입니다!';
      case 'YOUNG_BIRD': return '많은 경험을 쌓은 베테랑 멤버입니다!';
      case 'ROOSTER': return '커뮤니티를 이끌어가는 관리자입니다!';
      default: return '친아이 멤버입니다!';
    }
  };

  const { data: futureReservations, isLoading: futureLoading, error: futureError } = useQuery(
    'future-reservations',
    reservationService.getFutureReservations
  );

  const { data: userStats, isLoading: statsLoading, error: statsError } = useQuery(
    ['member-stats', user?.id],
    () => user?.id ? memberService.getMemberStats(user.id) : null,
    {
      enabled: !!user?.id
    }
  );

  if (futureLoading || statsLoading) {
    return <LoadingSpinner message="프로필 정보를 불러오는 중..." />;
  }

  if (futureError || statsError) {
    return <ErrorMessage message="프로필 정보를 불러오는데 실패했습니다." />;
  }

  if (!user) {
    return <ErrorMessage message="사용자 정보를 찾을 수 없습니다." />;
  }

  return (
    <div style={{ padding: styles.containerPadding }}>
      <div className="page-header" style={{ marginBottom: styles.marginBottom }}>
        <h1 className="page-title" style={{ 
          fontSize: styles.titleSize,
          margin: `0 0 ${styles.gap} 0`
        }}>👤 내 정보</h1>
        <p className="page-description" style={{
          fontSize: styles.bodySize,
          margin: 0,
          lineHeight: '1.5'
        }}>
          프로필 정보와 활동 내역을 확인할 수 있습니다.
        </p>
      </div>

      {/* 프로필 정보 */}
      <div className="card" style={{ 
        padding: styles.cardPadding, 
        marginBottom: styles.marginBottom,
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        color: 'white'
      }}>
        <div style={{ 
          display: 'flex', 
          alignItems: 'center', 
          gap: styles.gap,
          flexDirection: screenSize.width < 600 ? 'column' : 'row',
          textAlign: screenSize.width < 600 ? 'center' : 'left'
        }}>
          <div style={{ 
            fontSize: '48px', 
            lineHeight: '1',
            marginBottom: screenSize.width < 600 ? '10px' : '0'
          }}>
            {getGradeEmoji(user.grade)}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h2 style={{ 
                margin: 0, 
                fontSize: styles.titleSize,
                fontWeight: 'bold',
              }}>
                {user.name}
              </h2>
              <p style={{ 
                margin: 0, 
                fontSize: styles.headerSize,
                opacity: 0.9,
                color: 'white'
              }}>
                @{user.loginId}
              </p>
              <div style={{ 
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                backgroundColor: 'rgba(255, 255, 255, 0.2)',
                padding: '4px 12px',
                borderRadius: '20px',
                fontSize: styles.bodySize,
                fontWeight: 'bold'
              }}>
                {getGradeName(user.grade)} 등급
              </div>
            </div>
            <p style={{ 
              margin: '8px 0 0 0', 
              fontSize: styles.bodySize,
              opacity: 0.8,
              color: 'white'
            }}>
              {getGradeDescription(user.grade)}
            </p>
          </div>
        </div>
      </div>

      {/* 활동 통계 */}
      <div style={{ 
        display: 'grid', 
        gridTemplateColumns: styles.gridColumns,
        gap: styles.gap,
        marginBottom: styles.marginBottom
      }}>
        <div className="card" style={{ padding: styles.cardPadding }}>
          <h3 style={{ 
            fontSize: styles.headerSize, 
            margin: `0 0 ${styles.marginBottom} 0`,
            color: '#495057'
          }}>📊 활동 통계</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: styles.bodySize }}>총 참가 횟수</span>
              <strong style={{ fontSize: styles.headerSize, color: '#007bff' }}>
                {userStats?.totalParticipations || 0}회
              </strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: styles.bodySize }}>완료한 예약</span>
              <strong style={{ fontSize: styles.headerSize, color: '#28a745' }}>
                {userStats?.completedReservations || 0}회
              </strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: styles.bodySize }}>취소한 예약</span>
              <strong style={{ fontSize: styles.headerSize, color: '#dc3545' }}>
                {userStats?.canceledReservations || 0}회
              </strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: styles.bodySize }}>가입일</span>
              <strong style={{ fontSize: styles.headerSize, color: '#6c757d' }}>
                {userStats?.joinDate || '-'}
              </strong>
            </div>
          </div>
        </div>

        <div className="card" style={{ padding: styles.cardPadding }}>
          <h3 style={{ 
            fontSize: styles.headerSize, 
            margin: `0 0 ${styles.marginBottom} 0`,
            color: '#495057'
          }}>🎯 참가율</h3>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '32px', fontWeight: 'bold', color: '#007bff', marginBottom: '8px' }}>
              {Math.round(userStats?.participationRate || 0)}%
            </div>
            <p style={{ fontSize: styles.bodySize, color: '#6c757d', margin: 0 }}>
              신청한 예약 중 참가 완료율
            </p>
            <div style={{ 
              marginTop: '15px',
              height: '8px', 
              backgroundColor: '#e9ecef', 
              borderRadius: '4px',
              overflow: 'hidden'
            }}>
              <div style={{ 
                height: '100%', 
                width: `${Math.round(userStats?.participationRate || 0)}%`, 
                backgroundColor: '#007bff',
                borderRadius: '4px'
              }}></div>
            </div>
          </div>
        </div>
      </div>

      {/* 예정된 예약 */}
      <div className="card" style={{ padding: styles.cardPadding }}>
        <h3 style={{ 
          fontSize: styles.headerSize, 
          margin: `0 0 ${styles.marginBottom} 0`,
          color: '#495057'
        }}>📅 예정된 예약</h3>
        {futureReservations && futureReservations.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {futureReservations.map((reservation) => (
              <div key={reservation.id} style={{ 
                padding: '15px', 
                border: '1px solid #e9ecef', 
                borderRadius: '8px',
                backgroundColor: '#f8f9fa'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                  <strong style={{ fontSize: styles.headerSize, color: '#495057' }}>
                    {reservation.title}
                  </strong>
                  <span style={{ 
                    backgroundColor: '#28a745',
                    color: 'white',
                    padding: '2px 8px',
                    borderRadius: '12px',
                    fontSize: styles.bodySize
                  }}>
                    확정
                  </span>
                </div>
                <div style={{ fontSize: styles.bodySize, color: '#6c757d', marginBottom: '4px' }}>
                  📅 {reservation.reservationDate} {reservation.reservationTime}
                </div>
                <div style={{ fontSize: styles.bodySize, color: '#6c757d' }}>
                  📍 {reservation.location.name}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div style={{ textAlign: 'center', color: '#6c757d', padding: '20px' }}>
            <p style={{ fontSize: styles.bodySize, margin: 0 }}>
              예정된 예약이 없습니다.
            </p>
            <p style={{ fontSize: styles.bodySize, margin: '8px 0 0 0' }}>
              새로운 예약에 참가해보세요! 😊
            </p>
          </div>
        )}
      </div>

      {/* 등급 가이드 */}
      <div className="card" style={{ padding: styles.cardPadding, marginTop: styles.marginBottom }}>
        <h3 style={{ 
          fontSize: styles.headerSize, 
          margin: `0 0 ${styles.marginBottom} 0`,
          color: '#495057'
        }}>🏆 등급 시스템</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          {[
            { grade: 'EGG', name: '알', emoji: '🥚', desc: '새로 가입한 회원' },
            { grade: 'HATCHING', name: '부화중', emoji: '🐣', desc: '활동을 시작한 회원' },
            { grade: 'CHICK', name: '병아리', emoji: '🐥', desc: '적극적으로 활동하는 회원' },
            { grade: 'YOUNG_BIRD', name: '어린새', emoji: '🐤', desc: '많은 경험을 쌓은 회원' },
            { grade: 'ROOSTER', name: '관리자', emoji: '🐔', desc: '커뮤니티를 관리하는 회원' }
          ].map((gradeInfo) => (
            <div key={gradeInfo.grade} style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '12px',
              padding: '8px',
              borderRadius: '6px',
              backgroundColor: user.grade === gradeInfo.grade ? '#e7f3ff' : 'transparent',
              border: user.grade === gradeInfo.grade ? '2px solid #007bff' : '1px solid transparent'
            }}>
              <span style={{ fontSize: '20px' }}>{gradeInfo.emoji}</span>
              <div style={{ flex: 1 }}>
                <strong style={{ fontSize: styles.bodySize, color: '#495057' }}>
                  {gradeInfo.name}
                </strong>
                <span style={{ fontSize: styles.bodySize, color: '#6c757d', marginLeft: '8px' }}>
                  {gradeInfo.desc}
                </span>
              </div>
              {user.grade === gradeInfo.grade && (
                <span style={{ 
                  fontSize: styles.bodySize, 
                  color: '#007bff', 
                  fontWeight: 'bold' 
                }}>
                  현재 등급
                </span>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default ProfilePage;