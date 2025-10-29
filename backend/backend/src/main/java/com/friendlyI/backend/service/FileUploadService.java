package com.friendlyI.backend.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class FileUploadService {

    @Value("${app.upload.dir:${user.home}/friendly-i/uploads}")
    private String uploadDir;

    private static final List<String> ALLOWED_EXTENSIONS = Arrays.asList("jpg", "jpeg", "png", "gif");
    private static final long MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

    /**
     * 프로필 이미지 업로드
     */
    public String uploadProfileImage(MultipartFile file, Long memberId) {
        validateFile(file);

        try {
            String fileName = generateFileName(file, memberId);
            String profileDir = uploadDir + "/profiles/" + memberId;

            // 디렉토리 생성
            File directory = new File(profileDir);
            if (!directory.exists()) {
                directory.mkdirs();
            }

            // 기존 프로필 이미지 삭제
            deleteExistingProfileImage(memberId);

            // 파일 저장
            Path filePath = Paths.get(profileDir, fileName);
            Files.copy(file.getInputStream(), filePath);

            log.info("프로필 이미지 업로드 완료: memberId={}, fileName={}", memberId, fileName);

            return "/api/files/profiles/" + memberId + "/" + fileName;

        } catch (IOException e) {
            log.error("파일 업로드 실패: memberId={}, error={}", memberId, e.getMessage());
            throw new RuntimeException("파일 업로드에 실패했습니다.", e);
        }
    }

    /**
     * 프로필 이미지 삭제
     */
    public void deleteProfileImage(Long memberId) {
        deleteExistingProfileImage(memberId);
        log.info("프로필 이미지 삭제 완료: memberId={}", memberId);
    }

    /**
     * 파일 유효성 검증
     */
    private void validateFile(MultipartFile file) {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("업로드할 파일이 없습니다.");
        }

        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("파일 크기가 너무 큽니다. (최대 5MB)");
        }

        String originalFileName = file.getOriginalFilename();
        if (originalFileName == null) {
            throw new IllegalArgumentException("파일 이름이 없습니다.");
        }

        String extension = getFileExtension(originalFileName).toLowerCase();
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new IllegalArgumentException("허용되지 않는 파일 형식입니다. (jpg, jpeg, png, gif만 허용)");
        }
    }

    /**
     * 파일명 생성
     */
    private String generateFileName(MultipartFile file, Long memberId) {
        String originalFileName = file.getOriginalFilename();
        String extension = getFileExtension(originalFileName);
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        String uuid = UUID.randomUUID().toString().substring(0, 8);

        return String.format("profile_%d_%s_%s.%s", memberId, timestamp, uuid, extension);
    }

    /**
     * 파일 확장자 추출
     */
    private String getFileExtension(String fileName) {
        int lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex == -1) {
            return "";
        }
        return fileName.substring(lastDotIndex + 1);
    }

    /**
     * 기존 프로필 이미지 삭제
     */
    private void deleteExistingProfileImage(Long memberId) {
        String profileDir = uploadDir + "/profiles/" + memberId;
        File directory = new File(profileDir);

        if (directory.exists() && directory.isDirectory()) {
            File[] files = directory.listFiles();
            if (files != null) {
                for (File file : files) {
                    if (file.isFile() && file.getName().startsWith("profile_")) {
                        boolean deleted = file.delete();
                        log.debug("기존 프로필 이미지 삭제: {} (성공: {})", file.getName(), deleted);
                    }
                }
            }
        }
    }

    /**
     * 파일 경로로 실제 파일 조회
     */
    public File getFile(String relativePath) {
        File file = new File(uploadDir + "/" + relativePath);
        if (!file.exists() || !file.isFile()) {
            throw new IllegalArgumentException("파일을 찾을 수 없습니다.");
        }
        return file;
    }
}