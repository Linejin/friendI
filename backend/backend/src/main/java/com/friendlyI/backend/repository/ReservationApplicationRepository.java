package com.friendlyI.backend.repository;

import com.friendlyI.backend.entity.Member;
import com.friendlyI.backend.entity.Reservation;
import com.friendlyI.backend.entity.ReservationApplication;
import com.friendlyI.backend.entity.ReservationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface ReservationApplicationRepository extends JpaRepository<ReservationApplication, Long> {

       /**
        * 회원별 예약 신청 조회
        */
       List<ReservationApplication> findByMember(Member member);

       /**
        * 예약별 신청 조회
        */
       List<ReservationApplication> findByReservation(Reservation reservation);

       /**
        * 예약별 신청을 신청 순서대로 조회
        */
       List<ReservationApplication> findByReservationOrderByAppliedAtAsc(Reservation reservation);

       /**
        * 회원과 예약으로 신청 조회 (중복 신청 체크용)
        */
       Optional<ReservationApplication> findByMemberAndReservation(Member member, Reservation reservation);

       /**
        * 상태별 신청 조회
        */
       List<ReservationApplication> findByStatus(ReservationStatus status);

       /**
        * 예약별 확정된 신청 조회
        */
       List<ReservationApplication> findByReservationAndStatus(Reservation reservation, ReservationStatus status);

       /**
        * 회원의 확정된 예약 조회
        */
       @Query("SELECT ra FROM ReservationApplication ra WHERE ra.member = :member AND ra.status = 'CONFIRMED'")
       List<ReservationApplication> findConfirmedReservationsByMember(@Param("member") Member member);

       /**
        * 특정 날짜의 회원 예약 확인
        */
       @Query("SELECT ra FROM ReservationApplication ra " +
                     "WHERE ra.member = :member AND ra.reservation.reservationDate = :date")
       List<ReservationApplication> findByMemberAndDate(@Param("member") Member member,
                     @Param("date") LocalDate date);

       /**
        * 대기중인 신청을 신청 순서대로 조회
        */
       @Query("SELECT ra FROM ReservationApplication ra " +
                     "WHERE ra.reservation = :reservation AND ra.status = 'WAITING' " +
                     "ORDER BY ra.appliedAt ASC")
       List<ReservationApplication> findWaitingApplicationsInOrder(@Param("reservation") Reservation reservation);

       /**
        * 예약별 확정된 신청 수 조회
        */
       @Query("SELECT COUNT(ra) FROM ReservationApplication ra " +
                     "WHERE ra.reservation = :reservation AND ra.status = 'CONFIRMED'")
       Long countConfirmedByReservation(@Param("reservation") Reservation reservation);

       /**
        * 예약별 대기 신청 수 조회
        */
       @Query("SELECT COUNT(ra) FROM ReservationApplication ra " +
                     "WHERE ra.reservation = :reservation AND ra.status = 'WAITING'")
       Long countWaitingByReservation(@Param("reservation") Reservation reservation);

       /**
        * 여러 예약의 신청 통계를 한 번에 조회 (N+1 방지)
        */
       @Query("SELECT ra.reservation.id, ra.status, COUNT(ra) " +
                     "FROM ReservationApplication ra " +
                     "WHERE ra.reservation.id IN :reservationIds " +
                     "GROUP BY ra.reservation.id, ra.status")
       List<Object[]> getApplicationStatsByReservationIds(@Param("reservationIds") List<Long> reservationIds);

       /**
        * 회원이 특정 예약에 이미 신청했는지 확인
        */
       boolean existsByMemberAndReservation(Member member, Reservation reservation);

       /**
        * 회원이 특정 예약에 활성 상태로 신청했는지 확인 (취소된 신청 제외)
        */
       @Query("SELECT COUNT(ra) > 0 FROM ReservationApplication ra " +
                     "WHERE ra.member = :member AND ra.reservation = :reservation AND ra.status != 'CANCELLED'")
       boolean existsActiveApplicationByMemberAndReservation(@Param("member") Member member,
                     @Param("reservation") Reservation reservation);

       /**
        * 날짜 범위로 회원과 예약 정보를 포함한 신청 조회
        */
       @Query("SELECT ra FROM ReservationApplication ra " +
                     "JOIN FETCH ra.member " +
                     "JOIN FETCH ra.reservation r " +
                     "WHERE r.reservationDate BETWEEN :startDate AND :endDate")
       List<ReservationApplication> findApplicationsWithMemberAndReservationByDateRange(
                     @Param("startDate") LocalDate startDate,
                     @Param("endDate") LocalDate endDate);

       /**
        * 회원별 신청 수 조회
        */
       long countByMember(Member member);

       /**
        * 회원별 상태별 신청 수 조회
        */
       long countByMemberAndStatus(Member member, ReservationStatus status);

       /**
        * 회원 ID와 예약 날짜로 신청 조회
        */
       @Query("SELECT ra FROM ReservationApplication ra " +
                     "WHERE ra.member.id = :memberId AND ra.reservation.reservationDate = :date")
       List<ReservationApplication> findByMemberIdAndReservationDate(
                     @Param("memberId") Long memberId,
                     @Param("date") LocalDate date);

       /**
        * 날짜 범위별 회원 신청 통계
        */
       @Query("SELECT ra.member.id, ra.member.name, COUNT(ra) " +
                     "FROM ReservationApplication ra " +
                     "WHERE ra.reservation.reservationDate BETWEEN :startDate AND :endDate " +
                     "GROUP BY ra.member.id, ra.member.name")
       List<Object[]> getMemberApplicationStats(
                     @Param("startDate") LocalDate startDate,
                     @Param("endDate") LocalDate endDate);
}
