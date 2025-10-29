package com.friendlyI.backend.config;

/**
 * 보안 관련 상수
 */
public final class SecurityConstants {

    // 비밀번호 정책
    public static final int PASSWORD_MIN_LENGTH = 8;
    public static final int PASSWORD_MAX_LENGTH = 20;
    public static final String PASSWORD_PATTERN = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,20}$";

    // 로그인 ID 정책
    public static final int LOGIN_ID_MIN_LENGTH = 4;
    public static final int LOGIN_ID_MAX_LENGTH = 20;
    public static final String LOGIN_ID_PATTERN = "^[a-zA-Z0-9_]{4,20}$";

    // 세션 및 토큰 설정
    public static final int SESSION_TIMEOUT_MINUTES = 30;
    public static final int PASSWORD_RETRY_LIMIT = 5;
    public static final int ACCOUNT_LOCK_DURATION_MINUTES = 30;

    // 보안 헤더
    public static final String CONTENT_TYPE_OPTIONS = "nosniff";
    public static final String FRAME_OPTIONS = "DENY";
    public static final long HSTS_MAX_AGE = 31536000L; // 1년

    private SecurityConstants() {
        // 유틸리티 클래스
    }
}