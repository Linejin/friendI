import React, { useState, useEffect } from 'react';
import { useForm, useFieldArray } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import { useQueryClient } from 'react-query';
import * as yup from 'yup';
import { ReservationCreateRequest, LocationInfo } from '../types';
import { useAuth } from '../contexts/AuthContext';
import { CACHE_KEYS } from '../config/queryConfig';

const locationSchema = yup.object({
  name: yup.string().required('장소명은 필수입니다'),
  address: yup.string().optional(),
  url: yup.string()
    .required('장소 URL은 필수입니다')
    .test('is-naver-url', '네이버 URL만 허용됩니다 (예: https://map.naver.com/... or https://naver.me/...)', (value) => {
      if (!value) return false;
      return value.includes('naver.com') || value.includes('naver.me');
    })
});

const reservationSchema = yup.object({
  title: yup.string().required('제목은 필수입니다'),
  description: yup.string().required('설명은 필수입니다'),
  reservationDate: yup.string().required('예약 날짜는 필수입니다'),
  reservationTime: yup.string().required('예약 시간은 필수입니다'),
  maxCapacity: yup.number().min(1, '최대 인원은 1명 이상이어야 합니다').required('최대 인원은 필수입니다'),
  locations: yup.array().of(locationSchema).min(1, '최소 1개의 장소는 필요합니다').required('장소는 필수입니다')
}).test('datetime-validation', '과거 시간에는 예약을 생성할 수 없습니다', function(values) {
  const { reservationDate, reservationTime } = values;
  if (reservationDate && reservationTime) {
    const selectedDateTime = new Date(`${reservationDate}T${reservationTime}`);
    const now = new Date();
    return selectedDateTime >= now;
  }
  return true;
});

interface ReservationModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: ReservationCreateRequest) => Promise<void>;
  initialDate?: Date;
  isLoading?: boolean;
}

const ReservationModal: React.FC<ReservationModalProps> = ({
  isOpen,
  onClose,
  onSubmit,
  initialDate,
  isLoading = false
}) => {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const { register, handleSubmit, formState: { errors }, reset, control, setValue, watch } = useForm<ReservationCreateRequest>({
    resolver: yupResolver(reservationSchema),
    defaultValues: {
      reservationDate: '', // 초기값을 비워둠
      reservationTime: '10:00',
      locations: [{ name: '', address: '', url: '' }],
      title: '',
      description: '',
      maxCapacity: 1
    }
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: 'locations'
  });

  // 현재 폼 값 모니터링
  const watchedDate = watch('reservationDate');
  const watchedTime = watch('reservationTime');
  
  useEffect(() => {
    console.log('📝 Form values changed:');
    console.log('   - watchedDate:', watchedDate);
    console.log('   - watchedTime:', watchedTime);
  }, [watchedDate, watchedTime]);

  // 모달이 열릴 때 폼 초기화
  useEffect(() => {
    console.log('🔍 ReservationModal useEffect triggered');
    console.log('   - isOpen:', isOpen);
    console.log('   - initialDate:', initialDate);
    
    if (isOpen) {
      const dateToUse = initialDate || new Date();
      
      // Helper function for padding (ES5 compatible)
      const padZero = (num: number): string => {
        return num < 10 ? `0${num}` : `${num}`;
      };
      
      // 로컬 시간대를 고려한 날짜 문자열 생성
      const year = dateToUse.getFullYear();
      const month = padZero(dateToUse.getMonth() + 1);
      const day = padZero(dateToUse.getDate());
      const dateString = `${year}-${month}-${day}`;
      
      const timeString = initialDate 
        ? `${padZero(initialDate.getHours())}:${padZero(initialDate.getMinutes())}`
        : '10:00';
      
      console.log('📅 Setting form values:');
      console.log('   - originalDate:', dateToUse);
      console.log('   - dateString:', dateString);
      console.log('   - timeString:', timeString);
      
      // reset과 setValue 둘 다 사용
      setTimeout(() => {
        console.log('⚡ Executing form reset and setValue');
        
        // 먼저 개별 값 설정
        setValue('reservationDate', dateString);
        setValue('reservationTime', timeString);
        setValue('maxCapacity', 1);
        
        // 그 다음 전체 리셋
        reset({
          reservationDate: dateString,
          reservationTime: timeString,
          locations: [{ name: '', address: '', url: '' }],
          title: '',
          description: '',
          maxCapacity: 1
        });
        
        console.log('✅ Form reset and setValue completed');
      }, 50); // 더 긴 지연시간
    }
  }, [isOpen, initialDate, reset, setValue]);

  // 활성 장소 목록 로드
  const handleFormSubmit = async (data: ReservationCreateRequest) => {
    if (!user) {
      alert('로그인이 필요합니다.');
      return;
    }
    
    const requestData = {
      ...data,
      creatorMemberId: user.id
    };
    
    try {
      await onSubmit(requestData);
      
      // 예약 생성 완료 후 모든 관련 캐시 무효화
      queryClient.invalidateQueries(CACHE_KEYS.reservations);
      queryClient.invalidateQueries(CACHE_KEYS.availableReservations);
      queryClient.invalidateQueries(CACHE_KEYS.futureReservations);
      
      reset();
    } catch (error) {
      console.error('예약 생성 실패:', error);
      // onSubmit에서 이미 에러 처리를 하므로 여기서는 로그만 남김
    }
  };

  const handleClose = () => {
    reset();
    onClose();
  };

  if (!isOpen) return null;

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '24px',
        width: '90%',
        maxWidth: '500px',
        maxHeight: '90vh',
        overflow: 'auto'
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
          <h3>📅 새 예약 생성</h3>
          <button
            onClick={handleClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#6c757d'
            }}
          >
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit(handleFormSubmit)}>
          <div className="form-group">
            <label className="form-label">제목 *</label>
            <input
              {...register('title')}
              className="form-input"
              placeholder="예약 제목을 입력하세요"
            />
            {errors.title && <div className="error">{errors.title.message}</div>}
          </div>

          <div className="grid grid-2">
            <div className="form-group">
              <label className="form-label">예약 날짜 * (현재 날짜 이후만 가능)</label>
              <input
                key={`date-${isOpen}-${initialDate?.toISOString()}`}
                {...register('reservationDate')}
                type="date"
                className="form-input"
                min={new Date().toISOString().split('T')[0]} // 당일부터 선택 가능
              />
              {errors.reservationDate && <div className="error">{errors.reservationDate.message}</div>}
            </div>

            <div className="form-group">
              <label className="form-label">예약 시간 * (당일의 경우 현재 시간 이후)</label>
              <input
                key={`time-${isOpen}-${initialDate?.toISOString()}`}
                {...register('reservationTime')}
                type="time"
                className="form-input"
              />
              {errors.reservationTime && <div className="error">{errors.reservationTime.message}</div>}
            </div>
          </div>

          <div className="grid grid-2">
            <div className="form-group">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                <label className="form-label">장소 정보 *</label>
                <button
                  type="button"
                  onClick={() => append({ name: '', address: '', url: '' })}
                  className="button button-success"
                  style={{ fontSize: '14px', padding: '5px 10px' }}
                >
                  + 장소 추가
                </button>
              </div>
              
              {fields.map((field, index) => (
                <div key={field.id} style={{ 
                  border: '1px solid #e0e0e0', 
                  borderRadius: '8px', 
                  padding: '15px', 
                  marginBottom: '15px',
                  backgroundColor: '#f9f9f9'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                    <h4 style={{ margin: 0, fontSize: '16px', color: '#333' }}>
                      📍 장소 {index + 1}
                    </h4>
                    {fields.length > 1 && (
                      <button
                        type="button"
                        onClick={() => remove(index)}
                        className="button button-danger"
                        style={{ fontSize: '12px', padding: '3px 8px' }}
                      >
                        - 제거
                      </button>
                    )}
                  </div>
                  
                  <div className="form-group" style={{ marginBottom: '10px' }}>
                    <label className="form-label">장소명 *</label>
                    <input
                      {...register(`locations.${index}.name` as const)}
                      type="text"
                      className="form-input"
                      placeholder="예: 회의실 A, 카페 스타벅스"
                    />
                    {errors.locations?.[index]?.name && (
                      <div className="error">{errors.locations[index]?.name?.message}</div>
                    )}
                  </div>

                  <div className="form-group" style={{ marginBottom: '10px' }}>
                    <label className="form-label">장소 주소</label>
                    <input
                      {...register(`locations.${index}.address` as const)}
                      type="text"
                      className="form-input"
                      placeholder="예: 서울시 강남구 테헤란로 123 (선택사항)"
                    />
                    {errors.locations?.[index]?.address && (
                      <div className="error">{errors.locations[index]?.address?.message}</div>
                    )}
                  </div>

                  <div className="form-group" style={{ marginBottom: '0' }}>
                    <label className="form-label">네이버 지도 URL *</label>
                    <input
                      {...register(`locations.${index}.url` as const)}
                      type="url"
                      className="form-input"
                      placeholder="예: https://map.naver.com/v5/search/..."
                    />
                    <small style={{ color: '#666', fontSize: '12px', marginTop: '4px', display: 'block' }}>
                      💡 네이버 지도에서 장소를 검색한 후 URL을 복사해 주세요
                    </small>
                    {errors.locations?.[index]?.url && (
                      <div className="error">{errors.locations[index]?.url?.message}</div>
                    )}
                  </div>
                </div>
              ))}
              
              {errors.locations && typeof errors.locations.message === 'string' && (
                <div className="error">{errors.locations.message}</div>
              )}
            </div>

            <div className="form-group">
              <label className="form-label">최대 인원 *</label>
              <input
                {...register('maxCapacity')}
                type="number"
                min="1"
                max="100"
                className="form-input"
                placeholder="최대 참가 인원"
              />
              {errors.maxCapacity && <div className="error">{errors.maxCapacity.message}</div>}
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">설명 *</label>
            <textarea
              {...register('description')}
              className="form-input"
              rows={3}
              placeholder="예약에 대한 상세 설명을 입력하세요"
            />
            {errors.description && <div className="error">{errors.description.message}</div>}
          </div>

          <div style={{ 
            marginTop: '24px', 
            display: 'flex', 
            gap: '10px', 
            justifyContent: 'flex-end' 
          }}>
            <button 
              type="button" 
              onClick={handleClose}
              className="button"
              style={{ backgroundColor: '#6c757d', color: 'white' }}
            >
              취소
            </button>
            <button 
              type="submit" 
              className="button button-primary"
              disabled={isLoading}
            >
              {isLoading ? '생성 중...' : '예약 생성'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ReservationModal;