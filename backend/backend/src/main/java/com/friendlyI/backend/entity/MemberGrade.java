package com.friendlyI.backend.entity;

/**
 * 회원 등급을 나타내는 Enum
 * 🥚 -> 🐣 -> 🐥 -> 🐤 -> 🐔 (관리자)
 */
public enum MemberGrade {
    EGG("🥚", "알", 1),
    HATCHING("🐣", "부화중", 2),
    CHICK("🐥", "병아리", 3),
    YOUNG_BIRD("🐤", "어린새", 4),
    ROOSTER("🐔", "관리자", 5);
    
    private final String emoji;
    private final String description;
    private final int level;
    
    MemberGrade(String emoji, String description, int level) {
        this.emoji = emoji;
        this.description = description;
        this.level = level;
    }
    
    public String getEmoji() {
        return emoji;
    }
    
    public String getDescription() {
        return description;
    }
    
    public int getLevel() {
        return level;
    }
    
    public boolean isAdmin() {
        return this == ROOSTER;
    }
}
