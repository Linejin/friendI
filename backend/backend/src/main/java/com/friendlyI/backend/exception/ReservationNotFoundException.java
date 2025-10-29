package com.friendlyI.backend.exception;

/**
 * 예약 관련 예외
 */
public class ReservationNotFoundException extends RuntimeException {
    public ReservationNotFoundException(String message) {
        super(message);
    }

    public ReservationNotFoundException(Long reservationId) {
        super("존재하지 않는 예약입니다. ID: " + reservationId);
    }
}