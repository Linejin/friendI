package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.ReservationStatus;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class ReservationApplicationResponse {

    private Long id;
    private MemberSummary memberSummary; // 순환 참조 방지를 위해 변경
    private ReservationSummary reservationSummary; // 순환 참조 방지를 위해 변경
    private ReservationStatus status;
    private String statusDescription;
    private String note;
    private LocalDateTime appliedAt;
    private LocalDateTime updatedAt;
}
