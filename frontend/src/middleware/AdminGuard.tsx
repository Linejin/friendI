import React, { useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import LoadingSpinner from '../components/LoadingSpinner';

interface AdminGuardProps {
  children: React.ReactNode;
}

const AdminGuard: React.FC<AdminGuardProps> = ({ children }) => {
  const { user, isAuthenticated, isLoading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    // 로딩 중이면 대기
    if (isLoading) return;

    // 인증되지 않은 경우 로그인 페이지로 리다이렉트
    if (!isAuthenticated) {
      navigate('/login', { 
        state: { 
          from: location.pathname,
          message: '로그인이 필요합니다.' 
        } 
      });
      return;
    }

    // 관리자 권한이 없는 경우 홈페이지로 리다이렉트
    if (user?.grade !== 'ROOSTER') {
      navigate('/', { 
        state: { 
          message: '관리자 권한이 필요합니다. 접근이 거부되었습니다.',
          type: 'error'
        } 
      });
      return;
    }
  }, [user, isAuthenticated, isLoading, navigate, location.pathname]);

  // 로딩 중
  if (isLoading) {
    return <LoadingSpinner message="권한을 확인하는 중..." />;
  }

  // 인증되지 않았거나 관리자가 아닌 경우
  if (!isAuthenticated || user?.grade !== 'ROOSTER') {
    return <LoadingSpinner message="접근 권한을 확인하는 중..." />;
  }

  // 관리자인 경우에만 컴포넌트 렌더링
  return <>{children}</>;
};

export default AdminGuard;