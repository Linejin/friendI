package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.Location;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class LocationResponse {
    private Long id;
    private String name;
    private String address;
    private String description;
    private String url;
    private Boolean isActive;
    private Long activeReservationCount; // 현재 활성 예약 수
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static LocationResponse from(Location location) {
        return LocationResponse.builder()
                .id(location.getId())
                .name(location.getName())
                .address(location.getAddress())
                .description(location.getDescription())
                .url(location.getUrl())
                .isActive(location.getIsActive())
                .createdAt(location.getCreatedAt())
                .updatedAt(location.getUpdatedAt())
                .build();
    }

    public static LocationResponse from(Location location, Long activeReservationCount) {
        LocationResponse response = from(location);
        response.setActiveReservationCount(activeReservationCount);
        return response;
    }
}