package com.friendlyI.backend.dto;

import com.friendlyI.backend.entity.MemberGrade;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class MemberResponse {

    private Long id;
    private String loginId;
    private String name;
    private String email;
    private String phoneNumber;
    private Integer birthYear;
    private MemberGrade grade;
    private String gradeEmoji;
    private String gradeDescription;
    private Integer age;
    private boolean isAdmin;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
