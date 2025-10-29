package com.friendlyI.backend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class ReservationApplicationRequest {
    
    @NotNull(message = "회원 ID는 필수입니다")
    private Long memberId;
    
    @NotNull(message = "예약 ID는 필수입니다")
    private Long reservationId;
    
    private String note; // 신청시 메모
}
