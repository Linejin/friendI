package com.friendlyI.backend.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.multipart.MultipartResolver;
import org.springframework.web.multipart.support.StandardServletMultipartResolver;

import java.io.File;

@Slf4j
@Configuration
public class FileUploadConfig {

    @Value("${app.upload.dir:${user.home}/friendly-i/uploads}")
    private String uploadDir;

    @Value("${app.upload.max-file-size:5MB}")
    private String maxFileSize;

    @Value("${app.upload.max-request-size:10MB}")
    private String maxRequestSize;

    @Bean
    public MultipartResolver multipartResolver() {
        StandardServletMultipartResolver resolver = new StandardServletMultipartResolver();
        return resolver;
    }

    @Bean
    public String uploadDirectory() {
        File directory = new File(uploadDir);
        if (!directory.exists()) {
            boolean created = directory.mkdirs();
            if (created) {
                log.info("업로드 디렉토리 생성: {}", uploadDir);
            } else {
                log.warn("업로드 디렉토리 생성 실패: {}", uploadDir);
            }
        }
        return uploadDir;
    }
}