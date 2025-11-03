import React, { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { useMutation, useQueryClient } from 'react-query';
import { memberService } from '../api/members';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import LoadingSpinner from '../components/LoadingSpinner';
import ErrorMessage from '../components/ErrorMessage';
import ChangePasswordModal from '../components/ChangePasswordModal';
import { Member } from '../types';

interface UpdateProfileRequest {
  name: string;
  email: string;
  phoneNumber: string;
}

const updateProfileSchema = yup.object({
  name: yup
    .string()
    .required('이름을 입력해주세요')
    .min(2, '이름은 2글자 이상이어야 합니다')
    .max(50, '이름은 50글자 이하여야 합니다'),
  email: yup
    .string()
    .required('이메일을 입력해주세요')
    .email('올바른 이메일 형식이 아닙니다')
    .max(100, '이메일은 100글자 이하여야 합니다'),
  phoneNumber: yup
    .string()
    .required('전화번호를 입력해주세요')
    .matches(/^010-\d{4}-\d{4}$/, '전화번호 형식이 올바르지 않습니다 (예: 010-1234-5678)')
});

const EditProfilePage: React.FC = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [updateError, setUpdateError] = useState<string>('');
  const [updateSuccess, setUpdateSuccess] = useState<boolean>(false);
  const [showPasswordModal, setShowPasswordModal] = useState<boolean>(false);

  // 화면 크기 상태
  const [screenSize, setScreenSize] = useState({
    width: window.innerWidth,
    height: window.innerHeight
  });

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

  // 반응형 스타일
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
      inputHeight: isMobile ? '40px' : '44px',
      buttonHeight: isMobile ? '40px' : '44px',
      maxWidth: isMobile ? '100%' : isTablet ? '600px' : '500px'
    };
  };

  const styles = getResponsiveStyles();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    reset
  } = useForm<UpdateProfileRequest>({
    resolver: yupResolver(updateProfileSchema),
    defaultValues: {
      name: user?.name || '',
      email: user?.email || '',
      phoneNumber: user?.phoneNumber || ''
    }
  });

  // 프로필 업데이트 뮤테이션
  const updateProfileMutation = useMutation(
    (data: UpdateProfileRequest) => {
      if (!user?.id) throw new Error('사용자 정보를 찾을 수 없습니다');
      return memberService.updateMember(user.id, data);
    },
    {
      onSuccess: (updatedUser: Member) => {
        setUpdateError('');
        setUpdateSuccess(true);
        // 사용자 정보 캐시 업데이트
        queryClient.invalidateQueries(['member', user?.id]);
        // AuthContext의 사용자 정보도 업데이트해야 함 (추후 구현)
        
        // 3초 후 프로필 페이지로 이동
        setTimeout(() => {
          navigate('/profile');
        }, 3000);
      },
      onError: (error: any) => {
        console.error('프로필 업데이트 실패:', error);
        setUpdateError(
          error.response?.data?.message || 
          '프로필 업데이트에 실패했습니다. 다시 시도해주세요.'
        );
        setUpdateSuccess(false);
      }
    }
  );

  const onSubmit = async (data: UpdateProfileRequest) => {
    try {
      setUpdateError('');
      setUpdateSuccess(false);
      await updateProfileMutation.mutateAsync(data);
    } catch (error) {
      // 에러는 뮤테이션의 onError에서 처리됨
    }
  };

  // 사용자 정보가 없으면 로그인 페이지로 이동
  if (!user) {
    navigate('/login');
    return null;
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
    <div style={{ 
      padding: styles.containerPadding,
      maxWidth: styles.maxWidth,
      margin: '0 auto'
    }}>
      <div className="page-header" style={{ marginBottom: styles.marginBottom }}>
        <h1 className="page-title" style={{ 
          fontSize: styles.titleSize,
          margin: `0 0 ${styles.gap} 0`,
          display: 'flex',
          alignItems: 'center',
          gap: styles.gap
        }}>
          ✏️ 내 정보 수정
        </h1>
        <p className="page-description" style={{
          fontSize: styles.bodySize,
          margin: 0,
          lineHeight: '1.5',
          color: '#6c757d'
        }}>
          개인정보를 안전하게 수정할 수 있습니다.
        </p>
      </div>

      {/* 현재 사용자 정보 표시 */}
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
            fontSize: '40px', 
            lineHeight: '1',
            marginBottom: screenSize.width < 600 ? '8px' : '0'
          }}>
            {getGradeEmoji(user.grade)}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
              <h2 style={{ 
                margin: 0, 
                fontSize: styles.headerSize,
                fontWeight: 'bold',
              }}>
                {user.name}
              </h2>
              <span style={{ 
                fontSize: styles.bodySize,
                opacity: 0.9,
                color: 'white'
              }}>
                @{user.loginId}
              </span>
              <div style={{ 
                backgroundColor: 'rgba(255, 255, 255, 0.2)',
                padding: '2px 8px',
                borderRadius: '12px',
                fontSize: styles.bodySize,
                fontWeight: 'bold'
              }}>
                {getGradeName(user.grade)} 등급
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 업데이트 성공 메시지 */}
      {updateSuccess && (
        <div style={{
          padding: styles.cardPadding,
          marginBottom: styles.marginBottom,
          backgroundColor: '#d4edda',
          border: '1px solid #c3e6cb',
          borderRadius: '8px',
          color: '#155724'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '20px' }}>✅</span>
            <div>
              <strong style={{ fontSize: styles.headerSize }}>프로필이 성공적으로 업데이트되었습니다!</strong>
              <p style={{ fontSize: styles.bodySize, margin: '4px 0 0 0' }}>
                3초 후 프로필 페이지로 이동합니다...
              </p>
            </div>
          </div>
        </div>
      )}

      {/* 에러 메시지 */}
      {updateError && (
        <div style={{
          padding: styles.cardPadding,
          marginBottom: styles.marginBottom,
          backgroundColor: '#f8d7da',
          border: '1px solid #f5c6cb',
          borderRadius: '8px',
          color: '#721c24'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '20px' }}>❌</span>
            <div>
              <strong style={{ fontSize: styles.headerSize }}>업데이트 실패</strong>
              <p style={{ fontSize: styles.bodySize, margin: '4px 0 0 0' }}>
                {updateError}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* 수정 폼 */}
      <div className="card" style={{ padding: styles.cardPadding }}>
        <h3 style={{ 
          fontSize: styles.headerSize, 
          margin: `0 0 ${styles.marginBottom} 0`,
          color: '#495057',
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}>
          📝 개인정보 수정
        </h3>

        <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: styles.gap }}>
          {/* 이름 */}
          <div>
            <label htmlFor="name" style={{
              display: 'block',
              fontSize: styles.bodySize,
              fontWeight: 'bold',
              color: '#495057',
              marginBottom: '6px'
            }}>
              이름 *
            </label>
            <input
              type="text"
              id="name"
              {...register('name')}
              style={{
                width: '100%',
                height: styles.inputHeight,
                padding: '0 12px',
                border: errors.name ? '2px solid #dc3545' : '1px solid #ced4da',
                borderRadius: '6px',
                fontSize: styles.bodySize,
                outline: 'none',
                transition: 'border-color 0.2s',
                boxSizing: 'border-box'
              }}
              placeholder="이름을 입력하세요"
            />
            {errors.name && (
              <p style={{
                fontSize: styles.bodySize,
                color: '#dc3545',
                margin: '4px 0 0 0'
              }}>
                {errors.name.message}
              </p>
            )}
          </div>

          {/* 이메일 */}
          <div>
            <label htmlFor="email" style={{
              display: 'block',
              fontSize: styles.bodySize,
              fontWeight: 'bold',
              color: '#495057',
              marginBottom: '6px'
            }}>
              이메일 *
            </label>
            <input
              type="email"
              id="email"
              {...register('email')}
              style={{
                width: '100%',
                height: styles.inputHeight,
                padding: '0 12px',
                border: errors.email ? '2px solid #dc3545' : '1px solid #ced4da',
                borderRadius: '6px',
                fontSize: styles.bodySize,
                outline: 'none',
                transition: 'border-color 0.2s',
                boxSizing: 'border-box'
              }}
              placeholder="이메일을 입력하세요"
            />
            {errors.email && (
              <p style={{
                fontSize: styles.bodySize,
                color: '#dc3545',
                margin: '4px 0 0 0'
              }}>
                {errors.email.message}
              </p>
            )}
          </div>

          {/* 전화번호 */}
          <div>
            <label htmlFor="phoneNumber" style={{
              display: 'block',
              fontSize: styles.bodySize,
              fontWeight: 'bold',
              color: '#495057',
              marginBottom: '6px'
            }}>
              전화번호 *
            </label>
            <input
              type="tel"
              id="phoneNumber"
              {...register('phoneNumber')}
              style={{
                width: '100%',
                height: styles.inputHeight,
                padding: '0 12px',
                border: errors.phoneNumber ? '2px solid #dc3545' : '1px solid #ced4da',
                borderRadius: '6px',
                fontSize: styles.bodySize,
                outline: 'none',
                transition: 'border-color 0.2s',
                boxSizing: 'border-box'
              }}
              placeholder="010-1234-5678"
            />
            {errors.phoneNumber && (
              <p style={{
                fontSize: styles.bodySize,
                color: '#dc3545',
                margin: '4px 0 0 0'
              }}>
                {errors.phoneNumber.message}
              </p>
            )}
            <p style={{
              fontSize: styles.bodySize,
              color: '#6c757d',
              margin: '4px 0 0 0'
            }}>
              010-0000-0000 형식으로 입력해주세요
            </p>
          </div>

          {/* 버튼들 */}
          <div style={{ 
            display: 'flex', 
            gap: styles.gap,
            marginTop: styles.marginBottom,
            flexDirection: screenSize.width < 600 ? 'column' : 'row'
          }}>
            <button
              type="submit"
              disabled={isSubmitting || updateProfileMutation.isLoading}
              style={{
                height: styles.buttonHeight,
                padding: '0 24px',
                backgroundColor: isSubmitting || updateProfileMutation.isLoading ? '#6c757d' : '#007bff',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                fontSize: styles.bodySize,
                fontWeight: 'bold',
                cursor: isSubmitting || updateProfileMutation.isLoading ? 'not-allowed' : 'pointer',
                transition: 'background-color 0.2s',
                flex: screenSize.width < 600 ? '1' : '0 0 auto',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px'
              }}
            >
              {(isSubmitting || updateProfileMutation.isLoading) ? (
                <>
                  <span>⏳</span>
                  <span>업데이트 중...</span>
                </>
              ) : (
                <>
                  <span>💾</span>
                  <span>저장하기</span>
                </>
              )}
            </button>

            <button
              type="button"
              onClick={() => navigate('/profile')}
              disabled={isSubmitting || updateProfileMutation.isLoading}
              style={{
                height: styles.buttonHeight,
                padding: '0 24px',
                backgroundColor: 'transparent',
                color: '#6c757d',
                border: '1px solid #6c757d',
                borderRadius: '6px',
                fontSize: styles.bodySize,
                fontWeight: 'bold',
                cursor: isSubmitting || updateProfileMutation.isLoading ? 'not-allowed' : 'pointer',
                transition: 'all 0.2s',
                flex: screenSize.width < 600 ? '1' : '0 0 auto',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px'
              }}
              onMouseEnter={(e) => {
                if (!isSubmitting && !updateProfileMutation.isLoading) {
                  e.currentTarget.style.backgroundColor = '#6c757d';
                  e.currentTarget.style.color = 'white';
                }
              }}
              onMouseLeave={(e) => {
                if (!isSubmitting && !updateProfileMutation.isLoading) {
                  e.currentTarget.style.backgroundColor = 'transparent';
                  e.currentTarget.style.color = '#6c757d';
                }
              }}
            >
              <span>↩️</span>
              <span>취소</span>
            </button>
          </div>
        </form>
      </div>

      {/* 비밀번호 변경 섹션 */}
      <div className="card" style={{ 
        padding: styles.cardPadding,
        marginTop: styles.marginBottom,
        borderLeft: '4px solid #28a745'
      }}>
        <div style={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: 'flex-start',
          flexDirection: screenSize.width < 600 ? 'column' : 'row',
          gap: styles.gap
        }}>
          <div>
            <h3 style={{ 
              fontSize: styles.headerSize, 
              margin: `0 0 ${styles.gap} 0`,
              color: '#495057',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}>
              🔐 보안 설정
            </h3>
            <p style={{
              fontSize: styles.bodySize,
              margin: 0,
              color: '#6c757d',
              lineHeight: '1.5'
            }}>
              계정 보안을 위해 정기적으로 비밀번호를 변경해주세요.
            </p>
          </div>
          
          <button
            type="button"
            onClick={() => setShowPasswordModal(true)}
            disabled={isSubmitting || updateProfileMutation.isLoading}
            style={{
              height: styles.buttonHeight,
              padding: '0 20px',
              backgroundColor: '#28a745',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontSize: styles.bodySize,
              fontWeight: 'bold',
              cursor: isSubmitting || updateProfileMutation.isLoading ? 'not-allowed' : 'pointer',
              transition: 'background-color 0.2s',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              whiteSpace: 'nowrap',
              alignSelf: screenSize.width < 600 ? 'stretch' : 'flex-start'
            }}
            onMouseEnter={(e) => {
              if (!isSubmitting && !updateProfileMutation.isLoading) {
                e.currentTarget.style.backgroundColor = '#218838';
              }
            }}
            onMouseLeave={(e) => {
              if (!isSubmitting && !updateProfileMutation.isLoading) {
                e.currentTarget.style.backgroundColor = '#28a745';
              }
            }}
          >
            <span>🔑</span>
            <span>비밀번호 변경</span>
          </button>
        </div>
      </div>

      {/* 안내 사항 */}
      <div className="card" style={{ 
        padding: styles.cardPadding,
        marginTop: styles.marginBottom,
        backgroundColor: '#f8f9fa'
      }}>
        <h4 style={{ 
          fontSize: styles.bodySize, 
          margin: `0 0 ${styles.gap} 0`,
          color: '#495057',
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}>
          🔒 개인정보 보호 안내
        </h4>
        <ul style={{ 
          margin: 0, 
          paddingLeft: '20px',
          fontSize: styles.bodySize,
          color: '#6c757d',
          lineHeight: '1.5'
        }}>
          <li>수정된 정보는 즉시 반영됩니다</li>
          <li>이메일은 알림 발송에 사용됩니다</li>
          <li>전화번호는 긴급 연락 시에만 사용됩니다</li>
          <li>개인정보는 안전하게 암호화되어 저장됩니다</li>
        </ul>
      </div>

      {/* 비밀번호 변경 모달 */}
      <ChangePasswordModal
        isOpen={showPasswordModal}
        onClose={() => setShowPasswordModal(false)}
      />
    </div>
  );
};

export default EditProfilePage;