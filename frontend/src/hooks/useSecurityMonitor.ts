import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

/**
 * URL 접근을 모니터링하고 보안 로그를 기록하는 훅
 */
export const useSecurityMonitor = () => {
  const location = useLocation();
  const { user, isAuthenticated } = useAuth();

  useEffect(() => {
    // 관리자 페이지 접근 시도 로깅
    if (location.pathname.startsWith('/admin')) {
      const securityLog = {
        timestamp: new Date().toISOString(),
        path: location.pathname,
        userId: user?.id || 'anonymous',
        userGrade: user?.grade || 'none',
        isAuthenticated,
        isAuthorized: user?.grade === 'ROOSTER',
        userAgent: navigator.userAgent,
        ip: 'client-side', // 실제 환경에서는 서버에서 처리
        sessionId: localStorage.getItem('authToken') ? 'authenticated' : 'anonymous'
      };

      // 보안 로그 기록
      console.group(`🔐 [Security Monitor] Admin Access Attempt`);
      console.log('📍 Path:', location.pathname);
      console.log('👤 User:', user?.name || 'Anonymous');
      console.log('🏆 Grade:', user?.grade || 'None');
      console.log('✅ Authorized:', user?.grade === 'ROOSTER');
      console.log('📊 Full Log:', securityLog);
      console.groupEnd();

      // 실제 운영 환경에서는 서버로 보안 로그 전송
      if (process.env.NODE_ENV === 'production') {
        // sendSecurityLogToServer(securityLog);
      }

      // 권한이 없는 접근 시도인 경우 경고
      if (!user || user.grade !== 'ROOSTER') {
        console.warn(`🚨 [Security Alert] Unauthorized admin access attempt from user: ${user?.loginId || 'anonymous'}`);
      }
    }

    // 일반적인 페이지 접근 로깅 (개발 환경에서만)
    if (process.env.NODE_ENV === 'development') {
      console.log(`🌐 [Navigation] ${location.pathname} accessed by ${user?.name || 'anonymous'}`);
    }
  }, [location.pathname, user, isAuthenticated]);
};

/**
 * 서버로 보안 로그를 전송하는 함수 (실제 구현 시 사용)
 */
const sendSecurityLogToServer = async (logData: any) => {
  try {
    // 실제 API 엔드포인트로 보안 로그 전송
    await fetch('/api/security/log', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${localStorage.getItem('authToken')}`
      },
      body: JSON.stringify(logData)
    });
  } catch (error) {
    console.error('Failed to send security log:', error);
  }
};