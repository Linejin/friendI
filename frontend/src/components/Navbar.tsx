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

  return (
    <nav className="navbar">
      <div className="navbar-content">
        <Link to="/" className="navbar-brand">
          친해지고 싶은 아이들 🐤
        </Link>
        
        {isAuthenticated ? (
          <>
            <ul className="navbar-nav">
              {/* 공통 메뉴 */}
              <li>
                <Link 
                  to="/" 
                  className={`nav-link ${location.pathname === '/' ? 'active' : ''}`}
                >
                  🏠 홈
                </Link>
              </li>
              
              {/* 관리자 전용 메뉴 */}
              {isAdmin && (
                <>
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
                </>
              )}
              
              {/* 일반 사용자 메뉴 */}
              {!isAdmin && (
                <>
                  <li>
                    <Link 
                      to="/reservations" 
                      className={`nav-link ${location.pathname === '/reservations' ? 'active' : ''}`}
                    >
                      📅 예약 참가
                    </Link>
                  </li>
                </>
              )}
              
              {/* 공통 메뉴 */}
              <li>
                <Link 
                  to="/profile" 
                  className={`nav-link ${location.pathname === '/profile' ? 'active' : ''}`}
                >
                  👤 내 정보
                </Link>
              </li>
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