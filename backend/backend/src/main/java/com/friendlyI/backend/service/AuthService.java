package com.friendlyI.backend.service;

import com.friendlyI.backend.dto.LoginRequest;
import com.friendlyI.backend.dto.LoginResponse;
import com.friendlyI.backend.entity.Member;
import com.friendlyI.backend.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 인증 서비스
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class AuthService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;

    /**
     * 로그인 처리
     */
    @Transactional
    public LoginResponse login(LoginRequest request) {
        // 사용자 조회
        Member member = memberRepository.findByLoginId(request.getLoginId())
                .orElseThrow(() -> new RuntimeException("존재하지 않는 사용자입니다"));

        // 비밀번호 검증
        if (!passwordEncoder.matches(request.getPassword(), member.getPassword())) {
            throw new RuntimeException("비밀번호가 일치하지 않습니다");
        }

        // JWT 토큰 생성 (현재는 임시로 "dummy-token" 사용)
        String token = "dummy-token-" + member.getId();

        // 응답 생성
        return LoginResponse.builder()
                .token(token)
                .user(LoginResponse.UserInfo.builder()
                        .id(member.getId())
                        .loginId(member.getLoginId())
                        .name(member.getName())
                        .email(member.getEmail() != null ? member.getEmail() : "")
                        .phoneNumber(member.getPhoneNumber() != null ? member.getPhoneNumber() : "")
                        .grade(member.getGrade())
                        .createdAt(member.getCreatedAt())
                        .updatedAt(member.getUpdatedAt())
                        .build())
                .build();
    }

    /**
     * 현재 사용자 정보 조회 (임시로 admin 사용자 정보 반환)
     */
    public LoginResponse getCurrentUserInfo() {
        // 현재는 임시로 admin 사용자 정보 반환
        Member admin = memberRepository.findByLoginId("admin")
                .orElseThrow(() -> new RuntimeException("관리자 계정을 찾을 수 없습니다"));

        return LoginResponse.builder()
                .token("dummy-token-" + admin.getId())
                .user(LoginResponse.UserInfo.builder()
                        .id(admin.getId())
                        .loginId(admin.getLoginId())
                        .name(admin.getName())
                        .email(admin.getEmail() != null ? admin.getEmail() : "")
                        .phoneNumber(admin.getPhoneNumber() != null ? admin.getPhoneNumber() : "")
                        .grade(admin.getGrade())
                        .createdAt(admin.getCreatedAt())
                        .updatedAt(admin.getUpdatedAt())
                        .build())
                .build();
    }
}