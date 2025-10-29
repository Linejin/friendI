package com.friendlyI.backend.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
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
@Table(name = "locations")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Location {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    @NotBlank
    @Size(min = 2, max = 100, message = "장소 이름은 2-100자 사이여야 합니다")
    private String name;

    @Column(nullable = true)
    @Size(max = 500, message = "주소는 500자를 초과할 수 없습니다")
    private String address;

    @Column(length = 1000)
    private String description; // 장소 설명 (선택사항)

    @Column(length = 500, nullable = false)
    @NotBlank
    private String url; // 네이버 장소 URL (필수)

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true; // 활성 상태 (비활성화된 장소는 새 예약에 사용 불가)

    @OneToMany(mappedBy = "location", fetch = FetchType.LAZY)
    private List<Reservation> reservations = new ArrayList<>();

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @Builder
    public Location(String name, String address, String description, String url, Boolean isActive) {
        this.name = name;
        this.address = address;
        this.description = description;
        this.url = url;
        this.isActive = isActive != null ? isActive : true;
    }

    // 비즈니스 메서드
    public void updateLocation(String name, String address, String description, String url) {
        this.name = name;
        this.address = address;
        this.description = description;
        this.url = url;
    }

    public void activate() {
        this.isActive = true;
    }

    public void deactivate() {
        this.isActive = false;
    }

    public boolean isActive() {
        return this.isActive;
    }

    // 해당 장소에서 활성 예약 수 계산 (Repository에서 계산하는 것을 권장)
    public long getActiveReservationCount() {
        if (reservations == null) {
            return 0;
        }
        return reservations.stream()
                .filter(reservation -> reservation.getReservationDate().isAfter(java.time.LocalDate.now())
                        || reservation.getReservationDate().equals(java.time.LocalDate.now()))
                .count();
    }
}