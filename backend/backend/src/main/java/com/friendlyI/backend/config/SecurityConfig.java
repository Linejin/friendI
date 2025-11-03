package com.friendlyI.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.http.HttpMethod;

import java.util.List;

import static org.springframework.security.config.Customizer.withDefaults;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

        @Bean
        public PasswordEncoder passwordEncoder() {
                return new BCryptPasswordEncoder(12);
        }

        @Bean
        public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
                http
                        // ✅ CORS 활성화 (아래 corsConfigurationSource()와 세트)
                        .cors(withDefaults())

                        // CSRF 비활성화 (API)
                        .csrf(csrf -> csrf.disable())

                        // 보안 헤더
                        .headers(headers -> headers
                                // H2 콘솔 쓸 거면 sameOrigin 권장
                                .frameOptions(frame -> frame.sameOrigin())
                                .contentTypeOptions(withDefaults())
                                .httpStrictTransportSecurity(hsts -> hsts
                                        .maxAgeInSeconds(31536000)
                                        .includeSubDomains(true))
                                .referrerPolicy(ref -> ref
                                        .policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
                        )

                        // 세션 Stateless
                        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                        // 권한
                        .authorizeHttpRequests(auth -> auth
                                // ✅ CORS Preflight 허용
                                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()

                                // Swagger / H2 / Actuator
                                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
                                .requestMatchers("/h2-console/**").permitAll()
                                .requestMatchers("/actuator/health", "/actuator/info").permitAll()

                                // ✅ API 공개 범위
                                .requestMatchers("/api/locations/**").permitAll()

                                // 기존 임시 공개
                                .requestMatchers("/api/auth/**").permitAll()
                                .requestMatchers("/api/members/**").permitAll()
                                .requestMatchers("/api/reservations/**").permitAll()
                                .requestMatchers("/api/reservation-applications/**").permitAll()

                                // 그 외 보호
                                .anyRequest().authenticated()
                        );

                return http.build();
        }

        // ✅ 프론트 개발 서버 CORS 허용
        @Bean
        public CorsConfigurationSource corsConfigurationSource() {
                CorsConfiguration cfg = new CorsConfiguration();
                cfg.setAllowedOriginPatterns(List.of("http://localhost:3000", "http://*:3000"));
                cfg.setAllowedMethods(List.of("GET","POST","PUT","PATCH","DELETE","OPTIONS"));
                cfg.setAllowedHeaders(List.of("*"));
                cfg.setAllowCredentials(true);
                cfg.setMaxAge(3600L);

                UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
                source.registerCorsConfiguration("/**", cfg);
                return source;
        }
}
