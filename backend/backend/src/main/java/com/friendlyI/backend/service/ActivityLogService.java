package com.friendlyI.backend.service;

import com.friendlyI.backend.entity.ActivityLog;
import com.friendlyI.backend.repository.ActivityLogRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ActivityLogService {

    private final ActivityLogRepository activityLogRepository;

    /**
     * 활동 로그 기록 (비동기)
     */
    @Async
    @Transactional
    public void logActivity(Long memberId, String memberLoginId,
            ActivityLog.ActivityType activityType, String description) {
        try {
            HttpServletRequest request = getCurrentRequest();
            String ipAddress = getClientIpAddress(request);
            String userAgent = request.getHeader("User-Agent");
            String requestUri = request.getRequestURI();
            String httpMethod = request.getMethod();

            ActivityLog activityLog = ActivityLog.builder()
                    .memberId(memberId)
                    .memberLoginId(memberLoginId)
                    .activityType(activityType)
                    .description(description)
                    .ipAddress(ipAddress)
                    .userAgent(userAgent)
                    .requestUri(requestUri)
                    .httpMethod(httpMethod)
                    .build();

            activityLogRepository.save(activityLog);

            log.info("활동 로그 기록: {} - {} ({})", memberLoginId, description, activityType);
        } catch (Exception e) {
            log.error("활동 로그 기록 실패: {}", e.getMessage(), e);
        }
    }

    /**
     * 상세 정보와 함께 활동 로그 기록
     */
    @Async
    @Transactional
    public void logActivityWithDetails(Long memberId, String memberLoginId,
            ActivityLog.ActivityType activityType,
            String description, String details) {
        try {
            HttpServletRequest request = getCurrentRequest();
            String ipAddress = getClientIpAddress(request);
            String userAgent = request.getHeader("User-Agent");
            String requestUri = request.getRequestURI();
            String httpMethod = request.getMethod();

            ActivityLog activityLog = ActivityLog.builder()
                    .memberId(memberId)
                    .memberLoginId(memberLoginId)
                    .activityType(activityType)
                    .description(description)
                    .ipAddress(ipAddress)
                    .userAgent(userAgent)
                    .requestUri(requestUri)
                    .httpMethod(httpMethod)
                    .details(details)
                    .build();

            activityLogRepository.save(activityLog);

            log.info("활동 로그 기록 (상세): {} - {} ({})", memberLoginId, description, activityType);
        } catch (Exception e) {
            log.error("활동 로그 기록 실패: {}", e.getMessage(), e);
        }
    }

    /**
     * 특정 회원의 활동 로그 조회
     */
    public Page<ActivityLog> getMemberActivities(Long memberId, Pageable pageable) {
        return activityLogRepository.findByMemberIdOrderByCreatedAtDesc(memberId, pageable);
    }

    /**
     * 활동 유형별 로그 조회
     */
    public Page<ActivityLog> getActivitiesByType(ActivityLog.ActivityType activityType, Pageable pageable) {
        return activityLogRepository.findByActivityTypeOrderByCreatedAtDesc(activityType, pageable);
    }

    /**
     * 날짜 범위별 로그 조회
     */
    public Page<ActivityLog> getActivitiesByDateRange(LocalDateTime startDate, LocalDateTime endDate,
            Pageable pageable) {
        return activityLogRepository.findByDateRange(startDate, endDate, pageable);
    }

    /**
     * 최근 활동 로그 조회
     */
    public Page<ActivityLog> getRecentActivities(Pageable pageable) {
        return activityLogRepository.findRecentActivities(pageable);
    }

    /**
     * 회원별 활동 통계
     */
    public List<Object[]> getMemberActivityStats(LocalDateTime since) {
        return activityLogRepository.getMemberActivityStats(since);
    }

    /**
     * 일별 활동 통계
     */
    public List<Object[]> getDailyActivityStats(LocalDateTime since) {
        return activityLogRepository.getDailyActivityStats(since);
    }

    private HttpServletRequest getCurrentRequest() {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes != null) {
            return attributes.getRequest();
        }
        throw new IllegalStateException("요청 컨텍스트를 찾을 수 없습니다.");
    }

    private String getClientIpAddress(HttpServletRequest request) {
        String[] ipHeaders = {
                "X-Forwarded-For",
                "X-Real-IP",
                "Proxy-Client-IP",
                "WL-Proxy-Client-IP",
                "HTTP_X_FORWARDED_FOR",
                "HTTP_X_FORWARDED",
                "HTTP_X_CLUSTER_CLIENT_IP",
                "HTTP_CLIENT_IP",
                "HTTP_FORWARDED_FOR",
                "HTTP_FORWARDED",
                "HTTP_VIA",
                "REMOTE_ADDR"
        };

        for (String header : ipHeaders) {
            String ip = request.getHeader(header);
            if (ip != null && !ip.isEmpty() && !"unknown".equalsIgnoreCase(ip)) {
                return ip.split(",")[0].trim();
            }
        }

        return request.getRemoteAddr();
    }
}