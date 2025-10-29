package com.friendlyI.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class LocationCreateRequest {

    @NotBlank(message = "장소 이름은 필수입니다")
    @Size(min = 2, max = 100, message = "장소 이름은 2-100자 사이여야 합니다")
    private String name;

    @Size(max = 500, message = "주소는 500자를 초과할 수 없습니다")
    private String address;

    @Size(max = 1000, message = "설명은 1000자를 초과할 수 없습니다")
    private String description;

    @NotBlank(message = "네이버 URL은 필수입니다")
    @Size(max = 500, message = "URL은 500자를 초과할 수 없습니다")
    @Pattern(regexp = "^https?://([\\w-]+\\.)?(naver\\.com|naver\\.me)(/.*)?$", flags = {
            Pattern.Flag.CASE_INSENSITIVE }, message = "네이버 URL(naver.com 또는 naver.me)만 허용됩니다")
    private String url;
}