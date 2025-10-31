package com.paymentgateway.payment.controller;

import com.paymentgateway.common.dto.ApiResponse;
import com.paymentgateway.common.util.JwtUtil;
import com.paymentgateway.payment.dto.PaymentRequest;
import com.paymentgateway.payment.dto.PaymentResponse;
import com.paymentgateway.payment.entity.Payment;
import com.paymentgateway.payment.service.PaymentService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/payments")
@CrossOrigin(origins = "*")
public class PaymentController {

    @Autowired
    private PaymentService paymentService;

    @Autowired
    private JwtUtil jwtUtil;

    @PostMapping("/create")
    public ResponseEntity<ApiResponse<PaymentResponse>> createPayment(
            @Valid @RequestBody PaymentRequest request,
            @RequestHeader("Authorization") String token) {
        try {
            String jwtToken = token.replace("Bearer ", "");
            Long merchantId = jwtUtil.extractUserId(jwtToken);
            
            PaymentResponse response = paymentService.createPayment(merchantId, request);
            return ResponseEntity.ok(ApiResponse.success("Payment created successfully", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @GetMapping("/status/{transactionId}")
    public ResponseEntity<ApiResponse<PaymentResponse>> getPaymentStatus(@PathVariable String transactionId) {
        try {
            PaymentResponse response = paymentService.getPaymentStatus(transactionId);
            return ResponseEntity.ok(ApiResponse.success(response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @PostMapping("/webhook/upi")
    public ResponseEntity<ApiResponse<PaymentResponse>> handleUPIWebhook(
            @RequestParam String transactionId,
            @RequestParam String status,
            @RequestParam(required = false) String bankReference) {
        try {
            Payment.PaymentStatus paymentStatus = Payment.PaymentStatus.valueOf(status.toUpperCase());
            PaymentResponse response = paymentService.updatePaymentStatus(transactionId, paymentStatus, bankReference);
            return ResponseEntity.ok(ApiResponse.success("Payment status updated", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @GetMapping("/page")
    public ResponseEntity<String> getPaymentPage(@RequestParam String transactionId) {
        // This would return the payment page HTML
        // For now, return a simple response
        return ResponseEntity.ok(generatePaymentPageHTML(transactionId));
    }

    private String generatePaymentPageHTML(String transactionId) {
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Payment Gateway</title>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                    .container { max-width: 400px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                    .upi-option { padding: 15px; margin: 10px 0; border: 1px solid #ddd; border-radius: 5px; cursor: pointer; text-align: center; }
                    .upi-option:hover { background: #f0f0f0; }
                    .qr-code { text-align: center; margin: 20px 0; }
                    .amount { font-size: 24px; font-weight: bold; color: #333; text-align: center; margin: 20px 0; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h2>Complete Your Payment</h2>
                    <div class="amount">₹ 100.00</div>
                    <div class="upi-option" onclick="openUPIApp('phonepe')">📱 PhonePe</div>
                    <div class="upi-option" onclick="openUPIApp('googlepay')">💳 Google Pay</div>
                    <div class="upi-option" onclick="openUPIApp('paytm')">💰 Paytm</div>
                    <div class="qr-code">
                        <p>Or scan QR code with any UPI app</p>
                        <div style="width: 200px; height: 200px; background: #f0f0f0; margin: 0 auto; display: flex; align-items: center; justify-content: center;">
                            QR Code Here
                        </div>
                    </div>
                </div>
                <script>
                    function openUPIApp(provider) {
                        const upiUrl = 'upi://pay?pa=merchant@upi&am=100.00&tr=""" + transactionId + """&tn=Payment&cu=INR';
                        window.location.href = upiUrl;
                    }
                </script>
            </body>
            </html>
            """;
    }
}