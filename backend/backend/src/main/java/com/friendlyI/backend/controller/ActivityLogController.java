package com.friendlyI.backend.controller;

import com.friendlyI.backend.config.security.RequireAuth;
import com.friendlyI.backend.dto.ActivityLogResponse;
import com.friendlyI.backend.dto.common.PageResponse;
import com.friendlyI.backend.entity.ActivityLog;
import com.friendlyI.backend.service.ActivityLogService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

// @RestController
// @RequestMapping("/api/activity-logs")
@RequiredArgsConstructor
@Tag(name = "활동 로그 관리", description = "사용자 활동 로그 조회 API (관리자 전용)")
public class ActivityLogController {

    private final ActivityLogService activityLogService;

    @RequireAuth(adminOnly = true)
    @Operation(summary = "최근 활동 로그 조회 📊", description = "최근 사용자 활동 로그를 페이징으로 조회합니다.")
    @GetMapping("/recent")
    public ResponseEntity<PageResponse<ActivityLogResponse>> getRecentActivities(
            @Parameter(description = "페이지 번호 (0부터 시작)") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "페이지 크기") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "정렬 기준") @RequestParam(defaultValue = "createdAt") String sortBy,
            @Parameter(description = "정렬 방향") @RequestParam(defaultValue = "desc") String sortDir) {

        Sort sort = Sort.by(Sort.Direction.fromString(sortDir), sortBy);
        Pageable pageable = PageRequest.of(page, size, sort);

        Page<ActivityLog> activityPage = activityLogService.getRecentActivities(pageable);
        Page<ActivityLogResponse> responsePage = activityPage.map(ActivityLogResponse::from);

        return ResponseEntity.ok(PageResponse.of(responsePage));
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "회원별 활동 로그 조회 👤", description = "특정 회원의 활동 로그를 조회합니다.")
    @GetMapping("/member/{memberId}")
    public ResponseEntity<PageResponse<ActivityLogResponse>> getMemberActivities(
            @Parameter(description = "회원 ID") @PathVariable Long memberId,
            @Parameter(description = "페이지 번호") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "페이지 크기") @RequestParam(defaultValue = "20") int size) {

        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<ActivityLog> activityPage = activityLogService.getMemberActivities(memberId, pageable);
        Page<ActivityLogResponse> responsePage = activityPage.map(ActivityLogResponse::from);

        return ResponseEntity.ok(PageResponse.of(responsePage));
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "활동 유형별 로그 조회 🔍", description = "특정 활동 유형의 로그를 조회합니다.")
    @GetMapping("/type/{activityType}")
    public ResponseEntity<PageResponse<ActivityLogResponse>> getActivitiesByType(
            @Parameter(description = "활동 유형 (LOGIN, LOGOUT, MEMBER_CREATE, MEMBER_UPDATE, MEMBER_DELETE, GRADE_UPGRADE, RESERVATION_CREATE, RESERVATION_UPDATE, RESERVATION_DELETE, RESERVATION_APPLY, RESERVATION_CANCEL, SEARCH, VIEW, ERROR)") @PathVariable String activityType,
            @Parameter(description = "페이지 번호") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "페이지 크기") @RequestParam(defaultValue = "20") int size) {

        try {
            ActivityLog.ActivityType type = ActivityLog.ActivityType.valueOf(activityType.toUpperCase());
            Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
            Page<ActivityLog> activityPage = activityLogService.getActivitiesByType(type, pageable);
            Page<ActivityLogResponse> responsePage = activityPage.map(ActivityLogResponse::from);

            return ResponseEntity.ok(PageResponse.of(responsePage));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("유효하지 않은 활동 유형입니다: " + activityType);
        }
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "날짜 범위별 활동 로그 조회 📅", description = "특정 날짜 범위의 활동 로그를 조회합니다.")
    @GetMapping("/date-range")
    public ResponseEntity<PageResponse<ActivityLogResponse>> getActivitiesByDateRange(
            @Parameter(description = "시작 날짜시간 (예: 2023-12-01T00:00:00)") @RequestParam String startDate,
            @Parameter(description = "종료 날짜시간 (예: 2023-12-31T23:59:59)") @RequestParam String endDate,
            @Parameter(description = "페이지 번호") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "페이지 크기") @RequestParam(defaultValue = "20") int size) {

        try {
            LocalDateTime start = LocalDateTime.parse(startDate);
            LocalDateTime end = LocalDateTime.parse(endDate);

            Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
            Page<ActivityLog> activityPage = activityLogService.getActivitiesByDateRange(start, end, pageable);
            Page<ActivityLogResponse> responsePage = activityPage.map(ActivityLogResponse::from);

            return ResponseEntity.ok(PageResponse.of(responsePage));
        } catch (Exception e) {
            throw new IllegalArgumentException("날짜 형식이 올바르지 않습니다. ISO 형식을 사용하세요 (예: 2023-12-01T00:00:00)");
        }
    }
}