package com.friendlyI.backend.controller;

import com.friendlyI.backend.dto.LoginRequest;
import com.friendlyI.backend.dto.LoginResponse;
import com.friendlyI.backend.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * 인증 관련 API 컨트롤러
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "인증 API", description = "로그인, 로그아웃 등 인증 관련 API")
public class AuthController {

    private final AuthService authService;

    @Operation(summary = "로그인", description = "사용자 로그인을 처리합니다")
    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("로그인 시도: {}", request.getLoginId());

        try {
            LoginResponse response = authService.login(request);
            log.info("로그인 성공: {}", request.getLoginId());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("로그인 실패: {} - {}", request.getLoginId(), e.getMessage());
            throw e;
        }
    }

    @Operation(summary = "로그아웃", description = "사용자 로그아웃을 처리합니다")
    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        // 현재는 단순히 성공 응답만 반환 (JWT 토큰은 클라이언트에서 삭제)
        log.info("로그아웃 요청");
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "토큰 검증", description = "현재 토큰의 유효성을 검증합니다")
    @GetMapping("/validate")
    public ResponseEntity<Void> validateToken() {
        // 현재는 단순히 성공 응답만 반환 (추후 JWT 토큰 검증 로직 추가)
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "현재 사용자 정보", description = "현재 로그인한 사용자의 정보를 반환합니다")
    @GetMapping("/me")
    public ResponseEntity<LoginResponse> getCurrentUser() {
        // 현재는 임시로 admin 사용자 정보 반환 (추후 JWT에서 사용자 정보 추출)
        LoginResponse response = authService.getCurrentUserInfo();
        return ResponseEntity.ok(response);
    }
}