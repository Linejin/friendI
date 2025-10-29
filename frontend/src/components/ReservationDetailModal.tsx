import React, { useState, useEffect } from 'react';
import { useQueryClient, useQuery } from 'react-query';
import { Reservation, LocationInfo, ReservationApplicant, ReservationStatus } from '../types';
import { reservationService } from '../api/reservations';
import { useAuth } from '../contexts/AuthContext';
import { CACHE_KEYS, queryConfig } from '../config/queryConfig';

interface ReservationDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  reservation: Reservation | null;
  onEdit?: (reservation: Reservation) => void;
  onDelete?: (reservationId: number) => void;
  isDeleting?: boolean;
  canEdit?: boolean;
}

const ReservationDetailModal: React.FC<ReservationDetailModalProps> = ({
  isOpen,
  onClose,
  reservation,
  onEdit,
  onDelete,
  isDeleting = false,
  canEdit = false,
}) => {
  const { user } = useAuth(); // 현재 로그인한 사용자 정보
  const queryClient = useQueryClient(); // React Query 클라이언트
  const [isEditing, setIsEditing] = useState(false);
  const [editData, setEditData] = useState<Reservation | null>(null);
  const [isParticipating, setIsParticipating] = useState(false); // 사용자가 참가 중인지 여부
  const [participationLoading, setParticipationLoading] = useState(false); // 참가/취소 중인지 여부
  const [screenSize, setScreenSize] = useState({
    width: window.innerWidth,
    height: window.innerHeight
  });

  // 예약자 목록 조회 (useQuery 사용)
  const { data: applicants = [], isLoading: loadingApplicants, refetch: refetchApplicants } = useQuery(
    CACHE_KEYS.reservationApplicants(reservation?.id || 0),
    () => reservation?.id ? reservationService.getReservationApplicants(reservation.id) : Promise.resolve([]),
    {
      ...queryConfig.applicants,
      enabled: !!reservation?.id, // reservation이 있을 때만 쿼리 실행
      onError: (error) => {
        console.error('예약자 목록 조회 실패:', error);
      }
    }
  );

  // 예약 상세 정보 조회 (실시간 업데이트용)
  const { data: reservationDetail, refetch: refetchReservationDetail } = useQuery(
    ['reservation-detail', reservation?.id],
    () => reservation?.id ? reservationService.getReservationById(reservation.id) : Promise.resolve(null),
    {
      ...queryConfig.reservations,
      enabled: !!reservation?.id && isOpen, // reservation이 있고 모달이 열려있을 때만 쿼리 실행
      initialData: reservation, // 초기 데이터로 props의 reservation 사용
      onError: (error) => {
        console.error('예약 상세 정보 조회 실패:', error);
      }
    }
  );

  // 실제 사용할 예약 정보 (업데이트된 정보 우선 사용)
  const currentReservation = reservationDetail || reservation;

  // 간단한 편집용 상태
  const [editForm, setEditForm] = useState({
    title: '',
    description: '',
    reservationDate: '',
    reservationTime: '',
    maxCapacity: 1,
    locations: [{ name: '', address: '', url: '' }]
  });

  // 간단한 유효성 검사
  const [errors, setErrors] = useState<{[key: string]: string}>({});

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
      // 모달 크기
      modalWidth: isMobile ? '95%' : isTablet ? '80%' : '500px',
      modalMaxWidth: isMobile ? 'none' : '500px',
      modalPadding: isMobile ? '16px' : '24px',
      
      // 폰트 크기
      titleSize: isMobile ? '18px' : '20px',
      headerSize: isMobile ? '14px' : '16px',
      bodySize: isMobile ? '12px' : '14px',
      smallSize: isMobile ? '10px' : '12px',
      
      // 버튼 크기
      buttonPadding: isMobile ? '6px 12px' : '8px 16px',
      buttonFontSize: isMobile ? '12px' : '14px',
      
      // 간격
      marginBottom: isMobile ? '12px' : '15px',
      gap: isMobile ? '8px' : '10px',
      
      // 그리드
      gridColumns: isMobile ? '1fr' : '1fr 1fr'
    };
  };

  const styles = getResponsiveStyles();

  // 모달이 처음 열릴 때만 편집 상태 초기화
  useEffect(() => {
    if (isOpen && currentReservation) {
      console.log('모달이 열렸음, 편집 상태 초기화');
      setIsEditing(false);
      setEditData(null);
      // 편집 폼 초기화
      setEditForm({
        title: currentReservation.title,
        description: currentReservation.description,
        reservationDate: currentReservation.reservationDate,
        reservationTime: formatTime(currentReservation.reservationTime), // 시간 포맷 적용
        maxCapacity: currentReservation.maxCapacity,
        locations: [{ 
          name: currentReservation.location.name, 
          address: currentReservation.location.address || '', 
          url: currentReservation.location.url 
        }]
      });
      setErrors({});
      
      // 예약자 목록은 useQuery로 자동 관리되므로 별도 호출 불필요
      // 사용자 참가 상태는 applicants가 변경될 때 자동으로 확인됨
    }
  }, [currentReservation?.id, isOpen, user?.id]);

  // 예약자 목록 가져오기
  // 사용자 참가 상태 확인
  const checkUserParticipation = () => {
    if (!currentReservation || !user?.id || !applicants) return;
    
    try {
      const userApplication = applicants.find(
        applicant => applicant.memberId === user.id && 
        (applicant.status === 'CONFIRMED' || applicant.status === 'WAITING')
      );
      setIsParticipating(!!userApplication);
      
      // 디버깅용 로그
      if (userApplication) {
        console.log(`User participation status: ${userApplication.status}`);
      } else {
        console.log('User is not participating in this reservation');
        
        // 취소된 신청이 있는지도 확인
        const cancelledApplication = applicants.find(
          applicant => applicant.memberId === user.id && applicant.status === 'CANCELLED'
        );
        if (cancelledApplication) {
          console.log('User has a cancelled application for this reservation - can reapply');
        }
      }
    } catch (error) {
      console.error('참가 상태 확인 실패:', error);
      setIsParticipating(false);
    }
  };

  // applicants가 변경될 때마다 사용자 참가 상태 확인
  useEffect(() => {
    checkUserParticipation();
  }, [applicants, user?.id, currentReservation?.id]);

  // 예약 참가 신청
  const handleParticipate = async () => {
    if (!currentReservation || !user?.id) return;
    
    // 정원 초과 시 대기 안내
    const isFullyBooked = currentReservation.confirmedCount >= currentReservation.maxCapacity;
    if (isFullyBooked) {
      if (!window.confirm('현재 예약이 마감되었습니다. 대기열에 등록하시겠습니까?\n(다른 참가자가 취소하면 자동으로 확정됩니다)')) {
        return;
      }
    }
    
    setParticipationLoading(true);
    try {
      await reservationService.applyForReservation(currentReservation.id, user.id);
      setIsParticipating(true);
      // 예약자 목록 새로고침
      refetchApplicants();
      
      if (isFullyBooked) {
        alert('대기열에 등록되었습니다. 다른 참가자가 취소하면 자동으로 확정됩니다.');
      } else {
        alert('예약 참가 신청이 완료되었습니다!');
      }
    } catch (error: any) {
      console.error('예약 참가 실패:', error);
      
      // 에러 타입에 따른 구체적인 메시지 제공
      let errorMessage = '예약 참가 신청에 실패했습니다.';
      
      if (error.response?.status === 500) {
        errorMessage = '서버 내부 오류가 발생했습니다. 이전에 취소한 예약을 다시 신청하는 경우일 수 있습니다. 잠시 후 다시 시도해주세요.';
      } else if (error.response?.status === 400) {
        errorMessage = error.response?.data?.message || '잘못된 요청입니다. 이미 신청한 예약일 수 있습니다.';
      } else if (error.response?.status === 404) {
        errorMessage = '예약을 찾을 수 없습니다.';
      } else if (error.response?.status === 401) {
        errorMessage = '로그인이 필요합니다.';
      }
      
      alert(errorMessage);
      
      // 에러 발생 시에도 예약자 목록을 새로고침해서 실제 상태를 확인
      try {
        refetchApplicants();
      } catch (loadError) {
        console.error('예약자 목록 새로고침 실패:', loadError);
      }
    } finally {
      setParticipationLoading(false);
      
      // 참가 신청 완료 후 모든 관련 캐시 무효화
      queryClient.invalidateQueries(CACHE_KEYS.reservations);
      queryClient.invalidateQueries(CACHE_KEYS.availableReservations);
      queryClient.invalidateQueries(CACHE_KEYS.futureReservations);
      if (currentReservation?.id) {
        queryClient.invalidateQueries(CACHE_KEYS.reservationApplicants(currentReservation.id));
        queryClient.invalidateQueries(['reservation-detail', currentReservation.id]);
      }
    }
  };

  // 예약 참가 취소
  const handleCancelParticipation = async () => {
    if (!currentReservation || !user?.id) return;
    
    if (!window.confirm('정말로 예약 참가를 취소하시겠습니까?')) return;
    
    setParticipationLoading(true);
    try {
      // applicants 배열에서 현재 사용자의 활성 신청을 찾기
      const userApplication = applicants.find(
        applicant => applicant.memberId === user.id && 
        (applicant.status === 'CONFIRMED' || applicant.status === 'WAITING')
      );
      
      if (userApplication) {
        await reservationService.cancelReservationApplication(userApplication.applicationId);
        setIsParticipating(false);
        // 예약자 목록 새로고침
        refetchApplicants();
        alert('예약 참가가 취소되었습니다.');
      }
    } catch (error) {
      console.error('예약 참가 취소 실패:', error);
      alert('예약 참가 취소에 실패했습니다. 다시 시도해주세요.');
    } finally {
      setParticipationLoading(false);
      
      // 참가 취소 완료 후 모든 관련 캐시 무효화
      queryClient.invalidateQueries(CACHE_KEYS.reservations);
      queryClient.invalidateQueries(CACHE_KEYS.availableReservations);
      queryClient.invalidateQueries(CACHE_KEYS.futureReservations);
      if (currentReservation?.id) {
        queryClient.invalidateQueries(CACHE_KEYS.reservationApplicants(currentReservation.id));
        queryClient.invalidateQueries(['reservation-detail', currentReservation.id]);
      }
    }
  };

  // isEditing 상태 변경 디버깅
  useEffect(() => {
    console.log('isEditing 상태 변경됨:', isEditing);
    console.log('canEdit 값:', canEdit);
    console.log('reservation:', reservation);
  }, [isEditing, canEdit, reservation]);

  if (!isOpen || !currentReservation) return null;

  // 시간 포맷 함수
  const formatTime = (timeString: string) => {
    if (!timeString) return '';
    // "HH:mm:ss" 형식에서 "HH:mm"만 추출
    return timeString.substring(0, 5);
  };

  // 날짜 포맷 함수
  const formatDate = (dateString: string) => {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('ko-KR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      weekday: 'short'
    });
  };

  // 편집 중이면 폼 데이터를, 아니면 원본 currentReservation을 표시
  const current = isEditing ? {
    ...currentReservation,
    title: editForm.title || currentReservation.title,
    description: editForm.description || currentReservation.description,
    reservationDate: editForm.reservationDate || currentReservation.reservationDate,
    reservationTime: editForm.reservationTime || currentReservation.reservationTime,
    maxCapacity: editForm.maxCapacity || currentReservation.maxCapacity,
    location: editForm.locations?.[0] ? {
      ...currentReservation.location,
      name: editForm.locations[0].name || currentReservation.location.name,
      address: editForm.locations[0].address || currentReservation.location.address,
      url: editForm.locations[0].url || currentReservation.location.url
    } : currentReservation.location
  } : currentReservation;

  const handleDelete = () => {
    if (window.confirm('정말 이 예약을 삭제하시겠습니까?')) {
      onDelete?.(currentReservation.id);
    }
  };

  const startEdit = () => {
    console.log('startEdit 함수 호출됨');
    console.log('현재 currentReservation:', currentReservation);
    console.log('현재 isEditing:', isEditing);
    
    if (!currentReservation) {
      console.log('currentReservation이 없어서 리턴');
      return;
    }
    
    console.log('편집 모드 시작');
    setIsEditing(true);
    setEditData(currentReservation);
    
    // 편집 폼에 현재 데이터 로드
    setEditForm({
      title: currentReservation.title,
      description: currentReservation.description,
      reservationDate: currentReservation.reservationDate,
      reservationTime: formatTime(currentReservation.reservationTime), // 시간 포맷 적용
      maxCapacity: currentReservation.maxCapacity,
      locations: [{ 
        name: currentReservation.location.name, 
        address: currentReservation.location.address || '', 
        url: currentReservation.location.url 
      }]
    });
    
    console.log('startEdit 함수 완료, isEditing을 true로 설정함');
  };

  // 간단한 유효성 검사 함수
  const validateForm = () => {
    const newErrors: {[key: string]: string} = {};
    
    if (!editForm.title.trim()) {
      newErrors.title = '제목은 필수입니다';
    }
    
    if (!editForm.description.trim()) {
      newErrors.description = '설명은 필수입니다';
    }
    
    if (!editForm.reservationDate) {
      newErrors.reservationDate = '예약 날짜는 필수입니다';
    }
    
    if (!editForm.reservationTime) {
      newErrors.reservationTime = '예약 시간은 필수입니다';
    }
    
    if (editForm.maxCapacity < 1) {
      newErrors.maxCapacity = '최대 인원은 1명 이상이어야 합니다';
    }
    
    if (!editForm.locations[0]?.name.trim()) {
      newErrors['location.name'] = '장소명은 필수입니다';
    }
    
    if (!editForm.locations[0]?.url.trim()) {
      newErrors['location.url'] = '장소 URL은 필수입니다';
    } else {
      const url = editForm.locations[0].url;
      if (!url.includes('naver.com') && !url.includes('naver.me')) {
        newErrors['location.url'] = '네이버 URL만 허용됩니다 (예: https://map.naver.com/... or https://naver.me/...)';
      }
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!reservation || !onEdit) return;

    // 유효성 검사
    if (!validateForm()) {
      return;
    }

    // 현재 확정 인원보다 적은 최대 인원은 불가
    if (editForm.maxCapacity < reservation.confirmedCount) {
      alert('최대 인원은 현재 확정된 인원보다 적을 수 없습니다.');
      return;
    }

    try {
      // 첫 번째 장소만 사용 (현재 시스템에서는 단일 장소)
      const updatedReservation: Reservation = {
        ...reservation,
        title: editForm.title,
        description: editForm.description,
        reservationDate: editForm.reservationDate,
        reservationTime: editForm.reservationTime,
        maxCapacity: editForm.maxCapacity,
        location: {
          ...currentReservation.location,
          name: editForm.locations[0].name,
          address: editForm.locations[0].address,
          url: editForm.locations[0].url
        }
      };

      onEdit(updatedReservation);
      
      // 편집 모드 종료하되 모달은 유지
      setIsEditing(false);
      setEditData(null);
      
      // 성공 메시지 표시
      alert('예약이 성공적으로 수정되었습니다.');
    } catch (error) {
      console.error('ReservationDetailModal - Error in handleFormSubmit:', error);
      alert('수정 저장 중 오류가 발생했습니다: ' + (error instanceof Error ? error.message : String(error)));
    }
  };

  const isFull = current.confirmedCount >= current.maxCapacity;
  const progressPercentage = (current.confirmedCount / current.maxCapacity) * 100;

  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)', display: 'flex',
      justifyContent: 'center', alignItems: 'center', zIndex: 1000,
      padding: styles.modalPadding
    }}>
      <div style={{
        backgroundColor: 'white', 
        borderRadius: '8px', 
        padding: styles.modalPadding,
        width: styles.modalWidth, 
        maxWidth: styles.modalMaxWidth, 
        maxHeight: '90vh', 
        overflow: 'auto',
        boxSizing: 'border-box'
      }}>
        <div style={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: 'center', 
          marginBottom: styles.marginBottom,
          flexWrap: 'wrap',
          gap: styles.gap
        }}>
          <h3 style={{ 
            margin: 0, 
            fontSize: styles.titleSize,
            flexShrink: 0
          }}>📅 예약 상세정보</h3>
          <button
            onClick={onClose}
            style={{ 
              background: 'none', 
              border: 'none', 
              fontSize: styles.headerSize, 
              cursor: 'pointer', 
              color: '#6c757d',
              padding: '4px',
              minWidth: '24px',
              minHeight: '24px'
            }}
          >
            ×
          </button>
        </div>

        <form onSubmit={handleFormSubmit}>
          <div style={{ marginBottom: styles.marginBottom }}>
            <div style={{ 
              padding: styles.modalPadding, 
              backgroundColor: '#f8f9fa', 
              borderRadius: '8px', 
              marginBottom: styles.marginBottom 
            }}>
              {isEditing ? (
                <div>
                  <div style={{ marginBottom: styles.gap }}>
                    <input
                      type="text"
                      value={editForm.title}
                      onChange={(e) => setEditForm({...editForm, title: e.target.value})}
                      placeholder="예약 제목"
                      style={{ 
                        width: '100%', 
                        padding: styles.gap,
                        border: errors.title ? '1px solid #dc3545' : '1px solid #ddd',
                        borderRadius: '4px',
                        fontSize: styles.bodySize,
                        boxSizing: 'border-box'
                      }}
                    />
                    {errors.title && <div style={{ 
                      color: '#dc3545', 
                      fontSize: styles.smallSize, 
                      marginTop: '5px' 
                    }}>{errors.title}</div>}
                  </div>
                  <div>
                    <textarea
                      value={editForm.description}
                      onChange={(e) => setEditForm({...editForm, description: e.target.value})}
                      rows={3}
                      placeholder="예약 설명"
                      style={{ 
                        width: '100%',
                        padding: styles.gap,
                        border: errors.description ? '1px solid #dc3545' : '1px solid #ddd',
                        borderRadius: '4px',
                        fontSize: styles.bodySize,
                        boxSizing: 'border-box',
                        resize: 'vertical',
                        minHeight: '60px'
                      }}
                    />
                    {errors.description && <div style={{ 
                      color: '#dc3545', 
                      fontSize: styles.smallSize, 
                      marginTop: '5px' 
                    }}>{errors.description}</div>}
                  </div>
                </div>
              ) : (
                <>
                  <h4 style={{ 
                    margin: '0 0 10px 0', 
                    color: '#343a40',
                    fontSize: styles.headerSize
                  }}>{current.title}</h4>
                  <p style={{ 
                    margin: '0', 
                    color: '#6c757d',
                    fontSize: styles.bodySize,
                    lineHeight: '1.5'
                  }}>{current.description}</p>
                </>
              )}
            </div>

            {isEditing ? (
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                gap: styles.marginBottom 
              }}>
                {/* 날짜/시간과 인원을 한 행에 */}
                <div style={{ 
                  display: 'grid', 
                  gridTemplateColumns: styles.gridColumns, 
                  gap: styles.marginBottom 
                }}>
                  <div>
                    <strong style={{ fontSize: styles.bodySize }}>📅 날짜 및 시간</strong>
                    <div style={{ 
                      marginTop: '5px', 
                      display: 'flex', 
                      gap: styles.gap,
                      flexDirection: screenSize.width < 480 ? 'column' : 'row'
                    }}>
                      <div style={{ flex: '1' }}>
                        <input
                          type="date"
                          value={editForm.reservationDate}
                          onChange={(e) => setEditForm({...editForm, reservationDate: e.target.value})}
                          style={{ 
                            width: '100%',
                            padding: styles.gap, 
                            border: errors.reservationDate ? '1px solid #dc3545' : '1px solid #ddd', 
                            borderRadius: '4px',
                            fontSize: styles.bodySize,
                            boxSizing: 'border-box'
                          }}
                          min={new Date().toISOString().split('T')[0]}
                        />
                        {errors.reservationDate && <div style={{ 
                          color: '#dc3545', 
                          fontSize: styles.smallSize, 
                          marginTop: '2px' 
                        }}>{errors.reservationDate}</div>}
                      </div>
                      <div style={{ width: screenSize.width < 480 ? '100%' : '120px' }}>
                        <input
                          type="time"
                          value={editForm.reservationTime}
                          onChange={(e) => setEditForm({...editForm, reservationTime: e.target.value})}
                          style={{ 
                            width: '100%',
                            padding: styles.gap, 
                            border: errors.reservationTime ? '1px solid #dc3545' : '1px solid #ddd', 
                            borderRadius: '4px',
                            fontSize: styles.bodySize,
                            boxSizing: 'border-box'
                          }}
                        />
                        {errors.reservationTime && <div style={{ 
                          color: '#dc3545', 
                          fontSize: styles.smallSize, 
                          marginTop: '2px' 
                        }}>{errors.reservationTime}</div>}
                      </div>
                    </div>
                  </div>

                  <div>
                    <strong>👥 참가 인원</strong>
                    <div style={{ marginTop: '5px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <span style={{ color: '#28a745', fontWeight: 'bold' }}>
                        {current.confirmedCount}/
                      </span>
                      <div>
                        <input
                          type="number"
                          value={editForm.maxCapacity}
                          onChange={(e) => setEditForm({...editForm, maxCapacity: parseInt(e.target.value) || 1})}
                          min="1"
                          max="100"
                          style={{ 
                            width: '60px', 
                            padding: '2px 5px', 
                            border: errors.maxCapacity ? '1px solid #dc3545' : '1px solid #ddd', 
                            borderRadius: '4px',
                            textAlign: 'center'
                          }}
                        />
                        {errors.maxCapacity && <div style={{ color: '#dc3545', fontSize: '12px', marginTop: '2px' }}>{errors.maxCapacity}</div>}
                      </div>
                      <span style={{ fontWeight: 'bold' }}>명</span>
                      {current.waitingCount > 0 && (
                        <span style={{ marginLeft: '10px', color: '#ffc107' }}>
                          대기 {current.waitingCount}명
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                {/* 장소는 별도 행으로 - 단일 장소만 지원 */}
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                    <strong>📍 장소</strong>
                  </div>
                  <div style={{ border: '1px solid #ddd', borderRadius: '8px', padding: '15px', backgroundColor: '#f8f9fa' }}>
                    <div style={{ marginBottom: '10px' }}>
                      <input
                        type="text"
                        value={editForm.locations[0]?.name || ''}
                        onChange={(e) => {
                          const newLocations = [...editForm.locations];
                          newLocations[0] = { ...newLocations[0], name: e.target.value };
                          setEditForm({...editForm, locations: newLocations});
                        }}
                        placeholder="장소명"
                        style={{ 
                          width: '100%', 
                          padding: '8px', 
                          border: errors['location.name'] ? '1px solid #dc3545' : '1px solid #ddd', 
                          borderRadius: '4px' 
                        }}
                      />
                      {errors['location.name'] && <div style={{ color: '#dc3545', fontSize: '12px', marginTop: '2px' }}>{errors['location.name']}</div>}
                    </div>
                    <div style={{ marginBottom: '10px' }}>
                      <input
                        type="text"
                        value={editForm.locations[0]?.address || ''}
                        onChange={(e) => {
                          const newLocations = [...editForm.locations];
                          newLocations[0] = { ...newLocations[0], address: e.target.value };
                          setEditForm({...editForm, locations: newLocations});
                        }}
                        placeholder="주소 (선택사항)"
                        style={{ 
                          width: '100%', 
                          padding: '8px', 
                          border: '1px solid #ddd', 
                          borderRadius: '4px' 
                        }}
                      />
                    </div>
                    <div>
                      <input
                        type="url"
                        value={editForm.locations[0]?.url || ''}
                        onChange={(e) => {
                          const newLocations = [...editForm.locations];
                          newLocations[0] = { ...newLocations[0], url: e.target.value };
                          setEditForm({...editForm, locations: newLocations});
                        }}
                        placeholder="네이버 지도 URL"
                        style={{ 
                          width: '100%', 
                          padding: '8px', 
                          border: errors['location.url'] ? '1px solid #dc3545' : '1px solid #ddd', 
                          borderRadius: '4px' 
                        }}
                      />
                      {errors['location.url'] && <div style={{ color: '#dc3545', fontSize: '12px', marginTop: '2px' }}>{errors['location.url']}</div>}
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <>
                {/* 조회 모드 */}
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                    <strong>📅 날짜 및 시간</strong>
                    <div style={{ textAlign: 'right' }}>
                      <div style={{ fontWeight: 'bold' }}>
                        {formatDate(current.reservationDate)}
                      </div>
                      <div style={{ fontSize: '14px', color: '#007bff' }}>
                        {formatTime(current.reservationTime)}
                      </div>
                    </div>
                  </div>
                  
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                    <strong>📍 장소</strong>
                    <div style={{ textAlign: 'right' }}>
                      <div>{current.location.name}</div>
                      {current.location.address && (
                        <div style={{ fontSize: '12px', color: '#6c757d' }}>{current.location.address}</div>
                      )}
                      {current.location.url && (
                        <a 
                          href={current.location.url} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          style={{ fontSize: '12px', color: '#007bff' }}
                        >
                          지도 보기
                        </a>
                      )}
                    </div>
                  </div>
                </div>
              </>
            )}

            <div style={{ marginTop: '20px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                <strong>예약 현황</strong>
                <span style={{ fontSize: '14px', color: '#6c757d' }}>
                  {current.confirmedCount}/{current.maxCapacity}명
                  {current.waitingCount > 0 && (
                    <span style={{ marginLeft: '8px', color: '#ffc107' }}>
                      (대기 {current.waitingCount}명)
                    </span>
                  )}
                </span>
              </div>
              
              <div style={{ 
                width: '100%', 
                height: '8px', 
                backgroundColor: '#e9ecef', 
                borderRadius: '4px',
                overflow: 'hidden'
              }}>
                <div style={{
                  width: `${progressPercentage}%`,
                  height: '100%',
                  backgroundColor: isFull ? '#dc3545' : '#28a745',
                  transition: 'width 0.3s ease'
                }} />
              </div>
              
              {isFull && (
                <div style={{ 
                  fontSize: '12px', 
                  color: '#dc3545', 
                  marginTop: '5px',
                  textAlign: 'center'
                }}>
                  예약이 마감되었습니다
                </div>
              )}
            </div>

            {/* 예약자 현황 섹션 */}
            <div style={{ marginTop: '20px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                <strong>예약자 현황</strong>
                <button
                  onClick={() => refetchApplicants()}
                  disabled={loadingApplicants}
                  style={{
                    padding: '4px 8px',
                    border: '1px solid #6c757d',
                    borderRadius: '4px',
                    backgroundColor: 'white',
                    color: '#6c757d',
                    cursor: loadingApplicants ? 'not-allowed' : 'pointer',
                    fontSize: '12px'
                  }}
                >
                  {loadingApplicants ? '로딩...' : '새로고침'}
                </button>
              </div>
              
              {loadingApplicants ? (
                <div style={{ textAlign: 'center', padding: '20px', color: '#6c757d' }}>
                  로딩 중...
                </div>
              ) : applicants.length > 0 ? (
                <div style={{ 
                  maxHeight: '200px', 
                  overflowY: 'auto',
                  border: '1px solid #e0e0e0',
                  borderRadius: '4px',
                  backgroundColor: '#f8f9fa'
                }}>
                  {applicants.map((applicant, index) => (
                    <div 
                      key={applicant.memberId}
                      style={{ 
                        padding: '8px 12px',
                        borderBottom: index < applicants.length - 1 ? '1px solid #e0e0e0' : 'none',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span style={{ fontWeight: 'bold' }}>
                          {applicant.memberName}
                        </span>
                        {applicant.creator && (
                          <span style={{ 
                            backgroundColor: '#007bff',
                            color: 'white',
                            padding: '2px 8px',
                            borderRadius: '12px',
                            fontSize: '12px',
                            fontWeight: 'bold',         // (옵션) 텍스트 기준선 간격 조정
                          }}>
                            생성자
                          </span>
                        )}
                        {/* <span style={{ fontSize: '12px', color: '#6c757d' }}>
                          ({applicant.memberLoginId})
                        </span> */}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span 
                          style={{ 
                            padding: '2px 8px',
                            borderRadius: '12px',
                            fontSize: '12px',
                            fontWeight: 'bold',
                            backgroundColor: 
                              applicant.status === ReservationStatus.CONFIRMED ? '#28a745' :
                              applicant.status === ReservationStatus.WAITING ? '#ffc107' :
                              applicant.status === ReservationStatus.CANCELLED ? '#dc3545' : '#6c757d',
                            color: 'white'
                          }}
                        >
                          {applicant.status === ReservationStatus.CONFIRMED ? '확정' :
                           applicant.status === ReservationStatus.WAITING ? '대기' :
                           applicant.status === ReservationStatus.CANCELLED ? '취소' : '미정'}
                        </span>
                        <span style={{ fontSize: '10px', color: '#6c757d' }}>
                          {new Date(applicant.appliedAt).toLocaleDateString()}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{ 
                  textAlign: 'center', 
                  padding: '20px', 
                  color: '#6c757d',
                  border: '1px solid #e0e0e0',
                  borderRadius: '4px',
                  backgroundColor: '#f8f9fa'
                }}>
                  아직 신청한 회원이 없습니다.
                </div>
              )}
            </div>
          </div>

          <div style={{ 
            display: 'flex', 
            gap: styles.gap, 
            justifyContent: screenSize.width < 480 ? 'stretch' : 'flex-end',
            flexDirection: screenSize.width < 480 ? 'column' : 'row',
            marginTop: styles.marginBottom
          }}>
            {isEditing ? (
              <>
                <button
                  type="button"
                  onClick={() => {
                    setIsEditing(false);
                    setEditData(null);
                    setErrors({});
                  }}
                  style={{
                    padding: styles.buttonPadding,
                    border: '1px solid #6c757d',
                    borderRadius: '4px',
                    backgroundColor: 'white',
                    color: '#6c757d',
                    cursor: 'pointer',
                    fontSize: styles.buttonFontSize,
                    minHeight: '36px'
                  }}
                >
                  취소
                </button>
                <button
                  type="submit"
                  style={{
                    padding: styles.buttonPadding,
                    border: 'none',
                    borderRadius: '4px',
                    backgroundColor: '#28a745',
                    color: 'white',
                    cursor: 'pointer',
                    fontSize: styles.buttonFontSize,
                    minHeight: '36px'
                  }}
                >
                  수정 완료
                </button>
              </>
            ) : (
              <>
                {canEdit && (
                  <button
                    type="button"
                    onClick={startEdit}
                    style={{
                      padding: styles.buttonPadding,
                      border: '1px solid #007bff',
                      borderRadius: '4px',
                      backgroundColor: 'white',
                      color: '#007bff',
                      cursor: 'pointer',
                      fontSize: styles.buttonFontSize,
                      minHeight: '36px'
                    }}
                  >
                    수정
                  </button>
                )}
                
                {canEdit && onDelete && (
                  <button
                    type="button"
                    onClick={handleDelete}
                    disabled={isDeleting}
                    style={{
                      padding: styles.buttonPadding,
                      border: 'none',
                      borderRadius: '4px',
                      backgroundColor: isDeleting ? '#6c757d' : '#dc3545',
                      color: 'white',
                      cursor: isDeleting ? 'not-allowed' : 'pointer',
                      fontSize: styles.buttonFontSize,
                      minHeight: '36px'
                    }}
                  >
                    {isDeleting ? '삭제 중...' : '삭제'}
                  </button>
                )}
                
                {/* 생성자가 아닌 경우 참가/취소 버튼 표시 */}
                {user && user.id !== currentReservation?.creatorId && (
                  <>
                    {!isParticipating ? (
                      <button
                        type="button"
                        onClick={handleParticipate}
                        disabled={participationLoading}
                        style={{
                          padding: styles.buttonPadding,
                          border: 'none',
                          borderRadius: '4px',
                          backgroundColor: participationLoading ? '#6c757d' : 
                                           currentReservation?.confirmedCount >= currentReservation?.maxCapacity ? '#ffc107' : '#28a745',
                          color: 'white',
                          cursor: participationLoading ? 'not-allowed' : 'pointer',
                          fontSize: styles.buttonFontSize,
                          minHeight: '36px'
                        }}
                      >
                        {participationLoading ? '처리 중...' : 
                         currentReservation?.confirmedCount >= currentReservation?.maxCapacity ? '대기 등록' : '참가 신청'}
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={handleCancelParticipation}
                        disabled={participationLoading}
                        style={{
                          padding: styles.buttonPadding,
                          border: 'none',
                          borderRadius: '4px',
                          backgroundColor: participationLoading ? '#6c757d' : '#dc3545',
                          color: 'white',
                          cursor: participationLoading ? 'not-allowed' : 'pointer',
                          fontSize: styles.buttonFontSize,
                          minHeight: '36px'
                        }}
                      >
                        {participationLoading ? '처리 중...' : '참가 취소'}
                      </button>
                    )}
                  </>
                )}
                
                <button
                  type="button"
                  onClick={onClose}
                  style={{
                    padding: styles.buttonPadding,
                    border: '1px solid #6c757d',
                    borderRadius: '4px',
                    backgroundColor: 'white',
                    color: '#6c757d',
                    cursor: 'pointer',
                    fontSize: styles.buttonFontSize,
                    minHeight: '36px'
                  }}
                >
                  닫기
                </button>
              </>
            )}
          </div>
        </form>
      </div>
    </div>
  );
};

export default ReservationDetailModal;