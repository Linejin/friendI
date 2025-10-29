import React, { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';

interface AlertMessage {
  message: string;
  type: 'success' | 'error' | 'warning' | 'info';
}

const AlertBanner: React.FC = () => {
  const location = useLocation();
  const [alert, setAlert] = useState<AlertMessage | null>(null);

  useEffect(() => {
    // 라우트 state에서 메시지 확인
    const state = location.state as any;
    if (state?.message) {
      setAlert({
        message: state.message,
        type: state.type || 'info'
      });

      // 3초 후 자동으로 알림 제거
      const timer = setTimeout(() => {
        setAlert(null);
      }, 5000);

      return () => clearTimeout(timer);
    }
  }, [location.state]);

  if (!alert) return null;

  const getAlertStyle = (type: string) => {
    const baseStyle = {
      padding: '12px 20px',
      marginBottom: '20px',
      borderRadius: '8px',
      fontWeight: '500',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      animation: 'slideDown 0.3s ease-out'
    };

    switch (type) {
      case 'error':
        return { 
          ...baseStyle, 
          backgroundColor: '#f8d7da', 
          color: '#721c24', 
          border: '1px solid #f5c6cb' 
        };
      case 'warning':
        return { 
          ...baseStyle, 
          backgroundColor: '#fff3cd', 
          color: '#856404', 
          border: '1px solid #ffeaa7' 
        };
      case 'success':
        return { 
          ...baseStyle, 
          backgroundColor: '#d4edda', 
          color: '#155724', 
          border: '1px solid #c3e6cb' 
        };
      default:
        return { 
          ...baseStyle, 
          backgroundColor: '#d1ecf1', 
          color: '#0c5460', 
          border: '1px solid #bee5eb' 
        };
    }
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'error': return '🚨';
      case 'warning': return '⚠️';
      case 'success': return '✅';
      default: return 'ℹ️';
    }
  };

  return (
    <>
      <style>
        {`
          @keyframes slideDown {
            from {
              opacity: 0;
              transform: translateY(-20px);
            }
            to {
              opacity: 1;
              transform: translateY(0);
            }
          }
        `}
      </style>
      <div style={getAlertStyle(alert.type)}>
        <span>
          {getIcon(alert.type)} {alert.message}
        </span>
        <button 
          onClick={() => setAlert(null)}
          style={{
            background: 'none',
            border: 'none',
            fontSize: '18px',
            cursor: 'pointer',
            padding: '0 5px',
            opacity: 0.7
          }}
        >
          ×
        </button>
      </div>
    </>
  );
};

export default AlertBanner;