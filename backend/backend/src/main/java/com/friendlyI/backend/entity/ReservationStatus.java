package com.friendlyI.backend.entity;

/**
 * 예약 신청 상태를 나타내는 Enum
 */
public enum ReservationStatus {
    CONFIRMED("확정"),
    WAITING("대기"),
    CANCELLED("취소");
    
    private final String description;
    
    ReservationStatus(String description) {
        this.description = description;
    }
    
    public String getDescription() {
        return description;
    }
}
