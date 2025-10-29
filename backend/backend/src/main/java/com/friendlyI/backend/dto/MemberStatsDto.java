package com.friendlyI.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MemberStatsDto {
    private Long totalParticipations; // 총 참가 신청 횟수
    private Long completedReservations; // 완료한 예약 수
    private Long canceledReservations; // 취소한 예약 수
    private Long waitingReservations; // 현재 대기 중인 예약 수
    private LocalDate joinDate; // 가입일
    private Double participationRate; // 참가율 (완료/총신청 * 100)
}