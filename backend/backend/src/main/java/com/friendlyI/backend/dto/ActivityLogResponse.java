package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.ActivityLog;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class ActivityLogResponse {
    private Long id;
    private Long memberId;
    private String memberLoginId;
    private ActivityLog.ActivityType activityType;
    private String description;
    private String ipAddress;
    private String requestUri;
    private String httpMethod;
    private LocalDateTime createdAt;

    public static ActivityLogResponse from(ActivityLog activityLog) {
        return ActivityLogResponse.builder()
                .id(activityLog.getId())
                .memberId(activityLog.getMemberId())
                .memberLoginId(activityLog.getMemberLoginId())
                .activityType(activityLog.getActivityType())
                .description(activityLog.getDescription())
                .ipAddress(activityLog.getIpAddress())
                .requestUri(activityLog.getRequestUri())
                .httpMethod(activityLog.getHttpMethod())
                .createdAt(activityLog.getCreatedAt())
                .build();
    }
}