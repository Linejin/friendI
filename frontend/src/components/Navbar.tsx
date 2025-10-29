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

  return (
    <nav className="navbar">
      <div className="navbar-content">
        <Link to="/" className="navbar-brand">
          친해지고 싶은 아이들 🐤
        </Link>
        
        {isAuthenticated ? (
          <>
            <ul className="navbar-nav">
              <li>
                <Link 
                  to="/" 
                  className={`nav-link ${location.pathname === '/' ? 'active' : ''}`}
                >
                  홈
                </Link>
              </li>
              {user?.grade === 'ROOSTER' && (
                <li>
                  <Link 
                    to="/admin" 
                    className={`nav-link ${location.pathname === '/admin' ? 'active' : ''}`}
                  >
                    관리자
                  </Link>
                </li>
              )}
              <li>
                <Link 
                  to="/reservations" 
                  className={`nav-link ${location.pathname === '/reservations' ? 'active' : ''}`}
                >
                  {user?.grade === 'ROOSTER' ? '예약 관리' : '예약 참가'}
                </Link>
              </li>
              <li>
                <Link 
                  to="/profile" 
                  className={`nav-link ${location.pathname === '/profile' ? 'active' : ''}`}
                >
                  내 정보
                </Link>
              </li>
            </ul>
            
            <div className="navbar-user">
              <span className="user-info">
                {GRADE_INFO[user!.grade].emoji} {user!.name}
              </span>
              <button onClick={handleLogout} className="logout-button">
                로그아웃
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