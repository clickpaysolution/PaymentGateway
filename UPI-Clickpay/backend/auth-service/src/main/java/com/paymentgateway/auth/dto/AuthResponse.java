package com.paymentgateway.auth.dto;

import com.paymentgateway.auth.entity.User;

public class AuthResponse {
    private String token;
    private String username;
    private String email;
    private User.Role role;
    private Long userId;

    public AuthResponse() {}

    public AuthResponse(String token, String username, String email, User.Role role, Long userId) {
        this.token = token;
        this.username = username;
        this.email = email;
        this.role = role;
        this.userId = userId;
    }

    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public User.Role getRole() { return role; }
    public void setRole(User.Role role) { this.role = role; }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
}