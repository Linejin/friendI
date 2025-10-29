package com.friendlyI.backend.controller;

import com.friendlyI.backend.dto.ReservationApplicationRequest;
import com.friendlyI.backend.dto.ReservationApplicationResponse;
import com.friendlyI.backend.entity.ReservationStatus;
import com.friendlyI.backend.exception.ReservationApplicationException;
import com.friendlyI.backend.service.ReservationApplicationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/reservation-applications")
@RequiredArgsConstructor
@Tag(name = "예약 신청 관리", description = "예약 신청, 취소, 승인 및 대기열 관리 API")
public class ReservationApplicationController {

    private final ReservationApplicationService applicationService;

    @Operation(summary = "예약 신청 ✋", description = "예약에 신청합니다. 정원이 초과되면 자동으로 대기 상태가 됩니다.")
    @PostMapping
    public ResponseEntity<ReservationApplicationResponse> applyForReservation(
            @Parameter(description = "예약 신청 요청 정보", required = true) @Valid @RequestBody ReservationApplicationRequest request) {
        try {
            ReservationApplicationResponse response = applicationService.applyForReservation(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (ReservationApplicationException e) {
            // 예약 신청 관련 비즈니스 로직 예외
            System.err.println(String.format(
                    "[Application Error] Member %d, Reservation %d: %s",
                    request.getMemberId(),
                    request.getReservationId(),
                    e.getMessage()));
            return ResponseEntity.badRequest().body(null);
        } catch (Exception e) {
            // 기타 예외
            System.err.println(String.format(
                    "[Unexpected Error] Member %d, Reservation %d: %s",
                    request.getMemberId(),
                    request.getReservationId(),
                    e.getMessage()));
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(null);
        }
    }

    /**
     * 회원별 신청 조회
     */
    @GetMapping("/member/{memberId}")
    public ResponseEntity<List<ReservationApplicationResponse>> getApplicationsByMember(
            @PathVariable Long memberId) {
        List<ReservationApplicationResponse> applications = applicationService.getApplicationsByMember(memberId);
        return ResponseEntity.ok(applications);
    }

    /**
     * 예약별 신청 조회
     */
    @GetMapping("/reservation/{reservationId}")
    public ResponseEntity<List<ReservationApplicationResponse>> getApplicationsByReservation(
            @PathVariable Long reservationId) {
        List<ReservationApplicationResponse> applications = applicationService
                .getApplicationsByReservation(reservationId);
        return ResponseEntity.ok(applications);
    }

    /**
     * 예약 신청 취소
     */
    @DeleteMapping("/{applicationId}")
    public ResponseEntity<Void> cancelApplication(@PathVariable Long applicationId) {
        applicationService.cancelApplication(applicationId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 관리자용: 신청 상태 변경
     */
    @PutMapping("/{applicationId}/status")
    public ResponseEntity<ReservationApplicationResponse> updateApplicationStatus(
            @PathVariable Long applicationId,
            @RequestParam ReservationStatus status) {
        ReservationApplicationResponse response = applicationService.updateApplicationStatus(applicationId, status);
        return ResponseEntity.ok(response);
    }

    /**
     * 예외 처리
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleIllegalArgumentException(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(e.getMessage());
    }

    @ExceptionHandler(ReservationApplicationException.class)
    public ResponseEntity<String> handleReservationApplicationException(ReservationApplicationException e) {
        return ResponseEntity.badRequest().body(e.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<String> handleGenericException(Exception e) {
        System.err.println("Unexpected error in ReservationApplicationController: " + e.getMessage());
        e.printStackTrace();
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("서버 내부 오류가 발생했습니다. 관리자에게 문의하세요.");
    }
}
