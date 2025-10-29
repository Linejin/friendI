package com.friendlyI.backend.service;

import com.friendlyI.backend.dto.LocationSummary;
import com.friendlyI.backend.dto.ReservationApplicantDto;
import com.friendlyI.backend.dto.ReservationCreateRequest;
import com.friendlyI.backend.dto.ReservationResponse;
import com.friendlyI.backend.entity.Location;
import com.friendlyI.backend.entity.Member;
import com.friendlyI.backend.entity.Reservation;
import com.friendlyI.backend.entity.ReservationApplication;
import com.friendlyI.backend.entity.ReservationStatus;
import com.friendlyI.backend.repository.LocationRepository;
import com.friendlyI.backend.repository.MemberRepository;
import com.friendlyI.backend.repository.ReservationApplicationRepository;
import com.friendlyI.backend.repository.ReservationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReservationService {

    private final ReservationRepository reservationRepository;
    private final LocationRepository locationRepository;
    private final MemberRepository memberRepository;
    private final ReservationApplicationRepository reservationApplicationRepository;

    /**
     * 예약 생성 (생성자 자동 신청)
     */
    @Transactional
    public ReservationResponse createReservation(ReservationCreateRequest request, Long creatorMemberId) {
        if (request.getReservationDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("과거 날짜로는 예약을 생성할 수 없습니다.");
        }

        if (request.getLocations() == null || request.getLocations().isEmpty()) {
            throw new IllegalArgumentException("최소 1개의 장소는 필요합니다.");
        }

        // 생성자 회원 조회
        Member creator = memberRepository.findById(creatorMemberId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 회원입니다."));

        // 첫 번째 장소를 사용 (향후 여러 장소 지원 시 확장 가능)
        ReservationCreateRequest.LocationInfo locationInfo = request.getLocations().get(0);

        // 장소 찾기 또는 생성
        Location location = findOrCreateLocation(
                locationInfo.getName(),
                locationInfo.getAddress(),
                locationInfo.getUrl());

        Reservation reservation = Reservation.builder()
                .title(request.getTitle())
                .description(request.getDescription())
                .location(location)
                .maxCapacity(request.getMaxCapacity())
                .reservationDate(request.getReservationDate())
                .reservationTime(request.getReservationTime())
                .creator(creator) // ✅ 생성자 기록
                .build();

        Reservation savedReservation = reservationRepository.save(reservation);

        // 생성자를 자동으로 예약 신청 (확정 상태)
        ReservationApplication creatorApplication = ReservationApplication.builder()
                .member(creator)
                .reservation(savedReservation)
                .status(ReservationStatus.CONFIRMED)
                .note("예약 생성자 자동 신청")
                .build();

        reservationApplicationRepository.save(creatorApplication);

        return convertToResponse(savedReservation);
    }

    /**
     * 장소를 찾거나 없으면 새로 생성
     */
    private Location findOrCreateLocation(String name, String address, String url) {
        // 이름과 주소가 같은 장소가 있는지 확인
        return locationRepository.findByNameIgnoreCaseAndAddressIgnoreCase(name, address)
                .orElseGet(() -> {
                    // 없으면 새로 생성
                    Location newLocation = Location.builder()
                            .name(name)
                            .address(address)
                            .url(url)
                            .description("자동 생성된 장소")
                            .isActive(true)
                            .build();
                    return locationRepository.save(newLocation);
                });
    }

    /**
     * 예약 ID로 조회
     */
    public ReservationResponse getReservationById(Long id) {
        Reservation reservation = reservationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 예약입니다."));
        return convertToResponse(reservation);
    }

    /**
     * 모든 예약 조회 (날짜순)
     */
    public List<ReservationResponse> getAllReservations() {
        return reservationRepository.findAllByOrderByReservationDateAsc().stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * 날짜별 예약 조회
     */
    public List<ReservationResponse> getReservationsByDate(LocalDate date) {
        return reservationRepository.findByReservationDate(date).stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * 예약 가능한 예약 조회
     */
    public List<ReservationResponse> getAvailableReservations() {
        return reservationRepository.findAvailableReservations().stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * 미래 예약 조회
     */
    public List<ReservationResponse> getFutureReservations() {
        return reservationRepository.findByReservationDateAfter(LocalDate.now()).stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * 예약 수정
     */
    @Transactional
    public ReservationResponse updateReservation(Long id, ReservationCreateRequest request) {
        Reservation reservation = reservationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 예약입니다."));

        if (request.getReservationDate().isBefore(LocalDate.now())) {
            throw new IllegalArgumentException("과거 날짜로는 예약을 수정할 수 없습니다.");
        }

        if (request.getLocations() == null || request.getLocations().isEmpty()) {
            throw new IllegalArgumentException("최소 1개의 장소는 필요합니다.");
        }

        // 첫 번째 장소를 사용 (향후 여러 장소 지원 시 확장 가능)
        ReservationCreateRequest.LocationInfo locationInfo = request.getLocations().get(0);

        // 장소 찾기 또는 생성
        Location location = findOrCreateLocation(
                locationInfo.getName(),
                locationInfo.getAddress(),
                locationInfo.getUrl());

        reservation.updateReservation(
                request.getTitle(),
                request.getDescription(),
                location,
                request.getMaxCapacity(),
                request.getReservationDate(),
                request.getReservationTime());

        Reservation savedReservation = reservationRepository.save(reservation);
        return convertToResponse(savedReservation);
    }

    /**
     * 예약 삭제
     */
    @Transactional
    public void deleteReservation(Long id) {
        if (!reservationRepository.existsById(id)) {
            throw new IllegalArgumentException("존재하지 않는 예약입니다.");
        }
        reservationRepository.deleteById(id);
    }

    // ✅ 예약 수정 (권한 검증 추가)
    @Transactional
    public ReservationResponse updateReservation(Long id, ReservationCreateRequest request, Long actorMemberId) {
        Reservation reservation = reservationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 예약입니다."));

        // 🔒 권한 검증
        assertEditable(reservation, actorMemberId);

        // 날짜/장소 검증 + 수정 로직 ...
        // reservation.updateReservation(...);
        return convertToResponse(reservation);
    }

    // ✅ 예약 삭제 (권한 검증 추가)
    @Transactional
    public void deleteReservation(Long id, Long actorMemberId) {
        Reservation reservation = reservationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 예약입니다."));

        // 🔒 권한 검증
        assertEditable(reservation, actorMemberId);

        reservationRepository.delete(reservation);
    }

    /**
     * 🔒 예약 수정/삭제 권한 검증
     * creator == actor or admin only
     */
    private void assertEditable(Reservation reservation, Long actorMemberId) {
        Member actor = memberRepository.findById(actorMemberId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 회원입니다."));
        boolean isCreator = reservation.getCreator() != null
                && reservation.getCreator().getId().equals(actorMemberId);
        boolean isAdmin = actor.isAdmin(); // or actor.getRole() == Role.ADMIN

        if (!(isCreator || isAdmin)) {
            throw new org.springframework.security.access.AccessDeniedException("수정/삭제 권한이 없습니다.");
        }
    }

    /**
     * Entity를 Response DTO로 변환
     */
    private ReservationResponse convertToResponse(Reservation reservation) {
        ReservationResponse response = new ReservationResponse();
        response.setId(reservation.getId());
        response.setTitle(reservation.getTitle());
        response.setDescription(reservation.getDescription());

        LocationSummary locationSummary = LocationSummary.builder()
                .id(reservation.getLocation().getId())
                .name(reservation.getLocation().getName())
                .address(reservation.getLocation().getAddress())
                .url(reservation.getLocation().getUrl())
                .isActive(reservation.getLocation().getIsActive())
                .build();
        response.setLocation(locationSummary);

        response.setMaxCapacity(reservation.getMaxCapacity());
        response.setReservationDate(reservation.getReservationDate());
        response.setReservationTime(reservation.getReservationTime());
        response.setConfirmedCount(reservation.getConfirmedCount());
        response.setWaitingCount(reservation.getWaitingCount());
        response.setAvailableSlots(reservation.getAvailableSlots());
        response.setFullyBooked(reservation.isFullyBooked());
        response.setCreatedAt(reservation.getCreatedAt());
        response.setUpdatedAt(reservation.getUpdatedAt());

        // ✅ 추가: 생성자 정보 내려주기
        if (reservation.getCreator() != null) {
            response.setCreatorId(reservation.getCreator().getId());
            response.setCreatorName(reservation.getCreator().getName());
        }

        return response;
    }

    /**
     * 예약의 신청자 목록 조회
     */
    public List<ReservationApplicantDto> getReservationApplicants(Long reservationId) {
        Reservation reservation = reservationRepository.findById(reservationId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 예약입니다."));

        List<ReservationApplication> applications = reservationApplicationRepository
                .findByReservationOrderByAppliedAtAsc(reservation);

        return applications.stream()
                .map(application -> ReservationApplicantDto.builder()
                        .applicationId(application.getId()) // 신청 ID 추가
                        .memberId(application.getMember().getId())
                        .memberName(application.getMember().getName())
                        .memberLoginId(application.getMember().getLoginId())
                        .status(application.getStatus())
                        .appliedAt(application.getAppliedAt())
                        .isCreator(application.getMember().getId().equals(reservation.getCreator().getId()))
                        .build())
                .collect(Collectors.toList());
    }

}
