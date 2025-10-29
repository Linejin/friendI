package com.friendlyI.backend.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class LocationSummary {
    private Long id;
    private String name;
    private String address;
    private String url;
    private Boolean isActive;
}