import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { useMutation } from 'react-query';
import { authService } from '../api/auth';

interface ChangePasswordRequest {
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

const changePasswordSchema = yup.object({
  currentPassword: yup
    .string()
    .required('현재 비밀번호를 입력해주세요'),
  newPassword: yup
    .string()
    .required('새 비밀번호를 입력해주세요')
    .min(8, '비밀번호는 8글자 이상이어야 합니다')
    .matches(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
      '비밀번호는 대소문자, 숫자, 특수문자를 포함해야 합니다'
    ),
  confirmPassword: yup
    .string()
    .required('비밀번호 확인을 입력해주세요')
    .oneOf([yup.ref('newPassword')], '비밀번호가 일치하지 않습니다')
});

interface ChangePasswordModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const ChangePasswordModal: React.FC<ChangePasswordModalProps> = ({ isOpen, onClose }) => {
  const [changeError, setChangeError] = useState<string>('');
  const [changeSuccess, setChangeSuccess] = useState<boolean>(false);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset
  } = useForm<ChangePasswordRequest>({
    resolver: yupResolver(changePasswordSchema)
  });

  // 비밀번호 변경 뮤테이션 (추후 API 구현 시 사용)
  const changePasswordMutation = useMutation(
    (data: ChangePasswordRequest) => {
      // TODO: 실제 API 호출로 교체
      return new Promise((resolve, reject) => {
        setTimeout(() => {
          if (data.currentPassword === 'wrongpassword') {
            reject(new Error('현재 비밀번호가 올바르지 않습니다'));
          } else {
            resolve('success');
          }
        }, 1000);
      });
    },
    {
      onSuccess: () => {
        setChangeError('');
        setChangeSuccess(true);
        reset();
        
        // 3초 후 모달 닫기
        setTimeout(() => {
          setChangeSuccess(false);
          onClose();
        }, 3000);
      },
      onError: (error: any) => {
        console.error('비밀번호 변경 실패:', error);
        setChangeError(
          error.message || '비밀번호 변경에 실패했습니다. 다시 시도해주세요.'
        );
        setChangeSuccess(false);
      }
    }
  );

  const onSubmit = async (data: ChangePasswordRequest) => {
    try {
      setChangeError('');
      setChangeSuccess(false);
      await changePasswordMutation.mutateAsync(data);
    } catch (error) {
      // 에러는 뮤테이션의 onError에서 처리됨
    }
  };

  const handleClose = () => {
    if (!isSubmitting && !changePasswordMutation.isLoading) {
      reset();
      setChangeError('');
      setChangeSuccess(false);
      onClose();
    }
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
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
      padding: '20px'
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '12px',
        padding: '24px',
        width: '100%',
        maxWidth: '400px',
        maxHeight: '90vh',
        overflow: 'auto',
        position: 'relative',
        boxShadow: '0 10px 25px rgba(0, 0, 0, 0.2)'
      }}>
        {/* 헤더 */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px'
        }}>
          <h3 style={{
            margin: 0,
            fontSize: '18px',
            color: '#495057',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}>
            🔐 비밀번호 변경
          </h3>
          <button
            onClick={handleClose}
            disabled={isSubmitting || changePasswordMutation.isLoading}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: isSubmitting || changePasswordMutation.isLoading ? 'not-allowed' : 'pointer',
              color: '#6c757d',
              padding: '4px'
            }}
          >
            ✕
          </button>
        </div>

        {/* 성공 메시지 */}
        {changeSuccess && (
          <div style={{
            padding: '16px',
            marginBottom: '16px',
            backgroundColor: '#d4edda',
            border: '1px solid #c3e6cb',
            borderRadius: '8px',
            color: '#155724'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '18px' }}>✅</span>
              <div>
                <strong style={{ fontSize: '14px' }}>비밀번호가 성공적으로 변경되었습니다!</strong>
                <p style={{ fontSize: '12px', margin: '4px 0 0 0' }}>
                  3초 후 모달이 닫힙니다...
                </p>
              </div>
            </div>
          </div>
        )}

        {/* 에러 메시지 */}
        {changeError && (
          <div style={{
            padding: '16px',
            marginBottom: '16px',
            backgroundColor: '#f8d7da',
            border: '1px solid #f5c6cb',
            borderRadius: '8px',
            color: '#721c24'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '18px' }}>❌</span>
              <div>
                <strong style={{ fontSize: '14px' }}>변경 실패</strong>
                <p style={{ fontSize: '12px', margin: '4px 0 0 0' }}>
                  {changeError}
                </p>
              </div>
            </div>
          </div>
        )}

        {/* 폼 */}
        <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {/* 현재 비밀번호 */}
          <div>
            <label htmlFor="currentPassword" style={{
              display: 'block',
              fontSize: '14px',
              fontWeight: 'bold',
              color: '#495057',
              marginBottom: '6px'
            }}>
              현재 비밀번호 *
            </label>
            <input
              type="password"
              id="currentPassword"
              {...register('currentPassword')}
              style={{
                width: '100%',
                height: '42px',
                padding: '0 12px',
                border: errors.currentPassword ? '2px solid #dc3545' : '1px solid #ced4da',
                borderRadius: '6px',
                fontSize: '14px',
                outline: 'none',
                transition: 'border-color 0.2s',
                boxSizing: 'border-box'
              }}
              placeholder="현재 비밀번호를 입력하세요"
            />
            {errors.currentPassword && (
              <p style={{
                fontSize: '12px',
                color: '#dc3545',
                margin: '4px 0 0 0'
              }}>
                {errors.currentPassword.message}
              </p>
            )}
          </div>

          {/* 새 비밀번호 */}
          <div>
            <label htmlFor="newPassword" style={{
              display: 'block',
              fontSize: '14px',
              fontWeight: 'bold',
              color: '#495057',
              marginBottom: '6px'
            }}>
              새 비밀번호 *
            </label>
            <input
              type="password"
              id="newPassword"
              {...register('newPassword')}
              style={{
                width: '100%',
                height: '42px',
                padding: '0 12px',
                border: errors.newPassword ? '2px solid #dc3545' : '1px solid #ced4da',
                borderRadius: '6px',
                fontSize: '14px',
                outline: 'none',
                transition: 'border-color 0.2s',
                boxSizing: 'border-box'
              }}
              placeholder="새 비밀번호를 입력하세요"
            />
            {errors.newPassword && (
              <p style={{
                fontSize: '12px',
                color: '#dc3545',
                margin: '4px 0 0 0'
              }}>
                {errors.newPassword.message}
              </p>
            )}
          </div>

          {/* 비밀번호 확인 */}
          <div>
            <label htmlFor="confirmPassword" style={{
              display: 'block',
              fontSize: '14px',
              fontWeight: 'bold',
              color: '#495057',
              marginBottom: '6px'
            }}>
              새 비밀번호 확인 *
            </label>
            <input
              type="password"
              id="confirmPassword"
              {...register('confirmPassword')}
              style={{
                width: '100%',
                height: '42px',
                padding: '0 12px',
                border: errors.confirmPassword ? '2px solid #dc3545' : '1px solid #ced4da',
                borderRadius: '6px',
                fontSize: '14px',
                outline: 'none',
                transition: 'border-color 0.2s',
                boxSizing: 'border-box'
              }}
              placeholder="새 비밀번호를 다시 입력하세요"
            />
            {errors.confirmPassword && (
              <p style={{
                fontSize: '12px',
                color: '#dc3545',
                margin: '4px 0 0 0'
              }}>
                {errors.confirmPassword.message}
              </p>
            )}
          </div>

          {/* 버튼들 */}
          <div style={{ 
            display: 'flex', 
            gap: '12px',
            marginTop: '8px'
          }}>
            <button
              type="submit"
              disabled={isSubmitting || changePasswordMutation.isLoading}
              style={{
                flex: 1,
                height: '42px',
                backgroundColor: isSubmitting || changePasswordMutation.isLoading ? '#6c757d' : '#007bff',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                fontSize: '14px',
                fontWeight: 'bold',
                cursor: isSubmitting || changePasswordMutation.isLoading ? 'not-allowed' : 'pointer',
                transition: 'background-color 0.2s',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px'
              }}
            >
              {(isSubmitting || changePasswordMutation.isLoading) ? (
                <>
                  <span>⏳</span>
                  <span>변경 중...</span>
                </>
              ) : (
                <>
                  <span>🔒</span>
                  <span>변경하기</span>
                </>
              )}
            </button>

            <button
              type="button"
              onClick={handleClose}
              disabled={isSubmitting || changePasswordMutation.isLoading}
              style={{
                flex: 1,
                height: '42px',
                backgroundColor: 'transparent',
                color: '#6c757d',
                border: '1px solid #6c757d',
                borderRadius: '6px',
                fontSize: '14px',
                fontWeight: 'bold',
                cursor: isSubmitting || changePasswordMutation.isLoading ? 'not-allowed' : 'pointer',
                transition: 'all 0.2s'
              }}
            >
              취소
            </button>
          </div>
        </form>

        {/* 안내 사항 */}
        <div style={{
          marginTop: '16px',
          padding: '12px',
          backgroundColor: '#f8f9fa',
          borderRadius: '6px'
        }}>
          <h4 style={{
            fontSize: '12px',
            margin: '0 0 8px 0',
            color: '#495057',
            display: 'flex',
            alignItems: 'center',
            gap: '6px'
          }}>
            💡 비밀번호 규칙
          </h4>
          <ul style={{
            margin: 0,
            paddingLeft: '16px',
            fontSize: '11px',
            color: '#6c757d',
            lineHeight: '1.4'
          }}>
            <li>8글자 이상</li>
            <li>대문자, 소문자, 숫자, 특수문자 포함</li>
            <li>현재 비밀번호와 달라야 함</li>
          </ul>
        </div>
      </div>
    </div>
  );
};

export default ChangePasswordModal;