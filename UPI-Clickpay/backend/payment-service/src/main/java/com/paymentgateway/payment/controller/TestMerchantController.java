package com.paymentgateway.payment.controller;

import com.paymentgateway.common.dto.ApiResponse;
import com.paymentgateway.payment.dto.PaymentRequest;
import com.paymentgateway.payment.dto.PaymentResponse;
import com.paymentgateway.payment.service.PaymentService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/test-merchant")
@CrossOrigin(origins = "*")
public class TestMerchantController {

    @Autowired
    private PaymentService paymentService;

    // Test merchant ID (in real scenario, this would be extracted from API key)
    private static final Long TEST_MERCHANT_ID = 2L; // Assuming testmerchant user has ID 2

    @PostMapping("/create-payment")
    public ResponseEntity<ApiResponse<PaymentResponse>> createTestPayment(
            @Valid @RequestBody PaymentRequest request,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        try {
            // For demo purposes, we'll use a fixed test merchant ID
            // In production, you would validate the API key and extract merchant ID
            
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                return ResponseEntity.badRequest().body(ApiResponse.error("Missing or invalid API key"));
            }
            
            String apiKey = authHeader.replace("Bearer ", "");
            
            // Simple API key validation for demo (in production, validate against database)
            if (!"test_api_key_123".equals(apiKey)) {
                return ResponseEntity.badRequest().body(ApiResponse.error("Invalid API key"));
            }
            
            PaymentResponse response = paymentService.createPayment(TEST_MERCHANT_ID, request);
            return ResponseEntity.ok(ApiResponse.success("Payment created successfully", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @GetMapping("/payment-status/{transactionId}")
    public ResponseEntity<ApiResponse<PaymentResponse>> getTestPaymentStatus(
            @PathVariable String transactionId,
            @RequestHeader(value = "Authorization", required = false) String authHeader) {
        try {
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                return ResponseEntity.badRequest().body(ApiResponse.error("Missing or invalid API key"));
            }
            
            String apiKey = authHeader.replace("Bearer ", "");
            
            if (!"test_api_key_123".equals(apiKey)) {
                return ResponseEntity.badRequest().body(ApiResponse.error("Invalid API key"));
            }
            
            PaymentResponse response = paymentService.getPaymentStatus(transactionId);
            return ResponseEntity.ok(ApiResponse.success(response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }
}