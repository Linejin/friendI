package com.friendlyI.backend.config.security;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target({ ElementType.METHOD, ElementType.TYPE })
@Retention(RetentionPolicy.RUNTIME)
public @interface RequireAuth {
    /**
     * 필요한 최소 권한 레벨
     */
    String[] roles() default {};

    /**
     * 관리자 권한이 필요한지 여부
     */
    boolean adminOnly() default false;
}