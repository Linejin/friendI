import React from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Link } from 'react-router-dom';

const SecurityTestPage: React.FC = () => {
  const { user, isAuthenticated } = useAuth();

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">🔐 보안 테스트 페이지</h1>
        <p className="page-description">
          현재 사용자의 권한을 확인하고 관리자 페이지 접근을 테스트합니다.
        </p>
      </div>

      <div className="grid grid-2">
        <div className="card">
          <h3>👤 현재 사용자 정보</h3>
          <div style={{ marginTop: '15px' }}>
            <div style={{ marginBottom: '10px' }}>
              <strong>인증 상태:</strong> {isAuthenticated ? '✅ 인증됨' : '❌ 인증 안됨'}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>사용자 ID:</strong> {user?.id || 'N/A'}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>로그인 ID:</strong> {user?.loginId || 'N/A'}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>이름:</strong> {user?.name || 'N/A'}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>등급:</strong> {user?.grade || 'N/A'}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>관리자 권한:</strong> {user?.grade === 'ROOSTER' ? '✅ 있음' : '❌ 없음'}
            </div>
          </div>
        </div>

        <div className="card">
          <h3>🛡️ 접근 테스트</h3>
          <div style={{ marginTop: '15px' }}>
            <p style={{ marginBottom: '15px', fontSize: '14px', color: '#6c757d' }}>
              아래 링크를 클릭하여 권한 검증이 올바르게 작동하는지 확인하세요.
            </p>
            
            <div style={{ marginBottom: '15px' }}>
              <Link 
                to="/admin" 
                className="button button-primary"
                style={{ width: '100%', textAlign: 'center', display: 'block' }}
              >
                🔧 관리자 페이지 접근 시도
              </Link>
              <small style={{ color: '#6c757d', fontSize: '12px' }}>
                관리자가 아닌 경우 접근이 차단됩니다.
              </small>
            </div>

            <div style={{ marginBottom: '15px' }}>
              <Link 
                to="/" 
                className="button button-success"
                style={{ width: '100%', textAlign: 'center', display: 'block' }}
              >
                🏠 홈페이지로 이동
              </Link>
            </div>

            <div>
              <Link 
                to="/profile" 
                className="button button-secondary"
                style={{ width: '100%', textAlign: 'center', display: 'block' }}
              >
                👤 프로필 페이지로 이동
              </Link>
            </div>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginTop: '20px' }}>
        <h3>📋 보안 정책</h3>
        <div style={{ marginTop: '15px' }}>
          <ul style={{ paddingLeft: '20px', lineHeight: '1.6' }}>
            <li><strong>인증 필수:</strong> 모든 페이지는 로그인이 필요합니다.</li>
            <li><strong>관리자 전용:</strong> <code>/admin</code> 경로는 ROOSTER 등급만 접근 가능합니다.</li>
            <li><strong>자동 리다이렉트:</strong> 권한이 없는 경우 자동으로 적절한 페이지로 이동합니다.</li>
            <li><strong>보안 로깅:</strong> 모든 관리자 페이지 접근 시도가 기록됩니다.</li>
            <li><strong>실시간 검증:</strong> 페이지 로드 시마다 권한을 재확인합니다.</li>
          </ul>
        </div>
      </div>
    </div>
  );
};

export default SecurityTestPage;