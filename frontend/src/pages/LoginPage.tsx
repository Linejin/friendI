import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { LoginRequest } from '../types';
import LoadingSpinner from '../components/LoadingSpinner';

const loginSchema = yup.object({
  loginId: yup.string().required('아이디를 입력해주세요'),
  password: yup.string().required('비밀번호를 입력해주세요')
});

const LoginPage: React.FC = () => {
  const { login, isAuthenticated, isLoading } = useAuth();
  const [loginError, setLoginError] = useState<string>('');
  const location = useLocation();
  const navigate = useNavigate();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting }
  } = useForm<LoginRequest>({
    resolver: yupResolver(loginSchema)
  });

  // 이미 로그인된 경우 홈으로 리다이렉트
  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  const onSubmit = async (data: LoginRequest) => {
    try {
      setLoginError('');
      await login(data);
      // 로그인 성공 시 원래 페이지로 이동하거나 홈으로 이동
      const from = (location.state as any)?.from?.pathname || '/';
      navigate(from, { replace: true });
    } catch (error: any) {
      setLoginError(error.response?.data?.message || '로그인에 실패했습니다.');
    }
  };

  if (isLoading) {
    return <LoadingSpinner message="인증 정보를 확인하는 중..." />;
  }

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <h1>친아이 로그인 🐤</h1>
          <p>친해지고 싶은 아이들 예약 시스템</p>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="login-form">
          {loginError && (
            <div className="error-message">
              {loginError}
            </div>
          )}

          <div className="form-group">
            <label htmlFor="loginId" className="form-label">
              아이디
            </label>
            <input
              type="text"
              id="loginId"
              {...register('loginId')}
              className={`form-input ${errors.loginId ? 'error' : ''}`}
              placeholder="아이디를 입력하세요"
            />
            {errors.loginId && (
              <span className="field-error">{errors.loginId.message}</span>
            )}
          </div>

          <div className="form-group">
            <label htmlFor="password" className="form-label">
              비밀번호
            </label>
            <input
              type="password"
              id="password"
              {...register('password')}
              className={`form-input ${errors.password ? 'error' : ''}`}
              placeholder="비밀번호를 입력하세요"
            />
            {errors.password && (
              <span className="field-error">{errors.password.message}</span>
            )}
          </div>

          <button
            type="submit"
            disabled={isSubmitting}
            className="login-button"
          >
            {isSubmitting ? '로그인 중...' : '로그인'}
          </button>
        </form>

        <div className="login-footer">
          <p>계정이 없으신가요? 관리자에게 문의해주세요.</p>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;