import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { reservationService } from '../api/reservations';
import { Reservation, ReservationCreateRequest } from '../types';
import { queryConfig, CACHE_KEYS } from '../config/queryConfig';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';
import ReservationCalendar from '../components/ReservationCalendar';
import ReservationModal from '../components/ReservationModal';
import ReservationDetailModal from '../components/ReservationDetailModal';
import { useAuth } from '../contexts/AuthContext';

const ReservationsPage: React.FC = () => {
  const [viewMode, setViewMode] = useState<'calendar' | 'list'>('calendar');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedReservation, setSelectedReservation] = useState<Reservation | null>(null);
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [screenSize, setScreenSize] = useState({
    width: window.innerWidth,
    height: window.innerHeight
  });
  const queryClient = useQueryClient();

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
    const isDesktop = screenSize.width >= 1024;

    return {
      // 컨테이너
      containerPadding: isMobile ? '10px' : isTablet ? '20px' : '24px',
      
      // 폰트 크기
      titleSize: isMobile ? '20px' : '24px',
      headerSize: isMobile ? '14px' : '16px',
      bodySize: isMobile ? '12px' : '14px',
      smallSize: isMobile ? '10px' : '12px',
      
      // 버튼 크기
      buttonPadding: isMobile ? '8px 12px' : '10px 16px',
      buttonFontSize: isMobile ? '12px' : '14px',
      
      // 간격
      marginBottom: isMobile ? '15px' : '20px',
      gap: isMobile ? '8px' : '12px',
      largePadding: isMobile ? '30px 10px' : '50px',
      
      // 레이아웃
      headerDirection: isMobile ? 'column' : 'row',
      buttonDirection: isMobile ? 'row' : 'row',
      gridColumns: isMobile ? '1fr' : 'repeat(auto-fit, minmax(300px, 1fr))'
    };
  };

  const styles = getResponsiveStyles();

  const { user } = useAuth(); // 현재 로그인한 사용자 정보
  const { data: reservations, isLoading, error, refetch } = useQuery(
    CACHE_KEYS.reservations,
    reservationService.getAllReservations,
    {
      ...queryConfig.reservations,
      onSuccess: (data) => {
        console.log('Reservations loaded:', data);
      },
      onError: (error) => {
        console.error('Error loading reservations:', error);
      }
    }
  );

// ✅ Reservation -> ReservationCreateRequest 매퍼
const toCreateRequest = (r: Reservation, fallbackCreatorId: number): ReservationCreateRequest => {
  return {
    title: r.title,
    description: r.description,
    // ReservationCreateRequest가 LocalDate를 요구하므로 YYYY-MM-DD 형식으로 변환
    reservationDate:
      typeof r.reservationDate === 'string'
        ? r.reservationDate
        : new Date(r.reservationDate).toISOString().split('T')[0],

    maxCapacity: r.maxCapacity,

    // ✅ 필수: creatorMemberId
    // Reservation에 creatorMemberId가 있으면 유지, 없으면 현재 로그인 유저로 채움
    creatorMemberId: (r as any).creatorMemberId ?? fallbackCreatorId,

    // ✅ 필수: locations
    // 프로젝트 타입에 따라 아래 두 가지 중 하나로 맞추세요.

    // 1) locationId[] 형태라면 (권장: 백엔드가 id만 받는 경우)
    // locations: [(r as any).locationId ?? r.location?.id],

    // 2) 객체 배열 형태라면 (name/address/url 등)
    locations: (r as any).locations ?? [
      {
        name: r.location?.name ?? '',
        address: r.location?.address ?? '',
        url: r.location?.url ?? '',
      },
    ],

    // ✅ 필수: reservationTime (string 타입)
    reservationTime: r.reservationTime || '10:00',
  };
};

  const createReservationMutation = useMutation(reservationService.createReservation, {
    onSuccess: () => {
      queryClient.invalidateQueries(CACHE_KEYS.reservations);
      queryClient.invalidateQueries(CACHE_KEYS.availableReservations);
      queryClient.invalidateQueries(CACHE_KEYS.futureReservations);
      setShowCreateModal(false);
      setSelectedDate(null);
    }
  });

  const deleteReservationMutation = useMutation(reservationService.deleteReservation, {
    onSuccess: () => {
      queryClient.invalidateQueries(CACHE_KEYS.reservations);
      queryClient.invalidateQueries(CACHE_KEYS.availableReservations);
      queryClient.invalidateQueries(CACHE_KEYS.futureReservations);
      setShowDetailModal(false);
      setSelectedReservation(null);
    }
  });
    // ✅ 예약 수정 뮤테이션
    const updateReservationMutation = useMutation(
        (params: { id: number; data: ReservationCreateRequest }) =>
            reservationService.updateReservation(params.id, params.data),
        {
            onSuccess: () => {
                queryClient.invalidateQueries(CACHE_KEYS.reservations);
                queryClient.invalidateQueries(CACHE_KEYS.availableReservations);
                queryClient.invalidateQueries(CACHE_KEYS.futureReservations);
                // 수정 성공 시 모달을 닫지 않고 유지하여 수정된 내용 확인 가능
            },
            onError: (err) => {
                console.error('예약 수정 중 오류:', err);
                alert('예약 수정에 실패했습니다: ' + (err instanceof Error ? err.message : String(err)));
            },
        }
    );

    // ✅ 수정 핸들러
    const handleEditReservation = (updated: Reservation) => {
        if (!user) {
            alert('로그인이 필요합니다.');
            return;
        }
        try {
            const payload = toCreateRequest(updated, user.id);
            updateReservationMutation.mutate({ id: updated.id, data: payload });
        } catch (error) {
            console.error('ReservationsPage - Error in handleEditReservation:', error);
            alert('예약 수정 요청 중 오류가 발생했습니다: ' + (error instanceof Error ? error.message : String(error)));
        }
    };

  // 달력에서 빈 슬롯 클릭 시 (새 예약 생성)
  const handleSelectSlot = (slotInfo: { start: Date; end: Date }) => {
    console.log('ReservationsPage - handleSelectSlot called with:', slotInfo);
    const now = new Date(); // 현재 시간 기준
    
    if (slotInfo.start < now) {
      alert('과거 시간에는 예약을 생성할 수 없습니다. (현재 시간 이후만 가능)');
      return;
    }
    console.log('ReservationsPage - setting selectedDate to:', slotInfo.start);
    setSelectedDate(slotInfo.start);
    console.log('ReservationsPage - opening create modal');
    setShowCreateModal(true);
  };

  // 달력에서 기존 예약 클릭 시 (상세보기)
  const handleSelectEvent = (reservation: Reservation) => {
    setSelectedReservation(reservation);
    setShowDetailModal(true);
  };

  // 예약 생성 제출
  const handleCreateReservation = async (data: ReservationCreateRequest) => {
    await createReservationMutation.mutateAsync(data);
  };

  // 예약 삭제
  const handleDeleteReservation = (reservationId: number) => {
    deleteReservationMutation.mutate(reservationId);
  };

  // 모달 닫기
  const handleCloseCreateModal = () => {
    setShowCreateModal(false);
    setSelectedDate(null);
  };

  const handleCloseDetailModal = () => {
    setShowDetailModal(false);
    setSelectedReservation(null);
  };

  if (isLoading) {
    return <LoadingSpinner message="예약 목록을 불러오는 중..." />;
  }

  if (error) {
    console.error('Reservations error:', error);
    return (
      <div>
        <ErrorMessage 
          message={`예약 목록을 불러오는데 실패했습니다. ${
            error instanceof Error ? error.message : '알 수 없는 오류'
          }`} 
          onRetry={refetch} 
        />
      </div>
    );
  }
    const canEditSelected =
        !!user && !!selectedReservation &&
        (user.grade === 'ROOSTER' || user.id === selectedReservation.creatorId);

    console.log('canEditSelected 계산:', {
        user: user,
        selectedReservation: selectedReservation,
        userGrade: user?.grade,
        userId: user?.id,
        creatorId: selectedReservation?.creatorId,
        canEdit: canEditSelected
    });

  return (
    <div style={{ padding: styles.containerPadding }}>
      <div className="page-header" style={{ marginBottom: styles.marginBottom }}>
        <h1 className="page-title" style={{ 
          fontSize: styles.titleSize,
          margin: `0 0 ${styles.gap} 0`
        }}>예약 관리</h1>
        <p className="page-description" style={{
          fontSize: styles.bodySize,
          margin: 0,
          lineHeight: '1.5'
        }}>
          달력에서 예약을 관리하고 새로운 예약을 생성할 수 있습니다.
        </p>
      </div>

      <div className="card" style={{ 
        padding: styles.containerPadding,
        margin: 0
      }}>
        <div style={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: screenSize.width < 600 ? 'stretch' : 'center',
          marginBottom: styles.marginBottom,
          flexDirection: screenSize.width < 600 ? 'column' : 'row',
          gap: styles.gap
        }}>
          <div style={{ 
            display: 'flex', 
            gap: styles.gap,
            justifyContent: screenSize.width < 600 ? 'stretch' : 'flex-start',
            flexWrap: 'wrap'
          }}>
            <button 
              className={`button ${viewMode === 'calendar' ? 'button-primary' : ''}`}
              onClick={() => setViewMode('calendar')}
              style={{
                padding: styles.buttonPadding,
                fontSize: styles.buttonFontSize,
                flex: screenSize.width < 600 ? '1' : 'none',
                minHeight: '36px'
              }}
            >
              📅 달력 보기
            </button>
            <button 
              className={`button ${viewMode === 'list' ? 'button-primary' : ''}`}
              onClick={() => setViewMode('list')}
              style={{
                padding: styles.buttonPadding,
                fontSize: styles.buttonFontSize,
                flex: screenSize.width < 600 ? '1' : 'none',
                minHeight: '36px'
              }}
            >
              📋 목록 보기
            </button>
          </div>
          <div style={{ 
            display: 'flex', 
            gap: styles.gap, 
            alignItems: 'center',
            justifyContent: screenSize.width < 600 ? 'stretch' : 'flex-end',
            flexWrap: 'wrap'
          }}>
            <span style={{ 
              fontSize: styles.bodySize, 
              color: '#6c757d',
              flex: screenSize.width < 600 ? '1' : 'none',
              textAlign: screenSize.width < 600 ? 'center' : 'left'
            }}>
              총 {reservations?.length || 0}개 예약
            </span>
            <button 
              className="button button-primary"
              onClick={() => setShowCreateModal(true)}
              style={{
                padding: styles.buttonPadding,
                fontSize: styles.buttonFontSize,
                flex: screenSize.width < 600 ? 'none' : 'none',
                minHeight: '36px',
                whiteSpace: 'nowrap'
              }}
            >
              + 새 예약 생성
            </button>
          </div>
        </div>

        {viewMode === 'calendar' ? (
          reservations ? (
            <ReservationCalendar
              reservations={reservations}
              onSelectSlot={handleSelectSlot}
              onSelectEvent={handleSelectEvent}
            />
          ) : (
            <div style={{ textAlign: 'center', padding: '50px', color: '#6c757d' }}>
              <p>예약 데이터를 불러오는 중...</p>
            </div>
          )
        ) : (
          <div>
            {reservations && reservations.length > 0 ? (
              <div style={{
                display: 'grid',
                gridTemplateColumns: styles.gridColumns,
                gap: styles.gap,
                marginTop: styles.marginBottom
              }}>
                {reservations.map((reservation: Reservation) => (
                  <div 
                    key={reservation.id} 
                    className="card" 
                    style={{ 
                      backgroundColor: '#fafafa',
                      cursor: 'pointer',
                      transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                      padding: styles.containerPadding,
                      margin: 0
                    }}
                    onClick={() => handleSelectEvent(reservation)}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'translateY(-2px)';
                      e.currentTarget.style.boxShadow = '0 4px 15px rgba(0, 0, 0, 0.15)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'translateY(0)';
                      e.currentTarget.style.boxShadow = '0 2px 10px rgba(0, 0, 0, 0.1)';
                    }}
                  >
                    <div>
                      <h4 style={{
                        fontSize: styles.headerSize,
                        margin: `0 0 ${styles.gap} 0`
                      }}>{reservation.title}</h4>
                      <p style={{ 
                        color: '#6c757d', 
                        margin: `${styles.gap} 0`,
                        fontSize: styles.bodySize,
                        lineHeight: '1.4'
                      }}>
                        {reservation.description}
                      </p>
                    </div>
                    <div style={{ 
                      marginTop: styles.marginBottom, 
                      fontSize: styles.bodySize 
                    }}>
                      <div style={{ marginBottom: styles.gap }}>
                        <strong>📅 날짜:</strong> {reservation.reservationDate}
                      </div>
                      <div style={{ marginBottom: styles.gap }}>
                        <strong>📍 장소:</strong> {reservation.location.name}
                      </div>
                      <div style={{ marginBottom: styles.gap }}>
                        <strong>👥 인원:</strong> {reservation.confirmedCount}/{reservation.maxCapacity}명
                        {reservation.waitingCount > 0 && (
                          <span style={{ 
                            color: '#ffc107', 
                            marginLeft: styles.gap,
                            fontSize: styles.smallSize
                          }}>
                            대기 {reservation.waitingCount}명
                          </span>
                        )}
                      </div>
                    </div>
                    <div style={{ marginTop: '10px' }}>
                      <div style={{
                        width: '100%',
                        height: '8px',
                        backgroundColor: '#e9ecef',
                        borderRadius: '4px',
                        overflow: 'hidden'
                      }}>
                        <div style={{
                          width: `${(reservation.confirmedCount / reservation.maxCapacity) * 100}%`,
                          height: '100%',
                          backgroundColor: reservation.confirmedCount >= reservation.maxCapacity ? '#dc3545' : '#28a745',
                          transition: 'width 0.3s ease'
                        }} />
                      </div>
                      <div style={{ 
                        fontSize: styles.smallSize, 
                        color: '#6c757d', 
                        marginTop: '5px' 
                      }}>
                        {reservation.confirmedCount >= reservation.maxCapacity ? '예약 마감' : '예약 가능'}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div style={{ 
                textAlign: 'center', 
                padding: styles.largePadding, 
                color: '#6c757d' 
              }}>
                <h3 style={{ fontSize: styles.titleSize, marginBottom: styles.marginBottom }}>
                  등록된 예약이 없습니다
                </h3>
                <p style={{ fontSize: styles.bodySize }}>
                  새 예약을 생성해보세요!
                </p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* 예약 생성 모달 */}
      <ReservationModal
        isOpen={showCreateModal}
        onClose={handleCloseCreateModal}
        onSubmit={handleCreateReservation}
        initialDate={selectedDate || undefined}
        isLoading={createReservationMutation.isLoading}
      />

      {/* 예약 상세보기 모달 */}
        <ReservationDetailModal
        isOpen={showDetailModal}
        onClose={handleCloseDetailModal}
        reservation={selectedReservation}
        onEdit={handleEditReservation}   // ✅ 여기 연결
        onDelete={handleDeleteReservation}
        isDeleting={deleteReservationMutation.isLoading}
        canEdit={canEditSelected}
        />
    </div>
  );
};

export default ReservationsPage;