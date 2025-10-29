import React from 'react';

interface ErrorMessageProps {
  message: string;
  onRetry?: () => void;
}

const ErrorMessage: React.FC<ErrorMessageProps> = ({ message, onRetry }) => {
  return (
    <div className="card" style={{ textAlign: 'center', color: '#dc3545' }}>
      <h3>❌ 오류 발생</h3>
      <p>{message}</p>
      {onRetry && (
        <button 
          className="button button-primary" 
          onClick={onRetry}
          style={{ marginTop: '10px' }}
        >
          다시 시도
        </button>
      )}
    </div>
  );
};

export default ErrorMessage;