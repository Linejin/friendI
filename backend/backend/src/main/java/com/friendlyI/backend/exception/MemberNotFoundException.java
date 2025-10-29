package com.friendlyI.backend.exception;

/**
 * 회원 관련 예외
 */
public class MemberNotFoundException extends RuntimeException {
    public MemberNotFoundException(String message) {
        super(message);
    }

    public MemberNotFoundException(Long memberId) {
        super("존재하지 않는 회원입니다. ID: " + memberId);
    }

    public MemberNotFoundException(String field, String value) {
        super(String.format("회원을 찾을 수 없습니다. %s: %s", field, value));
    }
}