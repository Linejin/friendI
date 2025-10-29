package com.friendlyI.backend.config.security;

import com.friendlyI.backend.entity.MemberGrade;
import com.friendlyI.backend.exception.UnauthorizedException;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

@Slf4j
@Aspect
// @Component // 임시 비활성화
@RequiredArgsConstructor
public class AuthorizationAspect {

    private final JwtTokenUtil jwtTokenUtil;

    @Before("@annotation(requireAuth)")
    public void checkAuthorization(JoinPoint joinPoint, RequireAuth requireAuth) {
        HttpServletRequest request = getCurrentRequest();
        String token = extractTokenFromRequest(request);

        if (token == null || !jwtTokenUtil.validateToken(token)) {
            log.warn("인증되지 않은 요청: {}", request.getRequestURI());
            throw new UnauthorizedException("인증이 필요합니다.");
        }

        // 관리자 권한이 필요한 경우
        if (requireAuth.adminOnly() && !jwtTokenUtil.isAdmin(token)) {
            log.warn("관리자 권한이 필요한 요청: {} by {}",
                    request.getRequestURI(), jwtTokenUtil.getLoginIdFromToken(token));
            throw new UnauthorizedException("관리자 권한이 필요합니다.");
        }

        // 특정 역할이 필요한 경우
        String[] requiredRoles = requireAuth.roles();
        if (requiredRoles.length > 0) {
            MemberGrade userGrade = jwtTokenUtil.getGradeFromToken(token);
            boolean hasRequiredRole = false;

            for (String role : requiredRoles) {
                if (userGrade.name().equals(role)) {
                    hasRequiredRole = true;
                    break;
                }
            }

            if (!hasRequiredRole) {
                log.warn("권한이 부족한 요청: {} by {} (required: {})",
                        request.getRequestURI(), userGrade, String.join(",", requiredRoles));
                throw new UnauthorizedException("권한이 부족합니다.");
            }
        }

        log.debug("인증 성공: {} by {}", request.getRequestURI(), jwtTokenUtil.getLoginIdFromToken(token));
    }

    private HttpServletRequest getCurrentRequest() {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes == null) {
            throw new IllegalStateException("요청 컨텍스트를 찾을 수 없습니다.");
        }
        return attributes.getRequest();
    }

    private String extractTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}