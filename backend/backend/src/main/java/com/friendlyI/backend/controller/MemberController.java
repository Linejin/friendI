package com.friendlyI.backend.controller;

import com.friendlyI.backend.dto.MemberCreateRequest;
import com.friendlyI.backend.dto.MemberResponse;
import com.friendlyI.backend.dto.MemberStatsDto;
import com.friendlyI.backend.dto.MemberUpdateRequest;
import com.friendlyI.backend.dto.common.PageResponse;
import com.friendlyI.backend.config.security.RequireAuth;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import com.friendlyI.backend.entity.MemberGrade;
import com.friendlyI.backend.service.MemberService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/members")
@RequiredArgsConstructor
@Tag(name = "회원 관리", description = "회원 생성, 조회, 수정, 삭제 API")
public class MemberController {

    private final MemberService memberService;

    @Operation(summary = "회원 생성 🐣", description = "새로운 회원을 생성합니다. 기본 등급은 🥚(알) 등급으로 설정됩니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "회원 생성 성공", content = @Content(schema = @Schema(implementation = MemberResponse.class))),
            @ApiResponse(responseCode = "400", description = "잘못된 요청 (중복 ID, 유효성 검증 실패)", content = @Content),
            @ApiResponse(responseCode = "500", description = "서버 오류", content = @Content)
    })
    @PostMapping
    public ResponseEntity<MemberResponse> createMember(
            @Parameter(description = "회원 생성 요청 정보", required = true) @Valid @RequestBody MemberCreateRequest request) {
        MemberResponse response = memberService.createMember(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(summary = "전체 회원 조회 📋", description = "등록된 모든 회원 목록을 조회합니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "조회 성공", content = @Content(schema = @Schema(implementation = MemberResponse.class))),
            @ApiResponse(responseCode = "500", description = "서버 오류", content = @Content)
    })
    @GetMapping
    public ResponseEntity<List<MemberResponse>> getAllMembers() {
        List<MemberResponse> members = memberService.getAllMembers();
        return ResponseEntity.ok(members);
    }

    @Operation(summary = "회원 목록 페이징 조회 📄", description = "페이징을 지원하는 회원 목록 조회입니다.")
    @GetMapping("/paged")
    public ResponseEntity<PageResponse<MemberResponse>> getAllMembersPaged(
            @Parameter(description = "페이지 번호 (0부터 시작)") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "페이지 크기") @RequestParam(defaultValue = "10") int size,
            @Parameter(description = "정렬 기준") @RequestParam(defaultValue = "createdAt") String sortBy,
            @Parameter(description = "정렬 방향") @RequestParam(defaultValue = "desc") String sortDir) {

        Sort sort = Sort.by(Sort.Direction.fromString(sortDir), sortBy);
        Pageable pageable = PageRequest.of(page, size, sort);

        Page<MemberResponse> memberPage = memberService.getAllMembersPaged(pageable);
        return ResponseEntity.ok(PageResponse.of(memberPage));
    }

    /**
     * 회원 ID로 조회
     */
    @GetMapping("/{id}")
    public ResponseEntity<MemberResponse> getMemberById(@PathVariable Long id) {
        MemberResponse member = memberService.getMemberById(id);
        return ResponseEntity.ok(member);
    }

    /**
     * 로그인 ID로 조회
     */
    @GetMapping("/login/{loginId}")
    public ResponseEntity<MemberResponse> getMemberByLoginId(@PathVariable String loginId) {
        MemberResponse member = memberService.getMemberByLoginId(loginId);
        return ResponseEntity.ok(member);
    }

    @RequireAuth
    @Operation(summary = "회원 정보 수정 ✏️", description = "회원의 이름, 이메일, 전화번호를 수정합니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "회원 정보 수정 성공", content = @Content(schema = @Schema(implementation = MemberResponse.class))),
            @ApiResponse(responseCode = "404", description = "존재하지 않는 회원", content = @Content),
            @ApiResponse(responseCode = "400", description = "잘못된 요청", content = @Content)
    })
    @PutMapping("/{id}")
    public ResponseEntity<MemberResponse> updateMember(
            @Parameter(description = "회원 ID", required = true) @PathVariable Long id,
            @Parameter(description = "수정할 회원 정보", required = true) @Valid @RequestBody MemberUpdateRequest request) {
        MemberResponse member = memberService.updateMember(id, request);
        return ResponseEntity.ok(member);
    }

    @RequireAuth(adminOnly = true)
    @Operation(summary = "회원 등급 업그레이드 ⬆️", description = "회원의 등급을 변경합니다. 🥚→🐣→🐥→🐤→🐔(관리자) 순서로 등급이 있습니다.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "등급 변경 성공", content = @Content(schema = @Schema(implementation = MemberResponse.class))),
            @ApiResponse(responseCode = "404", description = "존재하지 않는 회원", content = @Content),
            @ApiResponse(responseCode = "400", description = "잘못된 등급", content = @Content)
    })
    @PutMapping("/{id}/grade")
    public ResponseEntity<MemberResponse> upgradeGrade(
            @Parameter(description = "회원 ID", required = true) @PathVariable Long id,
            @Parameter(description = "새로운 등급 (EGG, HATCHING, CHICK, YOUNG_BIRD, ROOSTER)", required = true) @RequestParam MemberGrade grade) {
        MemberResponse member = memberService.upgradeGrade(id, grade);
        return ResponseEntity.ok(member);
    }

    @Operation(summary = "회원 검색 🔍", description = "이름, 이메일, 로그인ID로 회원을 검색합니다.")
    @GetMapping("/search")
    public ResponseEntity<List<MemberResponse>> searchMembers(
            @Parameter(description = "검색 키워드") @RequestParam String keyword) {
        List<MemberResponse> members = memberService.searchMembers(keyword);
        return ResponseEntity.ok(members);
    }

    @Operation(summary = "등급별 회원 조회 📊", description = "특정 등급의 회원들을 조회합니다.")
    @GetMapping("/grade/{grade}")
    public ResponseEntity<List<MemberResponse>> getMembersByGrade(
            @Parameter(description = "회원 등급") @PathVariable MemberGrade grade) {
        List<MemberResponse> members = memberService.getMembersByGrade(grade);
        return ResponseEntity.ok(members);
    }

    @Operation(summary = "회원 활동 통계 조회 📈", description = "회원의 예약 참가 통계를 조회합니다.")
    @GetMapping("/{id}/stats")
    public ResponseEntity<MemberStatsDto> getMemberStats(
            @Parameter(description = "회원 ID") @PathVariable Long id) {
        MemberStatsDto stats = memberService.getMemberStats(id);
        return ResponseEntity.ok(stats);
    }

    /**
     * 회원 삭제
     */
    @RequireAuth(adminOnly = true)
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMember(@PathVariable Long id) {
        memberService.deleteMember(id);
        return ResponseEntity.noContent().build();
    }

    /**
     * 예외 처리
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleIllegalArgumentException(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(e.getMessage());
    }
}
