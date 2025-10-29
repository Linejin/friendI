package com.friendlyI.backend.dto;

import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Data
public class ReservationResponse {

    private Long id;
    private String title;
    private String description;
    private LocationSummary location; // 장소 정보
    private Integer maxCapacity;
    private Long creatorId;
    private String creatorName;
    private LocalDate reservationDate;
    private LocalTime reservationTime;
    private Integer confirmedCount;
    private Integer waitingCount;
    private Integer availableSlots;
    private boolean isFullyBooked;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
