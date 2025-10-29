package com.friendlyI.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.friendlyI.backend.controller.MemberController;
import com.friendlyI.backend.dto.MemberCreateRequest;
import com.friendlyI.backend.dto.MemberResponse;
import com.friendlyI.backend.dto.MemberUpdateRequest;
import com.friendlyI.backend.entity.MemberGrade;
import com.friendlyI.backend.exception.DuplicateResourceException;
import com.friendlyI.backend.exception.ResourceNotFoundException;
import com.friendlyI.backend.service.MemberService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.List;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.BDDMockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(MemberController.class)
@ActiveProfiles("test")
@DisplayName("MemberController 테스트")
class MemberControllerTest {

        @Autowired
        private MockMvc mockMvc;

        @MockBean
        private MemberService memberService;

        @Autowired
        private ObjectMapper objectMapper;

        private MemberResponse testMemberDto;

        @BeforeEach
        void setUp() {
                testMemberDto = MemberResponse.builder()
                                .id(1L)
                                .loginId("testuser")
                                .name("테스트유저")
                                .email("test@example.com")
                                .phoneNumber("010-1234-5678")
                                .grade(MemberGrade.EGG)
                                .build();
        }

        @Test
        @DisplayName("회원 생성 - 성공")
        void createMember_Success() throws Exception {
                // given
                MemberCreateDto createDto = MemberCreateDto.builder()
                                .loginId("newuser")
                                .password("password123")
                                .name("새유저")
                                .birthYear(1995)
                                .build();

                given(memberService.createMember(any(MemberCreateDto.class))).willReturn(testMemberDto);

                // when & then
                mockMvc.perform(post("/api/members")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(createDto)))
                                .andDo(print())
                                .andExpect(status().isCreated())
                                .andExpected(jsonPath("$.loginId").value("testuser"))
                                .andExpect(jsonPath("$.name").value("테스트유저"))
                                .andExpect(jsonPath("$.grade").value("EGG"));

                verify(memberService).createMember(any(MemberCreateDto.class));
        }

        @Test
        @DisplayName("회원 생성 - 실패 (잘못된 입력)")
        void createMember_InvalidInput() throws Exception {
                // given
                MemberCreateDto invalidDto = MemberCreateDto.builder()
                                .loginId("") // 빈 값
                                .password("123") // 너무 짧음
                                .name("") // 빈 값
                                .birthYear(1800) // 너무 오래된 년도
                                .build();

                // when & then
                mockMvc.perform(post("/api/members")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(invalidDto)))
                                .andDo(print())
                                .andExpect(status().isBadRequest())
                                .andExpect(jsonPath("$.errors").exists());

                verify(memberService, never()).createMember(any());
        }

        @Test
        @DisplayName("회원 생성 - 실패 (중복된 로그인 ID)")
        void createMember_DuplicateLoginId() throws Exception {
                // given
                MemberCreateDto createDto = MemberCreateDto.builder()
                                .loginId("existinguser")
                                .password("password123")
                                .name("새유저")
                                .birthYear(1995)
                                .build();

                given(memberService.createMember(any(MemberCreateDto.class)))
                                .willThrow(new DuplicateResourceException("이미 존재하는 로그인 ID입니다"));

                // when & then
                mockMvc.perform(post("/api/members")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(createDto)))
                                .andDo(print())
                                .andExpect(status().isConflict())
                                .andExpect(jsonPath("$.message").value("이미 존재하는 로그인 ID입니다"));
        }

        @Test
        @DisplayName("ID로 회원 조회 - 성공")
        void getMemberById_Success() throws Exception {
                // given
                Long memberId = 1L;
                given(memberService.getMemberById(memberId)).willReturn(testMemberDto);

                // when & then
                mockMvc.perform(get("/api/members/{id}", memberId))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.id").value(1))
                                .andExpected(jsonPath("$.loginId").value("testuser"))
                                .andExpect(jsonPath("$.name").value("테스트유저"));

                verify(memberService).getMemberById(memberId);
        }

        @Test
        @DisplayName("ID로 회원 조회 - 실패 (존재하지 않음)")
        void getMemberById_NotFound() throws Exception {
                // given
                Long memberId = 999L;
                given(memberService.getMemberById(memberId))
                                .willThrow(new ResourceNotFoundException("회원을 찾을 수 없습니다"));

                // when & then
                mockMvc.perform(get("/api/members/{id}", memberId))
                                .andDo(print())
                                .andExpect(status().isNotFound())
                                .andExpect(jsonPath("$.message").value("회원을 찾을 수 없습니다"));
        }

        @Test
        @DisplayName("로그인 ID로 회원 조회 - 성공")
        void getMemberByLoginId_Success() throws Exception {
                // given
                String loginId = "testuser";
                given(memberService.getMemberByLoginId(loginId)).willReturn(testMemberDto);

                // when & then
                mockMvc.perform(get("/api/members/login/{loginId}", loginId))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpected(jsonPath("$.loginId").value("testuser"))
                                .andExpect(jsonPath("$.name").value("테스트유저"));

                verify(memberService).getMemberByLoginId(loginId);
        }

        @Test
        @DisplayName("전체 회원 조회")
        void getAllMembers_Success() throws Exception {
                // given
                MemberSummaryDto member2 = MemberSummaryDto.builder()
                                .id(2L)
                                .loginId("user2")
                                .name("유저2")
                                .birthYear(1985)
                                .grade(MemberGrade.HATCHING_CHICK)
                                .build();

                List<MemberSummaryDto> members = Arrays.asList(testMemberDto, member2);
                given(memberService.getAllMembers()).willReturn(members);

                // when & then
                mockMvc.perform(get("/api/members"))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$").isArray())
                                .andExpect(jsonPath("$.length()").value(2))
                                .andExpect(jsonPath("$[0].loginId").value("testuser"))
                                .andExpect(jsonPath("$[1].loginId").value("user2"));

                verify(memberService).getAllMembers();
        }

        @Test
        @DisplayName("회원 정보 수정 - 성공")
        void updateMember_Success() throws Exception {
                // given
                Long memberId = 1L;
                MemberUpdateDto updateDto = MemberUpdateDto.builder()
                                .name("수정된이름")
                                .birthYear(1992)
                                .grade(MemberGrade.HATCHING_CHICK)
                                .build();

                MemberSummaryDto updatedMember = MemberSummaryDto.builder()
                                .id(memberId)
                                .loginId("testuser")
                                .name("수정된이름")
                                .birthYear(1992)
                                .grade(MemberGrade.HATCHING_CHICK)
                                .build();

                given(memberService.updateMember(eq(memberId), any(MemberUpdateDto.class)))
                                .willReturn(updatedMember);

                // when & then
                mockMvc.perform(put("/api/members/{id}", memberId)
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(updateDto)))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.name").value("수정된이름"))
                                .andExpect(jsonPath("$.birthYear").value(1992))
                                .andExpect(jsonPath("$.grade").value("HATCHING_CHICK"));

                verify(memberService).updateMember(eq(memberId), any(MemberUpdateDto.class));
        }

        @Test
        @DisplayName("회원 삭제 - 성공")
        void deleteMember_Success() throws Exception {
                // given
                Long memberId = 1L;
                willDoNothing().given(memberService).deleteMember(memberId);

                // when & then
                mockMvc.perform(delete("/api/members/{id}", memberId))
                                .andDo(print())
                                .andExpect(status().isNoContent());

                verify(memberService).deleteMember(memberId);
        }

        @Test
        @DisplayName("등급별 회원 조회")
        void getMembersByGrade_Success() throws Exception {
                // given
                MemberGrade grade = MemberGrade.EGG;
                List<MemberSummaryDto> members = Arrays.asList(testMemberDto);
                given(memberService.getMembersByGrade(grade)).willReturn(members);

                // when & then
                mockMvc.perform(get("/api/members/grade/{grade}", grade))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$").isArray())
                                .andExpect(jsonPath("$.length()").value(1))
                                .andExpect(jsonPath("$[0].grade").value("EGG"));

                verify(memberService).getMembersByGrade(grade);
        }

        @Test
        @DisplayName("이름으로 회원 검색")
        void searchMembersByName_Success() throws Exception {
                // given
                String searchTerm = "테스트";
                List<MemberSummaryDto> searchResults = Arrays.asList(testMemberDto);
                given(memberService.searchMembersByName(searchTerm)).willReturn(searchResults);

                // when & then
                mockMvc.perform(get("/api/members/search")
                                .param("name", searchTerm))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpected(jsonPath("$").isArray())
                                .andExpect(jsonPath("$.length()").value(1))
                                .andExpect(jsonPath("$[0].name").value("테스트유저"));

                verify(memberService).searchMembersByName(searchTerm);
        }

        @Test
        @DisplayName("관리자 회원 조회")
        void getAdminMembers_Success() throws Exception {
                // given
                MemberSummaryDto adminMember = MemberSummaryDto.builder()
                                .id(2L)
                                .loginId("admin")
                                .name("관리자")
                                .birthYear(1980)
                                .grade(MemberGrade.ROOSTER)
                                .build();

                List<MemberSummaryDto> admins = Arrays.asList(adminMember);
                given(memberService.getAdminMembers()).willReturn(admins);

                // when & then
                mockMvc.perform(get("/api/members/admins"))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$").isArray())
                                .andExpect(jsonPath("$.length()").value(1))
                                .andExpect(jsonPath("$[0].grade").value("ROOSTER"));

                verify(memberService).getAdminMembers();
        }

        @Test
        @DisplayName("로그인 검증")
        void validateLogin_Success() throws Exception {
                // given
                String loginId = "testuser";
                String password = "password123";
                given(memberService.validateLogin(loginId, password)).willReturn(true);

                // when & then
                mockMvc.perform(post("/api/members/login")
                                .param("loginId", loginId)
                                .param("password", password))
                                .andDo(print())
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.success").value(true));

                verify(memberService).validateLogin(loginId, password);
        }

        @Test
        @DisplayName("로그인 검증 - 실패")
        void validateLogin_Failed() throws Exception {
                // given
                String loginId = "testuser";
                String password = "wrongpassword";
                given(memberService.validateLogin(loginId, password)).willReturn(false);

                // when & then
                mockMvc.perform(post("/api/members/login")
                                .param("loginId", loginId)
                                .param("password", password))
                                .andDo(print())
                                .andExpect(status().isUnauthorized())
                                .andExpect(jsonPath("$.success").value(false));

                verify(memberService).validateLogin(loginId, password);
        }

        @Test
        @DisplayName("잘못된 경로 파라미터 - 숫자가 아닌 ID")
        void getMemberById_InvalidPathParameter() throws Exception {
                // when & then
                mockMvc.perform(get("/api/members/{id}", "invalid"))
                                .andDo(print())
                                .andExpect(status().isBadRequest());

                verify(memberService, never()).getMemberById(anyLong());
        }

        @Test
        @DisplayName("Content-Type 누락")
        void createMember_MissingContentType() throws Exception {
                // given
                MemberCreateDto createDto = MemberCreateDto.builder()
                                .loginId("newuser")
                                .password("password123")
                                .name("새유저")
                                .birthYear(1995)
                                .build();

                // when & then
                mockMvc.perform(post("/api/members")
                                .content(objectMapper.writeValueAsString(createDto)))
                                .andDo(print())
                                .andExpect(status().isUnsupportedMediaType());

                verify(memberService, never()).createMember(any());
        }

        @Test
        @DisplayName("JSON 파싱 오류")
        void createMember_InvalidJson() throws Exception {
                // when & then
                mockMvc.perform(post("/api/members")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("invalid json"))
                                .andDo(print())
                                .andExpect(status().isBadRequest());

                verify(memberService, never()).createMember(any());
        }
}