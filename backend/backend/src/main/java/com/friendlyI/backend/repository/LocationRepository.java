package com.friendlyI.backend.repository;

import com.friendlyI.backend.entity.Location;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LocationRepository extends JpaRepository<Location, Long> {

    /**
     * 활성 상태인 장소들만 조회
     */
    List<Location> findByIsActiveTrue();

    /**
     * 장소 이름으로 조회 (대소문자 구분 없음)
     */
    Optional<Location> findByNameIgnoreCase(String name);

    /**
     * 장소 이름과 주소로 조회 (정확히 일치하는 경우)
     */
    Optional<Location> findByNameAndAddress(String name, String address);

    /**
     * 장소 이름과 주소로 조회 (대소문자 구분 없음)
     */
    Optional<Location> findByNameIgnoreCaseAndAddressIgnoreCase(String name, String address);

    /**
     * 장소 이름으로 중복 체크 (대소문자 구분 없음, 현재 장소 제외)
     */
    boolean existsByNameIgnoreCaseAndIdNot(String name, Long id);

    /**
     * 장소 이름으로 중복 체크 (대소문자 구분 없음)
     */
    boolean existsByNameIgnoreCase(String name);

    /**
     * 장소 이름에 특정 키워드가 포함된 활성 장소들 검색
     */
    @Query("SELECT l FROM Location l WHERE l.isActive = true AND " +
            "(LOWER(l.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
            "LOWER(l.address) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Location> findActiveLocationsByKeyword(@Param("keyword") String keyword);

    /**
     * 특정 장소의 현재 활성 예약 수 조회
     */
    @Query("SELECT COUNT(r) FROM Reservation r WHERE r.location.id = :locationId AND " +
            "(r.reservationDate > CURRENT_DATE OR r.reservationDate = CURRENT_DATE)")
    Long countActiveReservationsByLocation(@Param("locationId") Long locationId);

    /**
     * 사용 중인 장소들 조회 (활성 예약이 있는 장소)
     */
    @Query("SELECT DISTINCT l FROM Location l JOIN l.reservations r WHERE " +
            "(r.reservationDate > CURRENT_DATE OR r.reservationDate = CURRENT_DATE)")
    List<Location> findLocationsWithActiveReservations();
}