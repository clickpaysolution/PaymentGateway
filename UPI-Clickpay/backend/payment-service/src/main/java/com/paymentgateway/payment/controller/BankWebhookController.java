package com.paymentgateway.payment.controller;

import com.paymentgateway.common.dto.ApiResponse;
import com.paymentgateway.payment.service.WebhookService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/webhooks")
@CrossOrigin(origins = "*")
public class BankWebhookController {

    @Autowired
    private WebhookService webhookService;

    @PostMapping("/hdfc")
    public ResponseEntity<ApiResponse<String>> handleHdfcWebhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-HDFC-Signature", required = false) String signature) {
        
        try {
            boolean processed = webhookService.processHdfcWebhook(payload, signature);
            
            if (processed) {
                return ResponseEntity.ok(ApiResponse.success("Webhook processed successfully"));
            } else {
                return ResponseEntity.badRequest().body(ApiResponse.error("Failed to process webhook"));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Webhook processing error: " + e.getMessage()));
        }
    }

    @PostMapping("/icici")
    public ResponseEntity<ApiResponse<String>> handleIciciWebhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-ICICI-Signature", required = false) String signature) {
        
        try {
            boolean processed = webhookService.processIciciWebhook(payload, signature);
            
            if (processed) {
                return ResponseEntity.ok(ApiResponse.success("Webhook processed successfully"));
            } else {
                return ResponseEntity.badRequest().body(ApiResponse.error("Failed to process webhook"));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Webhook processing error: " + e.getMessage()));
        }
    }

    @PostMapping("/sbi")
    public ResponseEntity<ApiResponse<String>> handleSbiWebhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-SBI-Signature", required = false) String signature) {
        
        try {
            boolean processed = webhookService.processSbiWebhook(payload, signature);
            
            if (processed) {
                return ResponseEntity.ok(ApiResponse.success("Webhook processed successfully"));
            } else {
                return ResponseEntity.badRequest().body(ApiResponse.error("Failed to process webhook"));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Webhook processing error: " + e.getMessage()));
        }
    }

    @PostMapping("/axis")
    public ResponseEntity<ApiResponse<String>> handleAxisWebhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-AXIS-Signature", required = false) String signature) {
        
        try {
            boolean processed = webhookService.processAxisWebhook(payload, signature);
            
            if (processed) {
                return ResponseEntity.ok(ApiResponse.success("Webhook processed successfully"));
            } else {
                return ResponseEntity.badRequest().body(ApiResponse.error("Failed to process webhook"));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Webhook processing error: " + e.getMessage()));
        }
    }

    @PostMapping("/generic")
    public ResponseEntity<ApiResponse<String>> handleGenericWebhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-Bank-Name", required = false) String bankName,
            @RequestHeader(value = "X-Signature", required = false) String signature) {
        
        try {
            boolean processed = webhookService.processGenericWebhook(payload, bankName, signature);
            
            if (processed) {
                return ResponseEntity.ok(ApiResponse.success("Webhook processed successfully"));
            } else {
                return ResponseEntity.badRequest().body(ApiResponse.error("Failed to process webhook"));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Webhook processing error: " + e.getMessage()));
        }
    }

    @GetMapping("/test")
    public ResponseEntity<ApiResponse<String>> testWebhook() {
        return ResponseEntity.ok(ApiResponse.success("Webhook endpoint is working"));
    }
}