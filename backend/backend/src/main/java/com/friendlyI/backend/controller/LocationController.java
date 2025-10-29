package com.friendlyI.backend.controller;

import com.friendlyI.backend.config.security.RequireAuth;
import com.friendlyI.backend.dto.LocationCreateRequest;
import com.friendlyI.backend.dto.LocationResponse;
import com.friendlyI.backend.service.LocationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/locations")
@RequiredArgsConstructor
@Tag(name = "장소 관리", description = "예약 장소 생성, 조회, 수정, 활성화/비활성화 API")
public class LocationController {

    private final LocationService locationService;

    @Operation(summary = "활성 장소 조회 🏢", description = "예약 가능한 활성 장소들을 조회합니다.")
    @GetMapping("/active")
    public ResponseEntity<List<LocationResponse>> getActiveLocations() {
        List<LocationResponse> locations = locationService.getAllActiveLocations();
        return ResponseEntity.ok(locations);
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "모든 장소 조회 📋", description = "모든 장소를 조회합니다. (관리자 전용)")
    @GetMapping
    public ResponseEntity<List<LocationResponse>> getAllLocations() {
        List<LocationResponse> locations = locationService.getAllLocations();
        return ResponseEntity.ok(locations);
    }

    @Operation(summary = "장소 상세 조회 🔍", description = "특정 장소의 상세 정보를 조회합니다.")
    @GetMapping("/{id}")
    public ResponseEntity<LocationResponse> getLocationById(
            @Parameter(description = "장소 ID") @PathVariable Long id) {
        LocationResponse location = locationService.getLocationById(id);
        return ResponseEntity.ok(location);
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "장소 생성 ➕", description = "새로운 장소를 생성합니다. (관리자 전용)")
    @PostMapping
    public ResponseEntity<LocationResponse> createLocation(
            @Parameter(description = "장소 생성 요청 정보") @Valid @RequestBody LocationCreateRequest request) {
        LocationResponse response = locationService.createLocation(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "장소 수정 ✏️", description = "기존 장소 정보를 수정합니다. (관리자 전용)")
    @PutMapping("/{id}")
    public ResponseEntity<LocationResponse> updateLocation(
            @Parameter(description = "장소 ID") @PathVariable Long id,
            @Parameter(description = "장소 수정 요청 정보") @Valid @RequestBody LocationCreateRequest request) {
        LocationResponse response = locationService.updateLocation(id, request);
        return ResponseEntity.ok(response);
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "장소 비활성화 ⏸️", description = "장소를 비활성화합니다. 활성 예약이 있으면 불가능합니다. (관리자 전용)")
    @PutMapping("/{id}/deactivate")
    public ResponseEntity<Void> deactivateLocation(
            @Parameter(description = "장소 ID") @PathVariable Long id) {
        locationService.deactivateLocation(id);
        return ResponseEntity.noContent().build();
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "장소 활성화 ▶️", description = "장소를 활성화합니다. (관리자 전용)")
    @PutMapping("/{id}/activate")
    public ResponseEntity<Void> activateLocation(
            @Parameter(description = "장소 ID") @PathVariable Long id) {
        locationService.activateLocation(id);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "장소 검색 🔎", description = "장소 이름 또는 주소로 검색합니다.")
    @GetMapping("/search")
    public ResponseEntity<List<LocationResponse>> searchLocations(
            @Parameter(description = "검색 키워드") @RequestParam String keyword) {
        List<LocationResponse> locations = locationService.searchLocations(keyword);
        return ResponseEntity.ok(locations);
    }

    @Operation(summary = "사용 중인 장소 조회 📍", description = "현재 활성 예약이 있는 장소들을 조회합니다.")
    @GetMapping("/in-use")
    public ResponseEntity<List<LocationResponse>> getLocationsInUse() {
        List<LocationResponse> locations = locationService.getLocationsWithActiveReservations();
        return ResponseEntity.ok(locations);
    }
}