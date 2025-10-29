package com.friendlyI.backend.repository;

import com.friendlyI.backend.entity.Member;
import com.friendlyI.backend.entity.MemberGrade;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MemberRepository extends JpaRepository<Member, Long> {

    /**
     * 로그인 ID로 회원 조회
     */
    Optional<Member> findByLoginId(String loginId);

    /**
     * 로그인 ID 중복 확인
     */
    boolean existsByLoginId(String loginId);

    /**
     * 회원 등급별 조회
     */
    List<Member> findByGrade(MemberGrade grade);

    /**
     * 이름으로 회원 검색 (부분 일치)
     */
    List<Member> findByNameContainingIgnoreCase(String name);

    /**
     * 출생년도 범위로 회원 조회
     */
    @Query("SELECT m FROM Member m WHERE m.birthYear BETWEEN :startYear AND :endYear")
    List<Member> findByBirthYearBetween(@Param("startYear") Integer startYear,
            @Param("endYear") Integer endYear);

    /**
     * 관리자 회원 조회
     */
    @Query("SELECT m FROM Member m WHERE m.grade = 'ROOSTER'")
    List<Member> findAdmins();

    /**
     * 이름 또는 이메일로 회원 검색 (부분 일치)
     */
    @Query("SELECT m FROM Member m WHERE " +
            "LOWER(m.name) LIKE LOWER(CONCAT('%', :keyword, '%')) OR " +
            "(m.email IS NOT NULL AND LOWER(m.email) LIKE LOWER(CONCAT('%', :keyword, '%'))) OR " +
            "LOWER(m.loginId) LIKE LOWER(CONCAT('%', :keyword, '%'))")
    List<Member> findByKeyword(@Param("keyword") String keyword);

    /**
     * 등급별 회원 수 조회
     */
    @Query("SELECT m.grade, COUNT(m) FROM Member m GROUP BY m.grade")
    List<Object[]> countMembersByGrade();
}
