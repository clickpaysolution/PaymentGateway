package com.paymentgateway.auth.service;

import com.paymentgateway.auth.dto.AuthResponse;
import com.paymentgateway.auth.dto.LoginRequest;
import com.paymentgateway.auth.dto.SignupRequest;
import com.paymentgateway.auth.entity.User;
import com.paymentgateway.auth.repository.UserRepository;
import com.paymentgateway.common.util.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    public AuthResponse signup(SignupRequest request) {
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new RuntimeException("Username already exists");
        }
        
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already exists");
        }

        User user = new User(
            request.getUsername(),
            request.getEmail(),
            passwordEncoder.encode(request.getPassword()),
            request.getRole()
        );

        user = userRepository.save(user);

        String token = jwtUtil.generateToken(user.getUsername(), user.getRole().name(), user.getId());

        return new AuthResponse(token, user.getUsername(), user.getEmail(), user.getRole(), user.getId());
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByUsername(request.getUsername())
            .orElseThrow(() -> new RuntimeException("Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new RuntimeException("Invalid credentials");
        }

        if (!user.getIsActive()) {
            throw new RuntimeException("Account is deactivated");
        }

        String token = jwtUtil.generateToken(user.getUsername(), user.getRole().name(), user.getId());

        return new AuthResponse(token, user.getUsername(), user.getEmail(), user.getRole(), user.getId());
    }

    public boolean validateToken(String token) {
        try {
            String username = jwtUtil.extractUsername(token);
            User user = userRepository.findByUsername(username).orElse(null);
            return user != null && jwtUtil.validateToken(token, username);
        } catch (Exception e) {
            return false;
        }
    }
}