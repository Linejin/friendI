package com.friendlyI.backend.repository;

import com.friendlyI.backend.entity.ActivityLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface ActivityLogRepository extends JpaRepository<ActivityLog, Long> {

    /**
     * 특정 회원의 활동 로그 조회
     */
    Page<ActivityLog> findByMemberIdOrderByCreatedAtDesc(Long memberId, Pageable pageable);

    /**
     * 활동 유형별 로그 조회
     */
    Page<ActivityLog> findByActivityTypeOrderByCreatedAtDesc(
            ActivityLog.ActivityType activityType, Pageable pageable);

    /**
     * 날짜 범위별 로그 조회
     */
    @Query("SELECT a FROM ActivityLog a WHERE a.createdAt BETWEEN :startDate AND :endDate ORDER BY a.createdAt DESC")
    Page<ActivityLog> findByDateRange(@Param("startDate") LocalDateTime startDate,
            @Param("endDate") LocalDateTime endDate,
            Pageable pageable);

    /**
     * 특정 IP 주소의 로그 조회
     */
    List<ActivityLog> findByIpAddressOrderByCreatedAtDesc(String ipAddress);

    /**
     * 최근 활동 로그 조회
     */
    @Query("SELECT a FROM ActivityLog a ORDER BY a.createdAt DESC")
    Page<ActivityLog> findRecentActivities(Pageable pageable);

    /**
     * 회원별 활동 통계
     */
    @Query("SELECT a.memberLoginId, a.activityType, COUNT(a) " +
            "FROM ActivityLog a " +
            "WHERE a.createdAt >= :since " +
            "GROUP BY a.memberLoginId, a.activityType " +
            "ORDER BY COUNT(a) DESC")
    List<Object[]> getMemberActivityStats(@Param("since") LocalDateTime since);

    /**
     * 일별 활동 통계
     */
    @Query("SELECT DATE(a.createdAt), COUNT(a) " +
            "FROM ActivityLog a " +
            "WHERE a.createdAt >= :since " +
            "GROUP BY DATE(a.createdAt) " +
            "ORDER BY DATE(a.createdAt)")
    List<Object[]> getDailyActivityStats(@Param("since") LocalDateTime since);
}