package com.friendlyI.backend.config;

import com.github.benmanes.caffeine.cache.Caffeine;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import java.util.concurrent.TimeUnit;

/**
 * 개선된 캐시 설정 - Caffeine 사용
 */
@Slf4j
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    @Primary
    public CacheManager cacheManager() {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager();

        // 기본 캐시 설정
        cacheManager.setCaffeine(Caffeine.newBuilder()
                .maximumSize(1000)
                .expireAfterWrite(30, TimeUnit.MINUTES)
                .expireAfterAccess(10, TimeUnit.MINUTES)
                .recordStats()
                .removalListener((key, value, cause) -> {
                    log.debug("캐시 제거: key={}, cause={}", key, cause);
                }));

        // 캐시 이름들 설정
        cacheManager.setCacheNames(java.util.Arrays.asList(
                "members", // 회원 정보 (30분)
                "memberStats", // 회원 통계 (1시간)
                "reservations", // 예약 정보 (15분)
                "reservationStats", // 예약 통계 (1시간)
                "activityLogs" // 활동 로그 (5분)
        ));

        return cacheManager;
    }

    @Bean("longTermCacheManager")
    public CacheManager longTermCacheManager() {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager();

        // 장기 캐시 설정 (통계, 설정값 등)
        cacheManager.setCaffeine(Caffeine.newBuilder()
                .maximumSize(500)
                .expireAfterWrite(2, TimeUnit.HOURS)
                .recordStats());

        cacheManager.setCacheNames(java.util.Arrays.asList(
                "dailyStats",
                "monthlyStats",
                "systemConfig"));

        return cacheManager;
    }
}