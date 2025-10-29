package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.MemberGrade;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * 로그인 응답 DTO
 */
@Getter
@Builder
@AllArgsConstructor
public class LoginResponse {

    private String token;
    private UserInfo user;

    /**
     * 사용자 정보 내부 클래스
     */
    @Getter
    @Builder
    @AllArgsConstructor
    public static class UserInfo {
        private Long id;
        private String loginId;
        private String name;
        private String email;
        private String phoneNumber;
        private MemberGrade grade;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;
    }
}