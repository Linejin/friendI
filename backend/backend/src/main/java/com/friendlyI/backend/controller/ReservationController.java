package com.friendlyI.backend.controller;

import com.friendlyI.backend.dto.ReservationApplicantDto;
import com.friendlyI.backend.dto.ReservationCreateRequest;
import com.friendlyI.backend.dto.ReservationResponse;
import com.friendlyI.backend.service.ReservationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/reservations")
@RequiredArgsConstructor
@Tag(name = "예약 관리", description = "날짜별 예약 생성, 조회, 수정, 삭제 API")
public class ReservationController {

    private final ReservationService reservationService;

    @Operation(summary = "예약 생성 📅", description = "새로운 예약을 생성합니다. 예약 날짜는 현재 날짜보다 미래여야 합니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "예약 생성 성공", content = @Content(schema = @Schema(implementation = ReservationResponse.class))),
            @ApiResponse(responseCode = "400", description = "잘못된 요청 (과거 날짜, 유효성 검증 실패)", content = @Content),
            @ApiResponse(responseCode = "500", description = "서버 오류", content = @Content)
    })
    @PostMapping
    public ResponseEntity<ReservationResponse> createReservation(
            @Parameter(description = "예약 생성 요청 정보", required = true) @Valid @RequestBody ReservationCreateRequest request) {

        // 날짜와 시간이 현재 시간 이후인지 검증
        if (!request.isValidDateTime()) {
            throw new IllegalArgumentException("예약 시간은 현재 시간 이후여야 합니다.");
        }

        ReservationResponse response = reservationService.createReservation(request, request.getCreatorMemberId());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * 모든 예약 조회
     */
    @GetMapping
    public ResponseEntity<List<ReservationResponse>> getAllReservations() {
        List<ReservationResponse> reservations = reservationService.getAllReservations();
        return ResponseEntity.ok(reservations);
    }

    /**
     * 예약 ID로 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<ReservationResponse> getReservationById(@PathVariable Long id) {
        ReservationResponse reservation = reservationService.getReservationById(id);
        return ResponseEntity.ok(reservation);
    }

    @Operation(summary = "날짜별 예약 조회 📅", description = "특정 날짜의 모든 예약을 조회합니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "조회 성공", content = @Content(schema = @Schema(implementation = ReservationResponse.class))),
            @ApiResponse(responseCode = "400", description = "잘못된 날짜 형식", content = @Content)
    })
    @GetMapping("/date/{date}")
    public ResponseEntity<List<ReservationResponse>> getReservationsByDate(
            @Parameter(description = "조회할 날짜 (yyyy-MM-dd 형식)", required = true, example = "2025-12-25") @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        List<ReservationResponse> reservations = reservationService.getReservationsByDate(date);
        return ResponseEntity.ok(reservations);
    }

    /**
     * 예약 가능한 예약 조회
     */
    @GetMapping("/available")
    public ResponseEntity<List<ReservationResponse>> getAvailableReservations() {
        List<ReservationResponse> reservations = reservationService.getAvailableReservations();
        return ResponseEntity.ok(reservations);
    }

    /**
     * 미래 예약 조회
     */
    @GetMapping("/future")
    public ResponseEntity<List<ReservationResponse>> getFutureReservations() {
        List<ReservationResponse> reservations = reservationService.getFutureReservations();
        return ResponseEntity.ok(reservations);
    }

    /**
     * 예약 수정
     */
    @PutMapping("/{id}")
    public ResponseEntity<ReservationResponse> updateReservation(
            @PathVariable Long id,
            @Valid @RequestBody ReservationCreateRequest request) {
        ReservationResponse reservation = reservationService.updateReservation(id, request);
        return ResponseEntity.ok(reservation);
    }

    /**
     * 예약 삭제
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteReservation(@PathVariable Long id) {
        reservationService.deleteReservation(id);
        return ResponseEntity.noContent().build();
    }

    /**
     * 예약 신청자 목록 조회
     */
    @Operation(summary = "예약 신청자 목록 조회 👥", description = "특정 예약의 신청자 목록을 조회합니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "신청자 목록 조회 성공"),
            @ApiResponse(responseCode = "404", description = "존재하지 않는 예약"),
            @ApiResponse(responseCode = "500", description = "서버 오류")
    })
    @GetMapping("/{id}/applicants")
    public ResponseEntity<List<ReservationApplicantDto>> getReservationApplicants(
            @Parameter(description = "예약 ID", required = true) @PathVariable Long id) {
        List<ReservationApplicantDto> applicants = reservationService.getReservationApplicants(id);
        return ResponseEntity.ok(applicants);
    }

    /**
     * 예외 처리
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleIllegalArgumentException(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(e.getMessage());
    }
}
