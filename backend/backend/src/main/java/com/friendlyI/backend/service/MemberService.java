package com.friendlyI.backend.service;

import com.friendlyI.backend.dto.MemberCreateRequest;
import com.friendlyI.backend.dto.MemberResponse;
import com.friendlyI.backend.dto.MemberStatsDto;
import com.friendlyI.backend.dto.MemberUpdateRequest;
import com.friendlyI.backend.entity.ActivityLog;
import com.friendlyI.backend.entity.Member;
import com.friendlyI.backend.entity.MemberGrade;
import com.friendlyI.backend.entity.ReservationStatus;
import com.friendlyI.backend.exception.MemberNotFoundException;
import com.friendlyI.backend.repository.MemberRepository;
import com.friendlyI.backend.repository.ReservationApplicationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberService {

    private final MemberRepository memberRepository;
    private final PasswordEncoder passwordEncoder;
    private final ActivityLogService activityLogService;
    private final ReservationApplicationRepository applicationRepository;

    /**
     * 회원 생성
     */
    @Transactional
    public MemberResponse createMember(MemberCreateRequest request) {
        if (memberRepository.existsByLoginId(request.getLoginId())) {
            throw new IllegalArgumentException("이미 존재하는 로그인 ID입니다.");
        }

        Member member = Member.builder()
                .loginId(request.getLoginId())
                .password(passwordEncoder.encode(request.getPassword())) // 비밀번호 암호화
                .name(request.getName())
                .birthYear(request.getBirthYear())
                .grade(request.getGrade() != null ? request.getGrade() : MemberGrade.EGG)
                .build();

        Member savedMember = memberRepository.save(member);

        // 활동 로그 기록
        activityLogService.logActivity(
                savedMember.getId(),
                savedMember.getLoginId(),
                ActivityLog.ActivityType.MEMBER_CREATE,
                String.format("새 회원 가입: %s (%s)", savedMember.getName(), savedMember.getLoginId()));

        return convertToResponse(savedMember);
    }

    /**
     * 회원 ID로 조회 (캐싱 적용)
     */
    @Cacheable(value = "members", key = "#id")
    public MemberResponse getMemberById(Long id) {
        Member member = memberRepository.findById(id)
                .orElseThrow(() -> new MemberNotFoundException(id));
        return convertToResponse(member);
    }

    /**
     * 로그인 ID로 조회
     */
    public MemberResponse getMemberByLoginId(String loginId) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 회원입니다."));
        return convertToResponse(member);
    }

    /**
     * 모든 회원 조회
     */
    public List<MemberResponse> getAllMembers() {
        return memberRepository.findAll().stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * 모든 회원 조회 (페이징)
     */
    @Cacheable(value = "members", key = "'paged_' + #pageable.pageNumber + '_' + #pageable.pageSize + '_' + #pageable.sort")
    public Page<MemberResponse> getAllMembersPaged(Pageable pageable) {
        Page<Member> memberPage = memberRepository.findAll(pageable);
        return memberPage.map(this::convertToResponse);
    }

    /**
     * 회원 등급 업그레이드 (캐시 갱신)
     */
    @Transactional
    @CacheEvict(value = "members", key = "#memberId")
    public MemberResponse upgradeGrade(Long memberId, MemberGrade newGrade) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new MemberNotFoundException(memberId));

        member.updateGrade(newGrade);
        Member savedMember = memberRepository.save(member);
        return convertToResponse(savedMember);
    }

    /**
     * 회원 정보 수정
     */
    @Transactional
    public MemberResponse updateMember(Long memberId, MemberUpdateRequest updateRequest) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new MemberNotFoundException(memberId));

        // 등급이 포함된 경우와 아닌 경우를 구분하여 처리
        if (updateRequest.getGrade() != null) {
            member.updateInfo(updateRequest.getName(), updateRequest.getEmail(),
                    updateRequest.getPhoneNumber(), updateRequest.getGrade());
        } else {
            member.updateInfo(updateRequest.getName(), updateRequest.getEmail(), updateRequest.getPhoneNumber());
        }

        Member savedMember = memberRepository.save(member);
        return convertToResponse(savedMember);
    }

    /**
     * 비밀번호 변경 (암호화 적용)
     */
    @Transactional
    @CacheEvict(value = "members", key = "#memberId")
    public void updatePassword(Long memberId, String newPassword) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new MemberNotFoundException(memberId));

        member.updatePassword(passwordEncoder.encode(newPassword));
        memberRepository.save(member);
    }

    /**
     * 비밀번호 검증
     */
    public boolean verifyPassword(Long memberId, String rawPassword) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new MemberNotFoundException(memberId));

        return passwordEncoder.matches(rawPassword, member.getPassword());
    }

    /**
     * 회원 삭제
     */
    @Transactional
    @CacheEvict(value = "members", key = "#memberId")
    public void deleteMember(Long memberId) {
        if (!memberRepository.existsById(memberId)) {
            throw new MemberNotFoundException(memberId);
        }
        memberRepository.deleteById(memberId);
    }

    /**
     * 키워드로 회원 검색 (이름, 이메일, 로그인ID)
     */
    public List<MemberResponse> searchMembers(String keyword) {
        if (keyword == null || keyword.trim().isEmpty()) {
            return getAllMembers(); // 키워드가 없으면 전체 조회
        }

        List<Member> members = memberRepository.findByKeyword(keyword.trim());
        return members.stream()
                .map(this::convertToResponse)
                .toList();
    }

    /**
     * 등급별 회원 조회
     */
    public List<MemberResponse> getMembersByGrade(MemberGrade grade) {
        List<Member> members = memberRepository.findByGrade(grade);
        return members.stream()
                .map(this::convertToResponse)
                .toList();
    }

    /**
     * 회원 활동 통계 조회
     */
    public MemberStatsDto getMemberStats(Long memberId) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new MemberNotFoundException(memberId));

        // 총 신청 횟수
        Long totalParticipations = applicationRepository.countByMember(member);

        // 완료한 예약 수 (CONFIRMED 상태)
        Long completedReservations = applicationRepository.countByMemberAndStatus(member, ReservationStatus.CONFIRMED);

        // 취소한 예약 수 (CANCELLED 상태)
        Long canceledReservations = applicationRepository.countByMemberAndStatus(member, ReservationStatus.CANCELLED);

        // 현재 대기 중인 예약 수 (WAITING 상태)
        Long waitingReservations = applicationRepository.countByMemberAndStatus(member, ReservationStatus.WAITING);

        // 참가율 계산
        Double participationRate = totalParticipations > 0
                ? (completedReservations.doubleValue() / totalParticipations.doubleValue()) * 100
                : 0.0;

        return MemberStatsDto.builder()
                .totalParticipations(totalParticipations)
                .completedReservations(completedReservations)
                .canceledReservations(canceledReservations)
                .waitingReservations(waitingReservations)
                .joinDate(member.getCreatedAt().toLocalDate())
                .participationRate(participationRate)
                .build();
    }

    /**
     * Entity를 Response DTO로 변환
     */
    private MemberResponse convertToResponse(Member member) {
        MemberResponse response = new MemberResponse();
        response.setId(member.getId());
        response.setLoginId(member.getLoginId());
        response.setName(member.getName());
        response.setEmail(member.getEmail());
        response.setPhoneNumber(member.getPhoneNumber());
        response.setBirthYear(member.getBirthYear());
        response.setGrade(member.getGrade());
        response.setGradeEmoji(member.getGrade().getEmoji());
        response.setGradeDescription(member.getGrade().getDescription());
        response.setAge(member.getAge());
        response.setAdmin(member.isAdmin());
        response.setCreatedAt(member.getCreatedAt());
        response.setUpdatedAt(member.getUpdatedAt());
        return response;
    }
}
