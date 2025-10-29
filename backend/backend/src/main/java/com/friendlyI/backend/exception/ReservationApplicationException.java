package com.friendlyI.backend.exception;

/**
 * 예약 신청 관련 예외
 */
public class ReservationApplicationException extends RuntimeException {
    public ReservationApplicationException(String message) {
        super(message);
    }
}

/**
 * 중복 신청 예외
 */
class DuplicateApplicationException extends ReservationApplicationException {
    public DuplicateApplicationException(Long memberId, Long reservationId) {
        super(String.format("회원 ID %d가 예약 ID %d에 이미 신청했습니다.", memberId, reservationId));
    }
}

/**
 * 신청 불가능 예외
 */
class ApplicationNotAllowedException extends ReservationApplicationException {
    public ApplicationNotAllowedException(String reason) {
        super("신청할 수 없습니다: " + reason);
    }
}