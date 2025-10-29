package com.friendlyI.backend.config.security;

import com.friendlyI.backend.entity.MemberGrade;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;

@Slf4j
@Component
public class JwtTokenUtil {

    @Value("${jwt.secret:friendly-i-secret-key-for-jwt-token-generation-please-change-in-production}")
    private String secretKey;

    @Value("${jwt.expiration:86400000}") // 24시간
    private long expirationTime;

    @Value("${jwt.refresh-expiration:604800000}") // 7일
    private long refreshExpirationTime;

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(secretKey.getBytes());
    }

    /**
     * JWT 토큰 생성
     */
    public String generateToken(String loginId, Long memberId, MemberGrade grade) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + expirationTime);

        return Jwts.builder()
                .subject(loginId)
                .claim("memberId", memberId)
                .claim("grade", grade.name())
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(getSigningKey())
                .compact();
    }

    /**
     * 리프레시 토큰 생성
     */
    public String generateRefreshToken(String loginId) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + refreshExpirationTime);

        return Jwts.builder()
                .subject(loginId)
                .claim("type", "refresh")
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(getSigningKey())
                .compact();
    }

    /**
     * 토큰에서 로그인 ID 추출
     */
    public String getLoginIdFromToken(String token) {
        return getClaimsFromToken(token).getSubject();
    }

    /**
     * 토큰에서 회원 ID 추출
     */
    public Long getMemberIdFromToken(String token) {
        return getClaimsFromToken(token).get("memberId", Long.class);
    }

    /**
     * 토큰에서 회원 등급 추출
     */
    public MemberGrade getGradeFromToken(String token) {
        String grade = getClaimsFromToken(token).get("grade", String.class);
        return MemberGrade.valueOf(grade);
    }

    /**
     * 토큰 유효성 검증
     */
    public boolean validateToken(String token) {
        try {
            getClaimsFromToken(token);
            return true;
        } catch (Exception e) {
            log.warn("토큰 검증 실패: {}", e.getMessage());
            return false;
        }
    }

    /**
     * 토큰 만료 여부 확인
     */
    public boolean isTokenExpired(String token) {
        try {
            Date expiration = getClaimsFromToken(token).getExpiration();
            return expiration.before(new Date());
        } catch (Exception e) {
            return true;
        }
    }

    /**
     * 토큰에서 Claims 추출
     */
    private Claims getClaimsFromToken(String token) {
        return Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    /**
     * 관리자 권한 확인
     */
    public boolean isAdmin(String token) {
        try {
            MemberGrade grade = getGradeFromToken(token);
            return grade == MemberGrade.ROOSTER;
        } catch (Exception e) {
            return false;
        }
    }
}