package com.friendlyI.backend.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class ReservationCreateRequest {

    @NotNull(message = "생성자 회원 ID는 필수입니다")
    private Long creatorMemberId;

    @NotBlank(message = "제목은 필수입니다")
    @Size(min = 2, max = 100, message = "제목은 2-100자 사이여야 합니다")
    @Pattern(regexp = "^[가-힣a-zA-Z0-9\\s\\-_().,!?]+$", message = "제목에는 특수문자를 사용할 수 없습니다")
    private String title;

    @Size(max = 1000, message = "설명은 1000자를 초과할 수 없습니다")
    private String description;

    @NotEmpty(message = "최소 1개의 장소는 필요합니다")
    @Valid
    private List<LocationInfo> locations;

    @NotNull(message = "최대 인원은 필수입니다")
    @Min(value = 1, message = "최대 인원은 1명 이상이어야 합니다")
    @Max(value = 1000, message = "최대 인원은 1000명을 초과할 수 없습니다")
    private Integer maxCapacity;

    @NotNull(message = "예약 날짜는 필수입니다")
    @FutureOrPresent(message = "예약 날짜는 현재 날짜 이후여야 합니다 (당일 예약 가능)")
    private LocalDate reservationDate;

    @NotNull(message = "예약 시간은 필수입니다")
    private LocalTime reservationTime;

    /**
     * 예약 날짜와 시간이 현재 시간 이후인지 검증
     */
    public boolean isValidDateTime() {
        if (reservationDate == null || reservationTime == null) {
            return false;
        }
        LocalDateTime reservationDateTime = LocalDateTime.of(reservationDate, reservationTime);
        return reservationDateTime.isAfter(LocalDateTime.now());
    }

    /**
     * 예약 날짜와 시간을 LocalDateTime으로 반환
     */
    public LocalDateTime getReservationDateTime() {
        if (reservationDate == null || reservationTime == null) {
            return null;
        }
        return LocalDateTime.of(reservationDate, reservationTime);
    }

    @Data
    public static class LocationInfo {
        @NotBlank(message = "장소명은 필수입니다")
        @Size(min = 2, max = 100, message = "장소명은 2-100자 사이여야 합니다")
        private String name;

        @Size(max = 500, message = "주소는 500자를 초과할 수 없습니다")
        private String address;

        @NotBlank(message = "네이버 URL은 필수입니다")
        @Size(max = 500, message = "URL은 500자를 초과할 수 없습니다")
        @Pattern(regexp = "^https?://([\\w-]+\\.)?(naver\\.com|naver\\.me)(/.*)?$", flags = {
                Pattern.Flag.CASE_INSENSITIVE }, message = "네이버 URL(naver.com 또는 naver.me)만 허용됩니다")
        private String url;
    }
}
