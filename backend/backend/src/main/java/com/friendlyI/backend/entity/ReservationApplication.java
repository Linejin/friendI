package com.friendlyI.backend.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "reservation_applications", uniqueConstraints = @UniqueConstraint(columnNames = { "member_id",
        "reservation_id" }))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ReservationApplication {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    @NotNull
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reservation_id", nullable = false)
    @NotNull
    private Reservation reservation;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @NotNull
    private ReservationStatus status;

    @Column
    private String note; // 신청시 메모

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime appliedAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @Version
    private Long version; // 낙관적 락을 위한 버전 필드

    @Builder
    public ReservationApplication(Member member, Reservation reservation,
            ReservationStatus status, String note) {
        this.member = member;
        this.reservation = reservation;
        this.status = status;
        this.note = note;
        if (reservation.getCreator() != null) {
            Long creatorMemberId = reservation.getCreator().getId();
            System.out.println("Reservation created by member id = " + creatorMemberId);
        }
    }

    // 비즈니스 메서드
    public void updateStatus(ReservationStatus newStatus) {
        this.status = newStatus;
    }

    public void updateNote(String newNote) {
        this.note = newNote;
    }

    public void cancel() {
        this.status = ReservationStatus.CANCELLED;
    }

    public void confirm() {
        this.status = ReservationStatus.CONFIRMED;
    }

    public void putOnWaitingList() {
        this.status = ReservationStatus.WAITING;
    }

    public boolean isConfirmed() {
        return this.status == ReservationStatus.CONFIRMED;
    }

    public boolean isWaiting() {
        return this.status == ReservationStatus.WAITING;
    }

    public boolean isCancelled() {
        return this.status == ReservationStatus.CANCELLED;
    }
}
