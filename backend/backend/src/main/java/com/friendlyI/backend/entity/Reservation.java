package com.friendlyI.backend.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "reservations")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Reservation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "creator_member_id", nullable = false)
    private Member creator;

    @Column(nullable = false)
    @NotBlank
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "location_id", nullable = false)
    @NotNull
    private Location location;

    @Column(nullable = false)
    @NotNull
    @Positive
    private Integer maxCapacity;

    @Column(nullable = false)
    @NotNull
    private LocalDate reservationDate;

    @Column(nullable = false)
    @NotNull
    private LocalTime reservationTime;

    @PrePersist
    @PreUpdate
    private void validateReservation() {
        if (reservationDate != null && reservationDate.isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("예약 날짜는 과거일 수 없습니다. (당일 예약은 가능합니다)");
        }
        if (maxCapacity != null && maxCapacity <= 0) {
            throw new IllegalArgumentException("최대 인원은 1명 이상이어야 합니다.");
        }
    }

    @OneToMany(mappedBy = "reservation", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    private List<ReservationApplication> applications = new ArrayList<>();

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @Version
    private Long version; // 낙관적 락을 위한 버전 필드

    @Builder
    public Reservation(String title, String description, Location location,
            Integer maxCapacity, LocalDate reservationDate, LocalTime reservationTime, Member creator) {
        this.title = title;
        this.description = description;
        this.location = location;
        this.maxCapacity = maxCapacity;
        this.reservationDate = reservationDate;
        this.reservationTime = reservationTime;
        this.creator = creator; // ✅ creator 필드 할당 추가
    }

    // 비즈니스 메서드 (N+1 쿼리 방지를 위해 Repository에서 계산된 값 사용 권장)
    public int getConfirmedCount() {
        if (applications == null || applications.isEmpty()) {
            return 0;
        }
        return (int) applications.stream()
                .filter(app -> app.getStatus() == ReservationStatus.CONFIRMED)
                .count();
    }

    public int getWaitingCount() {
        if (applications == null || applications.isEmpty()) {
            return 0;
        }
        return (int) applications.stream()
                .filter(app -> app.getStatus() == ReservationStatus.WAITING)
                .count();
    }

    public boolean isFullyBooked() {
        return getConfirmedCount() >= maxCapacity;
    }

    public int getAvailableSlots() {
        return Math.max(0, maxCapacity - getConfirmedCount());
    }

    // Repository를 통한 효율적인 계산을 위한 메서드들
    public boolean isFullyBooked(int confirmedCount) {
        return confirmedCount >= maxCapacity;
    }

    public int getAvailableSlots(int confirmedCount) {
        return Math.max(0, maxCapacity - confirmedCount);
    }

    public void updateReservation(String title, String description, Location location,
            Integer maxCapacity, LocalDate reservationDate, LocalTime reservationTime) {
        this.title = title;
        this.description = description;
        this.location = location;
        this.maxCapacity = maxCapacity;
        this.reservationDate = reservationDate;
        this.reservationTime = reservationTime;
    }
}
