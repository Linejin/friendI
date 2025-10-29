package com.friendlyI.backend.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.filter.CommonsRequestLoggingFilter;

/**
 * 로깅 설정 (보안 고려)
 */
@Configuration
@Slf4j
public class LoggingConfig {

    @Bean
    public CommonsRequestLoggingFilter requestLoggingFilter() {
        CommonsRequestLoggingFilter loggingFilter = new CommonsRequestLoggingFilter();

        // 요청/응답 로깅 설정 (민감정보 제외)
        loggingFilter.setIncludeClientInfo(false); // IP 주소 등은 별도 보안 로깅
        loggingFilter.setIncludeQueryString(false); // 쿼리 파라미터에 민감정보 가능성
        loggingFilter.setIncludePayload(false); // 요청 본문에 비밀번호 등 민감정보 가능성
        loggingFilter.setIncludeHeaders(false); // 헤더에 토큰 등 민감정보 가능성

        loggingFilter.setMaxPayloadLength(0); // 페이로드 로깅 비활성화
        loggingFilter.setAfterMessagePrefix("REQUEST: ");

        return loggingFilter;
    }
}