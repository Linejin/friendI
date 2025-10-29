package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.MemberGrade;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "회원 생성 요청")
public class MemberCreateRequest {

    @Schema(description = "로그인 ID (4-20자의 영문, 숫자, 언더스코어)", example = "user123", required = true)
    @NotBlank(message = "로그인 ID는 필수입니다")
    @Pattern(regexp = "^[a-zA-Z0-9_]{4,20}$", message = "로그인 ID는 4-20자의 영문, 숫자, 언더스코어만 사용 가능합니다")
    private String loginId;

    @Schema(description = "비밀번호 (8-20자, 대소문자+숫자+특수문자)", example = "Password123!", required = true)
    @NotBlank(message = "비밀번호는 필수입니다")
    @Pattern(regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,20}$", message = "비밀번호는 8-20자이며 대소문자, 숫자, 특수문자를 각각 하나 이상 포함해야 합니다")
    private String password;

    @Schema(description = "이름 (2-50자의 한글, 영문)", example = "홍길동", required = true)
    @NotBlank(message = "이름은 필수입니다")
    @Pattern(regexp = "^[가-힣a-zA-Z\\s]{2,50}$", message = "이름은 2-50자의 한글, 영문만 사용 가능합니다")
    private String name;

    @Schema(description = "출생년도 (1900-2024)", example = "1990", required = true)
    @NotNull(message = "출생년도는 필수입니다")
    @Min(value = 1900, message = "출생년도는 1900년 이후여야 합니다")
    @Max(value = 2024, message = "출생년도는 현재 연도를 초과할 수 없습니다")
    private Integer birthYear;

    @Schema(description = "회원 등급 (미지정시 EGG로 자동 설정)", example = "EGG")
    private MemberGrade grade;
}
