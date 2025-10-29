package com.friendlyI.backend.repository;

import com.friendlyI.backend.entity.Reservation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ReservationRepository extends JpaRepository<Reservation, Long> {
    
    /**
     * 날짜별 예약 조회
     */
    List<Reservation> findByReservationDate(LocalDate date);
    
    /**
     * 날짜 범위별 예약 조회
     */
    List<Reservation> findByReservationDateBetween(LocalDate startDate, LocalDate endDate);
    
    /**
     * 예약 날짜 기준 오름차순 정렬
     */
    List<Reservation> findAllByOrderByReservationDateAsc();
    
    /**
     * 특정 날짜 이후의 예약 조회 (미래 예약)
     */
    List<Reservation> findByReservationDateAfter(LocalDate date);
    
    /**
     * 제목으로 예약 검색 (부분 일치)
     */
    List<Reservation> findByTitleContainingIgnoreCase(String title);
    
    /**
     * 예약 가능한 슬롯이 있는 예약 조회
     */
    @Query("SELECT r FROM Reservation r WHERE " +
           "(SELECT COUNT(ra) FROM ReservationApplication ra " +
           "WHERE ra.reservation.id = r.id AND ra.status = 'CONFIRMED') < r.maxCapacity")
    List<Reservation> findAvailableReservations();
    
    /**
     * 특정 날짜의 예약 가능한 예약 조회
     */
    @Query("SELECT r FROM Reservation r WHERE r.reservationDate = :date AND " +
           "(SELECT COUNT(ra) FROM ReservationApplication ra " +
           "WHERE ra.reservation.id = r.id AND ra.status = 'CONFIRMED') < r.maxCapacity")
    List<Reservation> findAvailableReservationsByDate(@Param("date") LocalDate date);
}
