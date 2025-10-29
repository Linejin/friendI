import React from 'react';
import { useAuth } from '../contexts/AuthContext';
import HomePage from './HomePage';
import AdminDashboard from './AdminDashboard';

const DashboardRouter: React.FC = () => {
  const { user } = useAuth();

  // 관리자 권한 확인 (ROOSTER 등급)
  const isAdmin = user?.grade === 'ROOSTER';

  return isAdmin ? <AdminDashboard /> : <HomePage />;
};

export default DashboardRouter;