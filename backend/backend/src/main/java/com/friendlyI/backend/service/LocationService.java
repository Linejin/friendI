package com.friendlyI.backend.service;

import com.friendlyI.backend.dto.LocationCreateRequest;
import com.friendlyI.backend.dto.LocationResponse;
import com.friendlyI.backend.entity.Location;
import com.friendlyI.backend.repository.LocationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class LocationService {

    private final LocationRepository locationRepository;

    /**
     * 모든 활성 장소 조회
     */
    public List<LocationResponse> getAllActiveLocations() {
        List<Location> locations = locationRepository.findByIsActiveTrue();
        return locations.stream()
                .map(location -> {
                    Long activeReservationCount = locationRepository
                            .countActiveReservationsByLocation(location.getId());
                    return LocationResponse.from(location, activeReservationCount);
                })
                .collect(Collectors.toList());
    }

    /**
     * 모든 장소 조회 (관리자용)
     */
    public List<LocationResponse> getAllLocations() {
        List<Location> locations = locationRepository.findAll();
        return locations.stream()
                .map(location -> {
                    Long activeReservationCount = locationRepository
                            .countActiveReservationsByLocation(location.getId());
                    return LocationResponse.from(location, activeReservationCount);
                })
                .collect(Collectors.toList());
    }

    /**
     * 장소 ID로 조회
     */
    public LocationResponse getLocationById(Long id) {
        Location location = locationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 장소입니다: " + id));

        Long activeReservationCount = locationRepository.countActiveReservationsByLocation(id);
        return LocationResponse.from(location, activeReservationCount);
    }

    /**
     * 장소 생성
     */
    @Transactional
    public LocationResponse createLocation(LocationCreateRequest request) {
        // 중복 이름 체크
        if (locationRepository.existsByNameIgnoreCase(request.getName())) {
            throw new IllegalArgumentException("이미 존재하는 장소 이름입니다: " + request.getName());
        }

        Location location = Location.builder()
                .name(request.getName())
                .address(request.getAddress())
                .description(request.getDescription())
                .url(request.getUrl())
                .isActive(true)
                .build();

        Location savedLocation = locationRepository.save(location);
        log.info("새 장소가 생성되었습니다: {} (ID: {})", savedLocation.getName(), savedLocation.getId());

        return LocationResponse.from(savedLocation, 0L);
    }

    /**
     * 장소 수정
     */
    @Transactional
    public LocationResponse updateLocation(Long id, LocationCreateRequest request) {
        Location location = locationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 장소입니다: " + id));

        // 중복 이름 체크 (현재 장소 제외)
        if (locationRepository.existsByNameIgnoreCaseAndIdNot(request.getName(), id)) {
            throw new IllegalArgumentException("이미 존재하는 장소 이름입니다: " + request.getName());
        }

        location.updateLocation(request.getName(), request.getAddress(), request.getDescription(), request.getUrl());
        Location updatedLocation = locationRepository.save(location);

        log.info("장소가 수정되었습니다: {} (ID: {})", updatedLocation.getName(), updatedLocation.getId());

        Long activeReservationCount = locationRepository.countActiveReservationsByLocation(id);
        return LocationResponse.from(updatedLocation, activeReservationCount);
    }

    /**
     * 장소 비활성화 (삭제 대신)
     */
    @Transactional
    public void deactivateLocation(Long id) {
        Location location = locationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 장소입니다: " + id));

        // 활성 예약이 있는지 확인
        Long activeReservationCount = locationRepository.countActiveReservationsByLocation(id);
        if (activeReservationCount > 0) {
            throw new IllegalArgumentException("활성 예약이 있는 장소는 비활성화할 수 없습니다. 예약 수: " + activeReservationCount);
        }

        location.deactivate();
        locationRepository.save(location);

        log.info("장소가 비활성화되었습니다: {} (ID: {})", location.getName(), location.getId());
    }

    /**
     * 장소 활성화
     */
    @Transactional
    public void activateLocation(Long id) {
        Location location = locationRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 장소입니다: " + id));

        location.activate();
        locationRepository.save(location);

        log.info("장소가 활성화되었습니다: {} (ID: {})", location.getName(), location.getId());
    }

    /**
     * 장소 검색 (이름 또는 주소 키워드 검색)
     */
    public List<LocationResponse> searchLocations(String keyword) {
        List<Location> locations = locationRepository.findActiveLocationsByKeyword(keyword);
        return locations.stream()
                .map(location -> {
                    Long activeReservationCount = locationRepository
                            .countActiveReservationsByLocation(location.getId());
                    return LocationResponse.from(location, activeReservationCount);
                })
                .collect(Collectors.toList());
    }

    /**
     * 사용 중인 장소 조회 (활성 예약이 있는 장소)
     */
    public List<LocationResponse> getLocationsWithActiveReservations() {
        List<Location> locations = locationRepository.findLocationsWithActiveReservations();
        return locations.stream()
                .map(location -> {
                    Long activeReservationCount = locationRepository
                            .countActiveReservationsByLocation(location.getId());
                    return LocationResponse.from(location, activeReservationCount);
                })
                .collect(Collectors.toList());
    }
}