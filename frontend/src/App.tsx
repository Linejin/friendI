import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import Navbar from './components/Navbar';
import ProtectedRoute from './components/ProtectedRoute';
import RouteGuard from './middleware/RouteGuard';
import AlertBanner from './components/AlertBanner';
import { useSecurityMonitor } from './hooks/useSecurityMonitor';
import HomePage from './pages/HomePage';
import AdminDashboard from './pages/AdminDashboard';
import LoginPage from './pages/LoginPage';
import ReservationsPage from './pages/ReservationsPage';
import ProfilePage from './pages/ProfilePage';
import EditProfilePage from './pages/EditProfilePage';
import SecurityTestPage from './pages/SecurityTestPage';
import './App.css';

// 보안 모니터링을 포함한 메인 앱 컴포넌트
const AppContent: React.FC = () => {
  useSecurityMonitor(); // 보안 모니터링 활성화

  return (
    <div className="App">
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/*" element={
          <>
            <Navbar />
            <main className="container">
              <AlertBanner />
              <Routes>
                <Route path="/" element={
                  <ProtectedRoute>
                    <HomePage />
                  </ProtectedRoute>
                } />
                <Route path="/admin" element={
                  <ProtectedRoute>
                    <RouteGuard config={{ requireAuth: true, requireAdmin: true }}>
                      <AdminDashboard />
                    </RouteGuard>
                  </ProtectedRoute>
                } />
                <Route path="/reservations" element={
                  <ProtectedRoute>
                    <ReservationsPage />
                  </ProtectedRoute>
                } />
                <Route path="/profile" element={
                  <ProtectedRoute>
                    <ProfilePage />
                  </ProtectedRoute>
                } />
                <Route path="/profile/edit" element={
                  <ProtectedRoute>
                    <EditProfilePage />
                  </ProtectedRoute>
                } />
                <Route path="/security-test" element={
                  <ProtectedRoute>
                    <SecurityTestPage />
                  </ProtectedRoute>
                } />
              </Routes>
            </main>
          </>
        } />
      </Routes>
    </div>
  );
};

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;