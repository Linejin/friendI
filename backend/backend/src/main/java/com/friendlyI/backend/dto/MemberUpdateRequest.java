package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.MemberGrade;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Schema(description = "회원 정보 수정 요청")
public class MemberUpdateRequest {

    @NotBlank(message = "이름은 필수입니다")
    @Schema(description = "회원 이름", example = "김철수")
    private String name;

    @NotBlank(message = "이메일은 필수입니다")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    @Schema(description = "이메일 주소", example = "kimcs@example.com")
    private String email;

    @NotBlank(message = "전화번호는 필수입니다")
    @Schema(description = "전화번호", example = "010-1234-5678")
    private String phoneNumber;

    @Schema(description = "회원 등급 (관리자만 수정 가능)", example = "CHICK")
    private MemberGrade grade;
}