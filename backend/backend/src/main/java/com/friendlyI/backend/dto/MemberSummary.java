package com.friendlyI.backend.dto;

import lombok.Data;

/**
 * 간단한 회원 정보 (순환 참조 방지용)
 */
@Data
public class MemberSummary {
    private Long id;
    private String name;
    private String gradeEmoji;
    private String gradeDescription;
}