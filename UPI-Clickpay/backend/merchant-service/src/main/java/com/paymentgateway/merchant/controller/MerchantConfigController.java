package com.paymentgateway.merchant.controller;

import com.paymentgateway.common.dto.ApiResponse;
import com.paymentgateway.common.util.JwtUtil;
import com.paymentgateway.merchant.dto.MerchantConfigRequest;
import com.paymentgateway.merchant.entity.Merchant;
import com.paymentgateway.merchant.service.MerchantConfigService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/merchant/config")
@CrossOrigin(origins = "*")
public class MerchantConfigController {

    @Autowired
    private MerchantConfigService merchantConfigService;

    @Autowired
    private JwtUtil jwtUtil;

    @PostMapping("/update")
    public ResponseEntity<ApiResponse<String>> updateMerchantConfiguration(
            @Valid @RequestBody MerchantConfigRequest request,
            @RequestHeader("Authorization") String token) {
        try {
            String jwtToken = token.replace("Bearer ", "");
            Long merchantId = jwtUtil.extractUserId(jwtToken);

            // Validate bank configuration if switching to gateway mode
            if (request.getOperationMode() == Merchant.OperationMode.GATEWAY_ONLY && 
                request.getBankConfig() != null) {
                
                if (!merchantConfigService.validateBankConfiguration(request.getBankConfig())) {
                    return ResponseEntity.badRequest()
                        .body(ApiResponse.error("Invalid bank configuration"));
                }
            }

            merchantConfigService.updateMerchantConfiguration(merchantId, request);
            
            return ResponseEntity.ok(
                ApiResponse.success("Merchant configuration updated successfully")
            );
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(ApiResponse.error("Failed to update configuration: " + e.getMessage()));
        }
    }

    @GetMapping("/current")
    public ResponseEntity<ApiResponse<MerchantConfigRequest>> getCurrentConfiguration(
            @RequestHeader("Authorization") String token) {
        try {
            String jwtToken = token.replace("Bearer ", "");
            Long merchantId = jwtUtil.extractUserId(jwtToken);

            MerchantConfigRequest config = merchantConfigService.getMerchantConfiguration(merchantId);
            
            return ResponseEntity.ok(ApiResponse.success(config));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(ApiResponse.error("Failed to get configuration: " + e.getMessage()));
        }
    }

    @GetMapping("/fee-estimate")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getFeeEstimate(
            @RequestParam Merchant.OperationMode mode,
            @RequestParam BigDecimal monthlyVolume,
            @RequestParam BigDecimal avgTransactionSize) {
        try {
            Map<String, Object> estimate = merchantConfigService.calculateFeeEstimate(
                mode, monthlyVolume, avgTransactionSize
            );
            
            return ResponseEntity.ok(ApiResponse.success(estimate));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(ApiResponse.error("Failed to calculate estimate: " + e.getMessage()));
        }
    }

    @PostMapping("/validate-bank-config")
    public ResponseEntity<ApiResponse<Boolean>> validateBankConfiguration(
            @RequestBody MerchantConfigRequest.BankConfigDto bankConfig) {
        try {
            boolean isValid = merchantConfigService.validateBankConfiguration(bankConfig);
            
            return ResponseEntity.ok(ApiResponse.success(isValid));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(ApiResponse.error("Validation failed: " + e.getMessage()));
        }
    }

    @GetMapping("/modes")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getAvailableModes() {
        try {
            Map<String, Object> modes = Map.of(
                "GATEWAY_ONLY", Map.of(
                    "name", "Payment Gateway Only",
                    "description", "Use your own bank account and processor",
                    "setupFee", 0,
                    "monthlyFee", 2000,
                    "transactionFee", 2.00,
                    "percentageFee", 0.0
                ),
                "FULL_PROCESSOR", Map.of(
                    "name", "Full Payment Processor",
                    "description", "We handle everything including money movement",
                    "setupFee", 5000,
                    "monthlyFee", 1000,
                    "transactionFee", 2.00,
                    "percentageFee", 1.5
                ),
                "HYBRID", Map.of(
                    "name", "Hybrid Mode",
                    "description", "Flexible combination based on transaction size",
                    "setupFee", 2500,
                    "monthlyFee", 1500,
                    "transactionFee", 2.00,
                    "percentageFee", "Variable"
                )
            );
            
            return ResponseEntity.ok(ApiResponse.success(modes));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(ApiResponse.error("Failed to get modes: " + e.getMessage()));
        }
    }

    @GetMapping("/{merchantId}/info")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getMerchantInfo(
            @PathVariable Long merchantId) {
        try {
            Map<String, Object> merchantInfo = merchantConfigService.getMerchantInfo(merchantId);
            return ResponseEntity.ok(ApiResponse.success(merchantInfo));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(ApiResponse.error("Failed to get merchant info: " + e.getMessage()));
        }
    }
}