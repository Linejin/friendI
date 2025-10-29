import React, { useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export interface RouteGuardConfig {
  requireAuth?: boolean;
  requireAdmin?: boolean;
  redirectTo?: string;
  message?: string;
}

interface RouteGuardProps {
  children: React.ReactNode;
  config: RouteGuardConfig;
}

/**
 * 라우트 접근 제어를 위한 미들웨어 컴포넌트
 * 인증, 권한, 리다이렉션을 관리합니다.
 */
const RouteGuard: React.FC<RouteGuardProps> = ({ children, config }) => {
  const { user, isAuthenticated, isLoading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const {
    requireAuth = false,
    requireAdmin = false,
    redirectTo = '/',
    message = '접근 권한이 없습니다.'
  } = config;

  useEffect(() => {
    // 로딩 중이면 대기
    if (isLoading) return;

    // 인증이 필요한 페이지인데 인증되지 않은 경우
    if (requireAuth && !isAuthenticated) {
      navigate('/login', {
        state: {
          from: location.pathname,
          message: '로그인이 필요합니다.',
          type: 'warning'
        }
      });
      return;
    }

    // 관리자 권한이 필요한 페이지인데 관리자가 아닌 경우
    if (requireAdmin && (!isAuthenticated || user?.grade !== 'ROOSTER')) {
      // 콘솔에 보안 로그 기록
      console.warn(`[Security] Unauthorized admin access attempt:`, {
        userId: user?.id,
        userGrade: user?.grade,
        attemptedPath: location.pathname,
        timestamp: new Date().toISOString(),
        userAgent: navigator.userAgent
      });

      navigate(redirectTo, {
        state: {
          message: message,
          type: 'error',
          originalPath: location.pathname
        }
      });
      return;
    }
  }, [
    user, 
    isAuthenticated, 
    isLoading, 
    navigate, 
    location.pathname, 
    requireAuth, 
    requireAdmin, 
    redirectTo, 
    message
  ]);

  // 로딩 중
  if (isLoading) {
    return null; // 또는 로딩 스피너
  }

  // 인증이 필요한데 인증되지 않은 경우
  if (requireAuth && !isAuthenticated) {
    return null;
  }

  // 관리자 권한이 필요한데 관리자가 아닌 경우
  if (requireAdmin && (!isAuthenticated || user?.grade !== 'ROOSTER')) {
    return null;
  }

  return <>{children}</>;
};

export default RouteGuard;