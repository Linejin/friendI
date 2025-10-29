import React from 'react';
import { useAuth } from '../contexts/AuthContext';
import ErrorMessage from './ErrorMessage';

interface AdminRouteProps {
  children: React.ReactNode;
}

const AdminRoute: React.FC<AdminRouteProps> = ({ children }) => {
  const { user } = useAuth();

  // 관리자 권한 확인
  if (user?.grade !== 'ROOSTER') {
    return (
      <ErrorMessage 
        message="관리자 권한이 필요합니다. 접근이 제한된 페이지입니다." 
      />
    );
  }

  return <>{children}</>;
};

export default AdminRoute;