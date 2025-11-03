import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { GRADE_INFO } from '../types';

const Navbar: React.FC = () => {
  const location = useLocation();
  const { user, isAuthenticated, logout } = useAuth();

  const handleLogout = () => {
    logout();
  };

  // 관리자 여부 확인
  const isAdmin = user?.grade === 'ROOSTER';
  
  // 관리자 페이지 여부 확인
  const isAdminPage = location.pathname.startsWith('/admin') || 
                      location.pathname.startsWith('/members');

  // 메뉴 생성 함수
  const renderNavMenu = () => {
    const commonMenus = [
      { path: '/', label: '🏠 홈', isHome: true },
      { path: '/profile', label: '👤 내 정보' }
    ];

    if (isAdminPage && isAdmin) {
      // 관리자 페이지에서는 관리자 메뉴 전체 표시
      return (
        <>
          <li>
            <Link to="/" className="nav-link">🏠 홈</Link>
          </li>
          <li className="nav-divider">
            <span className="nav-section-title">관리자 메뉴</span>
          </li>
          <li>
            <Link 
              to="/admin" 
              className={`nav-link admin-link ${location.pathname === '/admin' ? 'active' : ''}`}
            >
              🛠️ 대시보드
            </Link>
          </li>
          <li>
            <Link 
              to="/members" 
              className={`nav-link admin-link ${location.pathname === '/members' ? 'active' : ''}`}
            >
              👥 회원관리
            </Link>
          </li>
          <li>
            <Link 
              to="/reservations" 
              className={`nav-link admin-link ${location.pathname === '/reservations' ? 'active' : ''}`}
            >
              📅 예약관리
            </Link>
          </li>
          <li>
            <Link to="/profile" className="nav-link">👤 내 정보</Link>
          </li>
        </>
      );
    } else {
      // 일반 페이지에서는 기본 메뉴만 표시
      return (
        <>
          <li>
            <Link 
              to="/" 
              className={`nav-link ${location.pathname === '/' ? 'active' : ''}`}
            >
              🏠 홈
            </Link>
          </li>
          <li>
            <Link 
              to="/reservations" 
              className={`nav-link ${location.pathname === '/reservations' ? 'active' : ''}`}
            >
              📅 {isAdmin ? '예약관리' : '예약 참가'}
            </Link>
          </li>
          <li>
            <Link 
              to="/profile" 
              className={`nav-link ${location.pathname.startsWith('/profile') ? 'active' : ''}`}
            >
              👤 내 정보
            </Link>
          </li>
          {/* 관리자라면 관리자 페이지 링크 추가 */}
          {isAdmin && (
            <li>
              <Link to="/admin" className="nav-link admin-link">
                🛠️ 관리자 페이지
              </Link>
            </li>
          )}
        </>
      );
    }
  };

  return (
    <nav className="navbar">
      <div className="navbar-content">
        <Link to="/" className="navbar-brand">
          친해지고 싶은 아이들 🐤
        </Link>
        
        {isAuthenticated ? (
          <>
            <ul className="navbar-nav">
              {renderNavMenu()}
            </ul>
            
            <div className="navbar-user">
              <span className={`user-info ${isAdmin ? 'admin-user' : 'regular-user'}`}>
                <span className="user-grade">{GRADE_INFO[user!.grade].emoji}</span>
                <span className="user-name">{user!.name}</span>
                {isAdmin && <span className="admin-badge">관리자</span>}
              </span>
              <button onClick={handleLogout} className="logout-button">
                🚪 로그아웃
              </button>
            </div>
          </>
        ) : (
          <div className="navbar-auth">
            <Link to="/login" className="login-link">
              로그인
            </Link>
          </div>
        )}
      </div>
    </nav>
  );
};

export default Navbar;