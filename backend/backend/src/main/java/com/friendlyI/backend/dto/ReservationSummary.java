package com.friendlyI.backend.dto;

import lombok.Data;
import java.time.LocalDate;

/**
 * 간단한 예약 정보 (순환 참조 방지용)
 */
@Data
public class ReservationSummary {
    private Long id;
    private String title;
    private LocalDate reservationDate;
    private LocationSummary location; // 장소 정보
    private Integer maxCapacity;
    private Integer availableSlots;
}