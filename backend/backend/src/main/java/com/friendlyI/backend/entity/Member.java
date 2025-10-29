package com.friendlyI.backend.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "members")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    @NotBlank
    private String loginId;

    @Column(nullable = false)
    @NotBlank
    private String password;

    @Column(nullable = false)
    @NotBlank
    private String name;

    @Column(nullable = true)
    private String email;

    @Column(nullable = true)
    private String phoneNumber;

    @Column(nullable = false)
    @NotNull
    private Integer birthYear;

    @PrePersist
    @PreUpdate
    private void validateMember() {
        if (birthYear != null) {
            int currentYear = java.time.Year.now().getValue();
            if (birthYear > currentYear) {
                throw new IllegalArgumentException("출생년도는 현재 연도보다 클 수 없습니다.");
            }
            if (birthYear < 1900) {
                throw new IllegalArgumentException("출생년도는 1900년 이후여야 합니다.");
            }
        }
    }

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @NotNull
    private MemberGrade grade;

    @OneToMany(mappedBy = "member", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    private List<ReservationApplication> reservationApplications = new ArrayList<>();

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @Builder
    public Member(String loginId, String password, String name, String email, String phoneNumber, Integer birthYear,
            MemberGrade grade) {
        this.loginId = loginId;
        this.password = password;
        this.name = name;
        this.email = email;
        this.phoneNumber = phoneNumber;
        this.birthYear = birthYear;
        this.grade = grade != null ? grade : MemberGrade.EGG; // 기본값은 알 등급
    }

    // 비즈니스 메서드
    public void updateGrade(MemberGrade newGrade) {
        this.grade = newGrade;
    }

    public void updatePassword(String newPassword) {
        this.password = newPassword;
    }

    public void updateInfo(String name, String email, String phoneNumber) {
        this.name = name;
        this.email = email;
        this.phoneNumber = phoneNumber;
    }

    public void updateInfo(String name, String email, String phoneNumber, MemberGrade grade) {
        this.name = name;
        this.email = email;
        this.phoneNumber = phoneNumber;
        if (grade != null) {
            this.grade = grade;
        }
    }

    public boolean isAdmin() {
        return this.grade.isAdmin();
    }

    public int getAge() {
        return java.time.Year.now().getValue() - this.birthYear;
    }
}
