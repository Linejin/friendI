package com.friendlyI.backend.config;

import com.friendlyI.backend.entity.Location;
import com.friendlyI.backend.entity.Member;
import com.friendlyI.backend.entity.MemberGrade;
import com.friendlyI.backend.repository.LocationRepository;
import com.friendlyI.backend.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 애플리케이션 시작 시 초기 데이터를 로드하는 클래스
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DataLoader implements CommandLineRunner {

    private final MemberRepository memberRepository;
    private final LocationRepository locationRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        createDefaultLocations();
        createDefaultAdminUser();
        createSampleUsers();
        log.info("초기 데이터 로딩 완료");
    }

    /**
     * 기본 장소 데이터 생성
     */
    private void createDefaultLocations() {
        if (locationRepository.count() == 0) {
            log.info("기본 장소 데이터 생성 중...");

            // 기본 장소들 생성
            Location[] defaultLocations = {
                    Location.builder()
                            .name("회의실 A")
                            .address("서울시 강남구 테헤란로 123번길 1층")
                            .description("소규모 회의 및 스터디용 공간 (최대 10명)")
                            .url("https://naver.me/IgJGvT1Y")  // 예시 네이버 지도 링크
                            .isActive(true)
                            .build(),
                    Location.builder()
                            .name("대강당")
                            .address("서울시 강남구 테헤란로 123번길 지하 1층")
                            .description("대규모 세미나 및 컨퍼런스용 공간 (최대 100명)")
                            .url("https://naver.me/IgJGvT1Y")  // ※ 실제 링크로 교체 필요
                            .isActive(true)
                            .build(),
                    Location.builder()
                            .name("스터디룸 1")
                            .address("서울시 강남구 테헤란로 123번길 2층")
                            .description("조용한 스터디 공간 (최대 6명)")
                            .url("https://naver.me/IgJGvT1Y")  // ※ 실제 링크로 교체 필요
                            .isActive(true)
                            .build(),
                    Location.builder()
                            .name("세미나실 B")
                            .address("서울시 강남구 테헤란로 123번길 3층")
                            .description("중규모 세미나 및 워크샵용 공간 (최대 30명)")
                            .url("https://naver.me/IgJGvT1Y")  // ※ 실제 링크로 교체 필요
                            .isActive(true)
                            .build(),
                    Location.builder()
                            .name("온라인 회의실")
                            .address("온라인")
                            .description("온라인 화상회의 공간 (제한 없음) - 미팅 링크는 예약 확정 시 별도 안내")
                            .url("https://naver.me/IgJGvT1Y")  // ※ 본사 주소 등의 지도 링크로 입력
                            .isActive(true)
                            .build()
            };


            for (Location location : defaultLocations) {
                locationRepository.save(location);
                log.info("기본 장소 생성: {} - {}", location.getName(), location.getAddress());
            }

            log.info("기본 장소 데이터 생성 완료");
        }
    }

    /**
     * 기본 관리자 계정 생성
     */
    private void createDefaultAdminUser() {
        String adminLoginId = environment.getProperty("ADMIN_USERNAME", "admin");
        String adminPassword = environment.getProperty("ADMIN_PASSWORD", "friendlyi2025!");

        // 이미 admin 계정이 존재하는지 확인
        if (memberRepository.existsByLoginId(adminLoginId)) {
            log.info("관리자 계정이 이미 존재합니다: {}", adminLoginId);
            return;
        }

        // 관리자 계정 생성
        Member admin = Member.builder()
                .loginId(adminLoginId)
                .password(passwordEncoder.encode(adminPassword))
                .name("시스템 관리자")
                .email("admin@friendlyi.com")
                .phoneNumber("010-0000-0000")
                .birthYear(1990)
                .grade(MemberGrade.ROOSTER)
                .build();

        memberRepository.save(admin);

        log.info("기본 관리자 계정이 생성되었습니다.");
        log.info("로그인 ID: {}", adminLoginId);
        // 보안상 패스워드는 로그에 출력하지 않음
        log.warn("⚠️ 보안을 위해 초기 패스워드를 반드시 변경해주세요!");
    }

    /**
     * 샘플 사용자 계정들 생성 (테스트용)
     */
    private void createSampleUsers() {
        // 각 등급별로 샘플 사용자 생성
        createSampleUserIfNotExists("egg_user", "1234", "김알이", "egg@test.com", "010-1111-1111", 2005, MemberGrade.EGG);
        createSampleUserIfNotExists("hatching_user", "1234", "이부화", "hatching@test.com", "010-2222-2222", 2003,
                MemberGrade.HATCHING);
        createSampleUserIfNotExists("chick_user", "1234", "박병아리", "chick@test.com", "010-3333-3333", 2001,
                MemberGrade.CHICK);
        createSampleUserIfNotExists("young_bird_user", "1234", "최어린새", "youngbird@test.com", "010-4444-4444", 1999,
                MemberGrade.YOUNG_BIRD);

        log.info("샘플 사용자 계정들이 생성되었습니다 (비밀번호: 1234)");
    }

    /**
     * 사용자가 존재하지 않는 경우에만 생성
     */
    private void createSampleUserIfNotExists(String loginId, String password, String name, String email,
            String phoneNumber, int birthYear, MemberGrade grade) {
        if (!memberRepository.existsByLoginId(loginId)) {
            Member user = Member.builder()
                    .loginId(loginId)
                    .password(passwordEncoder.encode(password))
                    .name(name)
                    .email(email)
                    .phoneNumber(phoneNumber)
                    .birthYear(birthYear)
                    .grade(grade)
                    .build();
            memberRepository.save(user);
            log.info("샘플 사용자 생성: {} ({})", name, grade.getDescription());
        }
    }
}