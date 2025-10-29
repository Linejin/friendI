package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.ReservationStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReservationApplicantDto {
    private Long applicationId; // 신청 ID (취소용)
    private Long memberId;
    private String memberName;
    private String memberLoginId;
    private ReservationStatus status; // CONFIRMED, WAITING, CANCELLED
    private LocalDateTime appliedAt;
    private boolean isCreator;
}