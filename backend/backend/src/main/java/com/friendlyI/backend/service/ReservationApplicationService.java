package com.friendlyI.backend.service;

import com.friendlyI.backend.dto.LocationSummary;
import com.friendlyI.backend.dto.MemberSummary;
import com.friendlyI.backend.dto.ReservationApplicationRequest;
import com.friendlyI.backend.dto.ReservationApplicationResponse;
import com.friendlyI.backend.dto.ReservationSummary;
import com.friendlyI.backend.entity.*;
import com.friendlyI.backend.exception.MemberNotFoundException;
import com.friendlyI.backend.exception.ReservationApplicationException;
import com.friendlyI.backend.exception.ReservationNotFoundException;
import com.friendlyI.backend.repository.MemberRepository;
import com.friendlyI.backend.repository.ReservationApplicationRepository;
import com.friendlyI.backend.repository.ReservationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReservationApplicationService {

    private final ReservationApplicationRepository applicationRepository;
    private final MemberRepository memberRepository;
    private final ReservationRepository reservationRepository;

    /**
     * 예약 신청
     */
    @Transactional
    public ReservationApplicationResponse applyForReservation(ReservationApplicationRequest request) {
        Member member = memberRepository.findById(request.getMemberId())
                .orElseThrow(() -> new MemberNotFoundException(request.getMemberId()));

        Reservation reservation = reservationRepository.findById(request.getReservationId())
                .orElseThrow(() -> new ReservationNotFoundException(request.getReservationId()));

        // 기존 신청이 있는지 확인 (모든 상태 포함)
        Optional<ReservationApplication> existingApplication = applicationRepository.findByMemberAndReservation(member,
                reservation);

        if (existingApplication.isPresent()) {
            ReservationApplication application = existingApplication.get();

            // 취소된 신청인 경우 재활성화
            if (application.isCancelled()) {
                return reactivateApplication(application, request.getNote());
            } else {
                // 이미 활성 상태인 신청이 있는 경우
                throw new ReservationApplicationException(
                        String.format("회원 ID %d가 예약 ID %d에 이미 신청했습니다.",
                                request.getMemberId(), request.getReservationId()));
            }
        }

        // 새로운 신청 생성
        return createNewApplication(member, reservation, request.getNote());
    }

    /**
     * 새로운 신청 생성
     */
    private ReservationApplicationResponse createNewApplication(Member member, Reservation reservation, String note) {
        // 예약 상태 결정 (정원 확인) - Repository를 통한 효율적인 조회
        Long confirmedCount = applicationRepository.countConfirmedByReservation(reservation);
        ReservationStatus status = reservation.isFullyBooked(confirmedCount.intValue()) ? ReservationStatus.WAITING
                : ReservationStatus.CONFIRMED;

        ReservationApplication application = ReservationApplication.builder()
                .member(member)
                .reservation(reservation)
                .status(status)
                .note(note)
                .build();

        ReservationApplication savedApplication = applicationRepository.save(application);
        return convertToResponse(savedApplication);
    }

    /**
     * 취소된 신청을 재활성화
     */
    private ReservationApplicationResponse reactivateApplication(ReservationApplication application, String note) {
        try {
            // 현재 예약 정원 확인
            Long confirmedCount = applicationRepository.countConfirmedByReservation(application.getReservation());
            ReservationStatus newStatus = application.getReservation().isFullyBooked(confirmedCount.intValue())
                    ? ReservationStatus.WAITING
                    : ReservationStatus.CONFIRMED;

            // 로깅 추가
            System.out.println(String.format(
                    "[ReactivateApplication] Member %d reapplying for reservation %d (previous status: %s, new status: %s)",
                    application.getMember().getId(),
                    application.getReservation().getId(),
                    application.getStatus(),
                    newStatus));

            // 신청 재활성화
            application.updateStatus(newStatus);
            if (note != null && !note.trim().isEmpty()) {
                application.updateNote(note);
            }

            ReservationApplication savedApplication = applicationRepository.save(application);

            System.out.println(String.format(
                    "[ReactivateApplication] Successfully reactivated application %d with status %s",
                    savedApplication.getId(),
                    savedApplication.getStatus()));

            return convertToResponse(savedApplication);
        } catch (Exception e) {
            System.err.println(String.format(
                    "[ReactivateApplication] Failed to reactivate application for member %d, reservation %d: %s",
                    application.getMember().getId(),
                    application.getReservation().getId(),
                    e.getMessage()));
            throw new ReservationApplicationException(
                    "취소된 예약 신청을 재활성화하는 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 예약 신청 취소
     */
    @Transactional
    public void cancelApplication(Long applicationId) {
        ReservationApplication application = applicationRepository.findById(applicationId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 신청입니다."));

        if (application.isCancelled()) {
            throw new IllegalArgumentException("이미 취소된 신청입니다.");
        }

        // 확정된 신청이었다면 대기자를 확정으로 변경
        if (application.isConfirmed()) {
            promoteWaitingToConfirmed(application.getReservation());
        }

        application.cancel();
        applicationRepository.save(application);
    }

    /**
     * 회원별 신청 조회
     */
    public List<ReservationApplicationResponse> getApplicationsByMember(Long memberId) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 회원입니다."));

        return applicationRepository.findByMember(member).stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * 예약별 신청 조회
     */
    public List<ReservationApplicationResponse> getApplicationsByReservation(Long reservationId) {
        Reservation reservation = reservationRepository.findById(reservationId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 예약입니다."));

        return applicationRepository.findByReservation(reservation).stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * 대기자를 확정으로 승격 (선착순)
     */
    @Transactional
    public void promoteWaitingToConfirmed(Reservation reservation) {
        List<ReservationApplication> waitingApplications = applicationRepository
                .findWaitingApplicationsInOrder(reservation);

        int availableSlots = reservation.getAvailableSlots();

        for (int i = 0; i < Math.min(availableSlots, waitingApplications.size()); i++) {
            ReservationApplication waitingApp = waitingApplications.get(i);
            waitingApp.confirm();
            applicationRepository.save(waitingApp);
        }
    }

    /**
     * 관리자용: 신청 상태 변경
     */
    @Transactional
    public ReservationApplicationResponse updateApplicationStatus(Long applicationId, ReservationStatus newStatus) {
        ReservationApplication application = applicationRepository.findById(applicationId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 신청입니다."));

        application.updateStatus(newStatus);
        ReservationApplication savedApplication = applicationRepository.save(application);

        // 상태 변경 후 대기자 처리
        if (newStatus == ReservationStatus.CANCELLED || newStatus == ReservationStatus.WAITING) {
            promoteWaitingToConfirmed(application.getReservation());
        }

        return convertToResponse(savedApplication);
    }

    /**
     * Entity를 Response DTO로 변환 (순환 참조 방지)
     */
    private ReservationApplicationResponse convertToResponse(ReservationApplication application) {
        ReservationApplicationResponse response = new ReservationApplicationResponse();
        response.setId(application.getId());

        // 간단한 회원 정보만 포함 (순환 참조 방지)
        MemberSummary memberSummary = new MemberSummary();
        memberSummary.setId(application.getMember().getId());
        memberSummary.setName(application.getMember().getName());
        memberSummary.setGradeEmoji(application.getMember().getGrade().getEmoji());
        memberSummary.setGradeDescription(application.getMember().getGrade().getDescription());
        response.setMemberSummary(memberSummary);

        // 간단한 예약 정보만 포함 (순환 참조 방지)
        ReservationSummary reservationSummary = new ReservationSummary();
        reservationSummary.setId(application.getReservation().getId());
        reservationSummary.setTitle(application.getReservation().getTitle());
        reservationSummary.setReservationDate(application.getReservation().getReservationDate());

        // 장소 정보를 LocationSummary로 변환
        LocationSummary locationSummary = LocationSummary.builder()
                .id(application.getReservation().getLocation().getId())
                .name(application.getReservation().getLocation().getName())
                .address(application.getReservation().getLocation().getAddress())
                .url(application.getReservation().getLocation().getUrl())
                .isActive(application.getReservation().getLocation().getIsActive())
                .build();
        reservationSummary.setLocation(locationSummary);

        reservationSummary.setMaxCapacity(application.getReservation().getMaxCapacity());
        reservationSummary.setAvailableSlots(application.getReservation().getAvailableSlots());
        response.setReservationSummary(reservationSummary);

        response.setStatus(application.getStatus());
        response.setStatusDescription(application.getStatus().getDescription());
        response.setNote(application.getNote());
        response.setAppliedAt(application.getAppliedAt());
        response.setUpdatedAt(application.getUpdatedAt());
        return response;
    }
}
