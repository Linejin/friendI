package com.friendlyI.backend.controller;

import com.friendlyI.backend.config.security.RequireAuth;
import com.friendlyI.backend.service.FileUploadService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.Map;

@Slf4j
// @RestController
// @RequestMapping("/api/files")
@RequiredArgsConstructor
@Tag(name = "파일 관리", description = "파일 업로드 및 다운로드 API")
public class FileController {

    private final FileUploadService fileUploadService;

    @RequireAuth
    @Operation(summary = "프로필 이미지 업로드 📸", description = "회원 프로필 이미지를 업로드합니다.")
    @PostMapping(value = "/profiles/{memberId}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Map<String, String>> uploadProfileImage(
            @Parameter(description = "회원 ID") @PathVariable Long memberId,
            @Parameter(description = "프로필 이미지 파일", content = @io.swagger.v3.oas.annotations.media.Content(mediaType = MediaType.MULTIPART_FORM_DATA_VALUE)) @RequestParam("file") MultipartFile file) {

        try {
            String fileUrl = fileUploadService.uploadProfileImage(file, memberId);

            Map<String, String> response = new HashMap<>();
            response.put("message", "프로필 이미지 업로드가 완료되었습니다.");
            response.put("fileUrl", fileUrl);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("프로필 이미지 업로드 실패: memberId={}, error={}", memberId, e.getMessage());

            Map<String, String> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());

            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    @RequireAuth
    @Operation(summary = "프로필 이미지 삭제 🗑️", description = "회원 프로필 이미지를 삭제합니다.")
    @DeleteMapping("/profiles/{memberId}")
    public ResponseEntity<Map<String, String>> deleteProfileImage(
            @Parameter(description = "회원 ID") @PathVariable Long memberId) {

        try {
            fileUploadService.deleteProfileImage(memberId);

            Map<String, String> response = new HashMap<>();
            response.put("message", "프로필 이미지가 삭제되었습니다.");

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("프로필 이미지 삭제 실패: memberId={}, error={}", memberId, e.getMessage());

            Map<String, String> errorResponse = new HashMap<>();
            errorResponse.put("error", e.getMessage());

            return ResponseEntity.badRequest().body(errorResponse);
        }
    }

    @Operation(summary = "프로필 이미지 조회 🖼️", description = "업로드된 프로필 이미지를 조회합니다.")
    @GetMapping("/profiles/{memberId}/{fileName}")
    public ResponseEntity<Resource> getProfileImage(
            @Parameter(description = "회원 ID") @PathVariable Long memberId,
            @Parameter(description = "파일명") @PathVariable String fileName) {

        try {
            String relativePath = "profiles/" + memberId + "/" + fileName;
            File file = fileUploadService.getFile(relativePath);

            Resource resource = new FileSystemResource(file);
            String contentType = Files.probeContentType(file.toPath());

            if (contentType == null) {
                contentType = "application/octet-stream";
            }

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(contentType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + fileName + "\"")
                    .body(resource);

        } catch (Exception e) {
            log.error("프로필 이미지 조회 실패: memberId={}, fileName={}, error={}", memberId, fileName, e.getMessage());
            return ResponseEntity.notFound().build();
        }
    }
}