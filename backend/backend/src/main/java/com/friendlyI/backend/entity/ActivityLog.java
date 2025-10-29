package com.friendlyI.backend.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "activity_logs")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ActivityLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long memberId;

    @Column(nullable = false)
    private String memberLoginId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ActivityType activityType;

    @Column(nullable = false, length = 500)
    private String description;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "user_agent", length = 500)
    private String userAgent;

    @Column(name = "request_uri", length = 255)
    private String requestUri;

    @Column(name = "http_method", length = 10)
    private String httpMethod;

    @Column(columnDefinition = "TEXT")
    private String details;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public ActivityLog(Long memberId, String memberLoginId, ActivityType activityType,
            String description, String ipAddress, String userAgent,
            String requestUri, String httpMethod, String details) {
        this.memberId = memberId;
        this.memberLoginId = memberLoginId;
        this.activityType = activityType;
        this.description = description;
        this.ipAddress = ipAddress;
        this.userAgent = userAgent;
        this.requestUri = requestUri;
        this.httpMethod = httpMethod;
        this.details = details;
    }

    public enum ActivityType {
        LOGIN("로그인"),
        LOGOUT("로그아웃"),
        MEMBER_CREATE("회원 생성"),
        MEMBER_UPDATE("회원 정보 수정"),
        MEMBER_DELETE("회원 삭제"),
        GRADE_UPGRADE("등급 업그레이드"),
        RESERVATION_CREATE("예약 생성"),
        RESERVATION_UPDATE("예약 수정"),
        RESERVATION_DELETE("예약 삭제"),
        RESERVATION_APPLY("예약 신청"),
        RESERVATION_CANCEL("예약 취소"),
        SEARCH("검색"),
        VIEW("조회"),
        ERROR("오류");

        private final String description;

        ActivityType(String description) {
            this.description = description;
        }

        public String getDescription() {
            return description;
        }
    }
}