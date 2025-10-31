# Bank API Integration Guide

## Overview

This document explains how to integrate the payment gateway with bank APIs for real transaction processing, status tracking, and merchant account management.

## Integration Architecture

```
Merchant → Payment Gateway → Bank API → Bank Processing → Status Updates
    ↑                                                           ↓
    └─────────────── Webhook Callbacks ←─────────────────────────┘
```

## 1. Bank API Integration Flow

### Step 1: Payment Initiation
```
Customer → Payment Gateway → Bank API → Bank Processing
```

### Step 2: Status Updates
```
Bank → Webhook → Payment Gateway → Merchant Callback
```

### Step 3: Settlement
```
Bank → Settlement API → Merchant Account
```

## 2. Merchant Account Configuration

### Database Schema for Bank Details
```sql
-- Add to merchants table
ALTER TABLE merchants ADD COLUMN bank_account_number VARCHAR(20);
ALTER TABLE merchants ADD COLUMN bank_ifsc_code VARCHAR(11);
ALTER TABLE merchants ADD COLUMN bank_account_holder_name VARCHAR(100);
ALTER TABLE merchants ADD COLUMN bank_merchant_id VARCHAR(50);
ALTER TABLE merchants ADD COLUMN bank_api_key VARCHAR(255);
ALTER TABLE merchants ADD COLUMN settlement_account_id VARCHAR(50);
```

### Merchant Bank Configuration Entity
```java
@Entity
@Table(name = "merchant_bank_config")
public class MerchantBankConfig {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "merchant_id")
    private Long merchantId;
    
    @Column(name = "bank_name")
    private String bankName;
    
    @Column(name = "bank_merchant_id")
    private String bankMerchantId;
    
    @Column(name = "bank_api_key")
    private String bankApiKey;
    
    @Column(name = "account_number")
    private String accountNumber;
    
    @Column(name = "ifsc_code")
    private String ifscCode;
    
    @Column(name = "account_holder_name")
    private String accountHolderName;
    
    @Column(name = "settlement_account_id")
    private String settlementAccountId;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
    
    // Getters and setters...
}
```

## 3. Bank API Service Implementation

### Bank API Configuration
```yaml
# application.yml
bank:
  apis:
    hdfc:
      base-url: "https://api.hdfcbank.com/payments"
      merchant-id: "${HDFC_MERCHANT_ID}"
      api-key: "${HDFC_API_KEY}"
      webhook-secret: "${HDFC_WEBHOOK_SECRET}"
    
    icici:
      base-url: "https://api.icicibank.com/upi"
      merchant-id: "${ICICI_MERCHANT_ID}"
      api-key: "${ICICI_API_KEY}"
      webhook-secret: "${ICICI_WEBHOOK_SECRET}"
    
    sbi:
      base-url: "https://api.sbi.co.in/payments"
      merchant-id: "${SBI_MERCHANT_ID}"
      api-key: "${SBI_API_KEY}"
      webhook-secret: "${SBI_WEBHOOK_SECRET}"
```

### Bank API Service Interface
```java
public interface BankApiService {
    BankPaymentResponse initiatePayment(BankPaymentRequest request);
    BankStatusResponse getPaymentStatus(String bankTransactionId);
    BankRefundResponse initiateRefund(String bankTransactionId, BigDecimal amount);
    boolean validateWebhookSignature(String payload, String signature, String secret);
}
```

### HDFC Bank API Implementation
```java
@Service
@ConditionalOnProperty(name = "bank.provider", havingValue = "hdfc")
public class HdfcBankApiService implements BankApiService {
    
    @Value("${bank.apis.hdfc.base-url}")
    private String baseUrl;
    
    @Value("${bank.apis.hdfc.merchant-id}")
    private String merchantId;
    
    @Value("${bank.apis.hdfc.api-key}")
    private String apiKey;
    
    @Autowired
    private RestTemplate restTemplate;
    
    @Override
    public BankPaymentResponse initiatePayment(BankPaymentRequest request) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("Authorization", "Bearer " + apiKey);
            headers.set("X-Merchant-Id", merchantId);
            
            // HDFC API Request Format
            Map<String, Object> hdfcRequest = Map.of(
                "merchantTransactionId", request.getTransactionId(),
                "amount", request.getAmount().multiply(new BigDecimal("100")).intValue(), // Convert to paise
                "merchantUserId", request.getCustomerId(),
                "redirectUrl", request.getCallbackUrl(),
                "redirectMode", "POST",
                "callbackUrl", request.getWebhookUrl(),
                "mobileNumber", request.getMobileNumber(),
                "paymentInstrument", Map.of(
                    "type", "UPI_COLLECT",
                    "vpa", request.getUpiId()
                )
            );
            
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(hdfcRequest, headers);
            
            ResponseEntity<HdfcPaymentResponse> response = restTemplate.postForEntity(
                baseUrl + "/v1/pay", entity, HdfcPaymentResponse.class
            );
            
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                HdfcPaymentResponse hdfcResponse = response.getBody();
                
                return BankPaymentResponse.builder()
                    .success(hdfcResponse.isSuccess())
                    .bankTransactionId(hdfcResponse.getData().getMerchantTransactionId())
                    .bankReferenceId(hdfcResponse.getData().getTransactionId())
                    .paymentUrl(hdfcResponse.getData().getInstrumentResponse().getRedirectInfo().getUrl())
                    .status(mapHdfcStatus(hdfcResponse.getCode()))
                    .message(hdfcResponse.getMessage())
                    .build();
            }
            
            throw new BankApiException("Failed to initiate payment with HDFC");
            
        } catch (Exception e) {
            log.error("Error initiating HDFC payment", e);
            throw new BankApiException("HDFC API error: " + e.getMessage());
        }
    }
    
    @Override
    public BankStatusResponse getPaymentStatus(String bankTransactionId) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "Bearer " + apiKey);
            headers.set("X-Merchant-Id", merchantId);
            
            HttpEntity<Void> entity = new HttpEntity<>(headers);
            
            ResponseEntity<HdfcStatusResponse> response = restTemplate.exchange(
                baseUrl + "/v1/status/" + merchantId + "/" + bankTransactionId,
                HttpMethod.GET, entity, HdfcStatusResponse.class
            );
            
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                HdfcStatusResponse hdfcResponse = response.getBody();
                
                return BankStatusResponse.builder()
                    .bankTransactionId(bankTransactionId)
                    .status(mapHdfcStatus(hdfcResponse.getCode()))
                    .bankReferenceId(hdfcResponse.getData().getTransactionId())
                    .amount(new BigDecimal(hdfcResponse.getData().getAmount()).divide(new BigDecimal("100")))
                    .responseCode(hdfcResponse.getCode())
                    .responseMessage(hdfcResponse.getMessage())
                    .build();
            }
            
            throw new BankApiException("Failed to get status from HDFC");
            
        } catch (Exception e) {
            log.error("Error getting HDFC payment status", e);
            throw new BankApiException("HDFC status API error: " + e.getMessage());
        }
    }
    
    private PaymentStatus mapHdfcStatus(String hdfcCode) {
        return switch (hdfcCode) {
            case "PAYMENT_SUCCESS" -> PaymentStatus.SUCCESS;
            case "PAYMENT_ERROR", "PAYMENT_DECLINED" -> PaymentStatus.FAILED;
            case "PAYMENT_PENDING", "PAYMENT_INITIATED" -> PaymentStatus.PENDING;
            default -> PaymentStatus.PENDING;
        };
    }
}
```

## 4. Enhanced Payment Service with Bank Integration

```java
@Service
public class EnhancedPaymentService {
    
    @Autowired
    private BankApiService bankApiService;
    
    @Autowired
    private MerchantBankConfigRepository merchantBankConfigRepository;
    
    @Autowired
    private PaymentRepository paymentRepository;
    
    @Autowired
    private WebhookService webhookService;
    
    public PaymentResponse createPaymentWithBankIntegration(Long merchantId, PaymentRequest request) {
        // 1. Get merchant bank configuration
        MerchantBankConfig bankConfig = merchantBankConfigRepository.findByMerchantId(merchantId)
            .orElseThrow(() -> new RuntimeException("Merchant bank configuration not found"));
        
        // 2. Create payment record
        Payment payment = createPaymentRecord(merchantId, request);
        
        // 3. Prepare bank API request
        BankPaymentRequest bankRequest = BankPaymentRequest.builder()
            .transactionId(payment.getTransactionId())
            .amount(payment.getAmount())
            .customerId("CUST_" + merchantId)
            .upiId(request.getUpiId())
            .mobileNumber(extractMobileFromUPI(request.getUpiId()))
            .callbackUrl(request.getCallbackUrl())
            .webhookUrl(buildWebhookUrl(payment.getTransactionId()))
            .merchantBankId(bankConfig.getBankMerchantId())
            .build();
        
        try {
            // 4. Call bank API
            BankPaymentResponse bankResponse = bankApiService.initiatePayment(bankRequest);
            
            // 5. Update payment with bank details
            payment.setBankReference(bankResponse.getBankReferenceId());
            payment.setBankTransactionId(bankResponse.getBankTransactionId());
            payment.setStatus(bankResponse.getStatus());
            
            if (bankResponse.getPaymentUrl() != null) {
                payment.setPaymentUrl(bankResponse.getPaymentUrl());
            }
            
            payment = paymentRepository.save(payment);
            
            // 6. Return response
            PaymentResponse response = new PaymentResponse(payment);
            response.setPaymentUrl(bankResponse.getPaymentUrl());
            
            return response;
            
        } catch (BankApiException e) {
            // Handle bank API errors
            payment.setStatus(PaymentStatus.FAILED);
            payment.setErrorMessage(e.getMessage());
            paymentRepository.save(payment);
            
            throw new PaymentProcessingException("Bank API error: " + e.getMessage());
        }
    }
    
    @Scheduled(fixedRate = 30000) // Check every 30 seconds
    public void checkPendingPaymentStatus() {
        List<Payment> pendingPayments = paymentRepository.findByStatusAndCreatedAtAfter(
            PaymentStatus.PENDING, 
            LocalDateTime.now().minusHours(24) // Check payments from last 24 hours
        );
        
        for (Payment payment : pendingPayments) {
            try {
                BankStatusResponse statusResponse = bankApiService.getPaymentStatus(
                    payment.getBankTransactionId()
                );
                
                if (statusResponse.getStatus() != payment.getStatus()) {
                    updatePaymentStatus(payment, statusResponse);
                }
                
            } catch (Exception e) {
                log.error("Error checking payment status for: " + payment.getTransactionId(), e);
            }
        }
    }
    
    private void updatePaymentStatus(Payment payment, BankStatusResponse statusResponse) {
        payment.setStatus(statusResponse.getStatus());
        payment.setBankReference(statusResponse.getBankReferenceId());
        
        if (statusResponse.getStatus() == PaymentStatus.SUCCESS || 
            statusResponse.getStatus() == PaymentStatus.FAILED) {
            payment.setCompletedAt(LocalDateTime.now());
        }
        
        payment = paymentRepository.save(payment);
        
        // Send webhook to merchant
        webhookService.sendPaymentStatusWebhook(payment);
    }
}
```

## 5. Webhook Handling for Bank Callbacks

```java
@RestController
@RequestMapping("/api/webhooks")
public class BankWebhookController {
    
    @Autowired
    private PaymentService paymentService;
    
    @Autowired
    private BankApiService bankApiService;
    
    @PostMapping("/hdfc")
    public ResponseEntity<String> handleHdfcWebhook(
            @RequestBody String payload,
            @RequestHeader("X-HDFC-Signature") String signature) {
        
        try {
            // 1. Validate webhook signature
            if (!bankApiService.validateWebhookSignature(payload, signature, hdfcWebhookSecret)) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid signature");
            }
            
            // 2. Parse webhook payload
            HdfcWebhookPayload webhookData = objectMapper.readValue(payload, HdfcWebhookPayload.class);
            
            // 3. Update payment status
            Payment payment = paymentRepository.findByBankTransactionId(
                webhookData.getData().getMerchantTransactionId()
            ).orElseThrow(() -> new RuntimeException("Payment not found"));
            
            PaymentStatus newStatus = mapHdfcStatus(webhookData.getCode());
            
            if (newStatus != payment.getStatus()) {
                payment.setStatus(newStatus);
                payment.setBankReference(webhookData.getData().getTransactionId());
                
                if (newStatus == PaymentStatus.SUCCESS || newStatus == PaymentStatus.FAILED) {
                    payment.setCompletedAt(LocalDateTime.now());
                }
                
                paymentRepository.save(payment);
                
                // 4. Send webhook to merchant
                webhookService.sendPaymentStatusWebhook(payment);
            }
            
            return ResponseEntity.ok("Webhook processed successfully");
            
        } catch (Exception e) {
            log.error("Error processing HDFC webhook", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Webhook processing failed");
        }
    }
}
```

## 6. Merchant Webhook Service

```java
@Service
public class WebhookService {
    
    @Autowired
    private RestTemplate restTemplate;
    
    @Autowired
    private MerchantRepository merchantRepository;
    
    public void sendPaymentStatusWebhook(Payment payment) {
        Merchant merchant = merchantRepository.findByUserId(payment.getMerchantId())
            .orElse(null);
        
        if (merchant == null || merchant.getWebhookUrl() == null) {
            return;
        }
        
        try {
            WebhookPayload webhookPayload = WebhookPayload.builder()
                .transactionId(payment.getTransactionId())
                .status(payment.getStatus().name())
                .amount(payment.getAmount())
                .bankReference(payment.getBankReference())
                .timestamp(LocalDateTime.now())
                .signature(generateWebhookSignature(payment, merchant.getApiKey()))
                .build();
            
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("X-Webhook-Signature", webhookPayload.getSignature());
            
            HttpEntity<WebhookPayload> entity = new HttpEntity<>(webhookPayload, headers);
            
            ResponseEntity<String> response = restTemplate.postForEntity(
                merchant.getWebhookUrl(), entity, String.class
            );
            
            log.info("Webhook sent successfully for transaction: " + payment.getTransactionId());
            
        } catch (Exception e) {
            log.error("Failed to send webhook for transaction: " + payment.getTransactionId(), e);
            // Implement retry mechanism here
        }
    }
    
    private String generateWebhookSignature(Payment payment, String apiKey) {
        String data = payment.getTransactionId() + payment.getStatus() + payment.getAmount() + apiKey;
        return DigestUtils.sha256Hex(data);
    }
}
```

## 7. Bank Configuration Management

### Admin API for Bank Configuration
```java
@RestController
@RequestMapping("/api/admin/bank-config")
public class BankConfigController {
    
    @PostMapping("/merchant/{merchantId}")
    public ResponseEntity<ApiResponse<MerchantBankConfig>> configureMerchantBank(
            @PathVariable Long merchantId,
            @RequestBody BankConfigRequest request) {
        
        MerchantBankConfig config = new MerchantBankConfig();
        config.setMerchantId(merchantId);
        config.setBankName(request.getBankName());
        config.setAccountNumber(encryptSensitiveData(request.getAccountNumber()));
        config.setIfscCode(request.getIfscCode());
        config.setAccountHolderName(request.getAccountHolderName());
        config.setBankMerchantId(request.getBankMerchantId());
        config.setBankApiKey(encryptSensitiveData(request.getBankApiKey()));
        
        config = merchantBankConfigRepository.save(config);
        
        return ResponseEntity.ok(ApiResponse.success("Bank configuration saved", config));
    }
}
```

## 8. Settlement and Reconciliation

### Settlement Service
```java
@Service
public class SettlementService {
    
    @Scheduled(cron = "0 0 2 * * ?") // Daily at 2 AM
    public void processSettlements() {
        LocalDate yesterday = LocalDate.now().minusDays(1);
        
        List<Payment> successfulPayments = paymentRepository.findSuccessfulPaymentsByDate(yesterday);
        
        Map<Long, List<Payment>> paymentsByMerchant = successfulPayments.stream()
            .collect(Collectors.groupingBy(Payment::getMerchantId));
        
        for (Map.Entry<Long, List<Payment>> entry : paymentsByMerchant.entrySet()) {
            processMerchantSettlement(entry.getKey(), entry.getValue(), yesterday);
        }
    }
    
    private void processMerchantSettlement(Long merchantId, List<Payment> payments, LocalDate settlementDate) {
        BigDecimal totalAmount = payments.stream()
            .map(Payment::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        // Calculate fees (example: 2% + ₹2 per transaction)
        BigDecimal feePercentage = new BigDecimal("0.02");
        BigDecimal fixedFee = new BigDecimal("2.00");
        BigDecimal totalFees = totalAmount.multiply(feePercentage)
            .add(fixedFee.multiply(new BigDecimal(payments.size())));
        
        BigDecimal settlementAmount = totalAmount.subtract(totalFees);
        
        // Create settlement record
        Settlement settlement = new Settlement();
        settlement.setMerchantId(merchantId);
        settlement.setSettlementDate(settlementDate);
        settlement.setTotalAmount(totalAmount);
        settlement.setFeeAmount(totalFees);
        settlement.setSettlementAmount(settlementAmount);
        settlement.setTransactionCount(payments.size());
        settlement.setStatus(SettlementStatus.PENDING);
        
        settlementRepository.save(settlement);
        
        // Initiate bank transfer
        initiateBankTransfer(settlement);
    }
}
```

## 9. Integration Checklist

### Pre-Integration Setup
- [ ] Obtain bank API credentials (Merchant ID, API Key, Webhook Secret)
- [ ] Set up merchant bank account details
- [ ] Configure webhook URLs with banks
- [ ] Set up SSL certificates for webhook endpoints
- [ ] Implement signature validation for webhooks

### Testing
- [ ] Test payment initiation with small amounts
- [ ] Verify webhook delivery and processing
- [ ] Test status polling mechanism
- [ ] Validate settlement calculations
- [ ] Test error handling scenarios

### Production Deployment
- [ ] Configure production bank API endpoints
- [ ] Set up monitoring and alerting
- [ ] Implement retry mechanisms for failed API calls
- [ ] Set up logging for audit trails
- [ ] Configure rate limiting for bank API calls

## 10. Security Considerations

### API Security
- Use HTTPS for all bank API communications
- Implement request signing with HMAC
- Validate webhook signatures
- Encrypt sensitive data at rest
- Use secure key management

### Data Protection
- PCI DSS compliance for card data (if applicable)
- Encrypt bank account details
- Implement data retention policies
- Regular security audits

## 11. Error Handling and Retry Mechanisms

### Bank API Error Handling
```java
@Component
public class BankApiErrorHandler {
    
    private static final int MAX_RETRY_ATTEMPTS = 3;
    private static final long RETRY_DELAY_MS = 1000;
    
    @Retryable(value = {BankApiException.class}, maxAttempts = MAX_RETRY_ATTEMPTS, 
               backoff = @Backoff(delay = RETRY_DELAY_MS, multiplier = 2))
    public BankPaymentResponse callBankApiWithRetry(BankPaymentRequest request) {
        try {
            return bankApiService.initiatePayment(request);
        } catch (HttpServerErrorException e) {
            log.warn("Bank API server error, retrying... Attempt: {}", getCurrentAttempt());
            throw new BankApiException("Bank API server error: " + e.getMessage());
        } catch (HttpClientErrorException e) {
            log.error("Bank API client error, not retrying: {}", e.getMessage());
            throw new BankApiException("Bank API client error: " + e.getMessage());
        }
    }
    
    @Recover
    public BankPaymentResponse recover(BankApiException ex, BankPaymentRequest request) {
        log.error("All retry attempts failed for transaction: {}", request.getTransactionId());
        return BankPaymentResponse.builder()
            .success(false)
            .status(PaymentStatus.FAILED)
            .message("Bank API unavailable after retries")
            .build();
    }
}
```

### Circuit Breaker Pattern
```java
@Component
public class BankApiCircuitBreaker {
    
    @CircuitBreaker(name = "bankApi", fallbackMethod = "fallbackPayment")
    @TimeLimiter(name = "bankApi")
    public CompletableFuture<BankPaymentResponse> initiatePaymentWithCircuitBreaker(
            BankPaymentRequest request) {
        return CompletableFuture.supplyAsync(() -> bankApiService.initiatePayment(request));
    }
    
    public CompletableFuture<BankPaymentResponse> fallbackPayment(
            BankPaymentRequest request, Exception ex) {
        log.error("Circuit breaker activated for bank API", ex);
        return CompletableFuture.completedFuture(
            BankPaymentResponse.builder()
                .success(false)
                .status(PaymentStatus.FAILED)
                .message("Bank service temporarily unavailable")
                .build()
        );
    }
}
```

## 12. Multi-Bank Support Implementation

### Bank Provider Factory
```java
@Component
public class BankApiFactory {
    
    private final Map<String, BankApiService> bankServices;
    
    public BankApiFactory(List<BankApiService> services) {
        this.bankServices = services.stream()
            .collect(Collectors.toMap(
                service -> service.getBankName().toLowerCase(),
                service -> service
            ));
    }
    
    public BankApiService getBankService(String bankName) {
        BankApiService service = bankServices.get(bankName.toLowerCase());
        if (service == null) {
            throw new UnsupportedBankException("Bank not supported: " + bankName);
        }
        return service;
    }
    
    public List<String> getSupportedBanks() {
        return new ArrayList<>(bankServices.keySet());
    }
}
```

### Enhanced Payment Service with Multi-Bank Support
```java
@Service
public class MultiBankPaymentService {
    
    @Autowired
    private BankApiFactory bankApiFactory;
    
    @Autowired
    private MerchantBankConfigRepository merchantBankConfigRepository;
    
    public PaymentResponse createPaymentWithPreferredBank(Long merchantId, PaymentRequest request) {
        // Get merchant's preferred banks in order
        List<MerchantBankConfig> bankConfigs = merchantBankConfigRepository
            .findByMerchantIdAndIsActiveOrderByPriority(merchantId, true);
        
        if (bankConfigs.isEmpty()) {
            throw new RuntimeException("No active bank configuration found for merchant");
        }
        
        // Try banks in order of preference
        for (MerchantBankConfig config : bankConfigs) {
            try {
                BankApiService bankService = bankApiFactory.getBankService(config.getBankName());
                return processPaymentWithBank(merchantId, request, config, bankService);
                
            } catch (BankApiException e) {
                log.warn("Failed to process payment with {}: {}", config.getBankName(), e.getMessage());
                // Continue to next bank
            }
        }
        
        throw new PaymentProcessingException("All configured banks failed to process payment");
    }
    
    private PaymentResponse processPaymentWithBank(Long merchantId, PaymentRequest request, 
            MerchantBankConfig config, BankApiService bankService) {
        
        Payment payment = createPaymentRecord(merchantId, request);
        payment.setBankProvider(config.getBankName());
        
        BankPaymentRequest bankRequest = buildBankRequest(payment, config, request);
        BankPaymentResponse bankResponse = bankService.initiatePayment(bankRequest);
        
        updatePaymentWithBankResponse(payment, bankResponse);
        
        return new PaymentResponse(payment);
    }
}
```

## 13. Real-time Status Updates with WebSockets

### WebSocket Configuration
```java
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
    
    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(new PaymentStatusWebSocketHandler(), "/ws/payment-status")
                .setAllowedOrigins("*");
    }
}

@Component
public class PaymentStatusWebSocketHandler extends TextWebSocketHandler {
    
    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    
    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        String transactionId = getTransactionIdFromSession(session);
        sessions.put(transactionId, session);
        log.info("WebSocket connection established for transaction: {}", transactionId);
    }
    
    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        String transactionId = getTransactionIdFromSession(session);
        sessions.remove(transactionId);
        log.info("WebSocket connection closed for transaction: {}", transactionId);
    }
    
    public void sendStatusUpdate(String transactionId, PaymentStatus status) {
        WebSocketSession session = sessions.get(transactionId);
        if (session != null && session.isOpen()) {
            try {
                PaymentStatusUpdate update = new PaymentStatusUpdate(transactionId, status, LocalDateTime.now());
                session.sendMessage(new TextMessage(objectMapper.writeValueAsString(update)));
            } catch (Exception e) {
                log.error("Failed to send WebSocket update", e);
            }
        }
    }
}
```

## 14. Advanced Fraud Detection

### Fraud Detection Service
```java
@Service
public class FraudDetectionService {
    
    @Autowired
    private PaymentRepository paymentRepository;
    
    public FraudCheckResult checkForFraud(PaymentRequest request, Long merchantId) {
        List<FraudRule> violations = new ArrayList<>();
        
        // Check for duplicate transactions
        if (isDuplicateTransaction(request, merchantId)) {
            violations.add(new FraudRule("DUPLICATE_TRANSACTION", "Duplicate transaction detected"));
        }
        
        // Check for velocity limits
        if (exceedsVelocityLimits(request, merchantId)) {
            violations.add(new FraudRule("VELOCITY_LIMIT", "Transaction velocity limit exceeded"));
        }
        
        // Check for suspicious amounts
        if (isSuspiciousAmount(request.getAmount())) {
            violations.add(new FraudRule("SUSPICIOUS_AMOUNT", "Suspicious transaction amount"));
        }
        
        // Check merchant risk score
        if (isHighRiskMerchant(merchantId)) {
            violations.add(new FraudRule("HIGH_RISK_MERCHANT", "High risk merchant"));
        }
        
        FraudCheckResult result = new FraudCheckResult();
        result.setViolations(violations);
        result.setRiskScore(calculateRiskScore(violations));
        result.setAction(determineAction(result.getRiskScore()));
        
        return result;
    }
    
    private boolean isDuplicateTransaction(PaymentRequest request, Long merchantId) {
        return paymentRepository.existsByMerchantIdAndAmountAndCreatedAtAfter(
            merchantId, 
            request.getAmount(), 
            LocalDateTime.now().minusMinutes(5)
        );
    }
    
    private boolean exceedsVelocityLimits(PaymentRequest request, Long merchantId) {
        // Check transactions in last hour
        List<Payment> recentPayments = paymentRepository.findByMerchantIdAndCreatedAtAfter(
            merchantId, LocalDateTime.now().minusHours(1)
        );
        
        BigDecimal totalAmount = recentPayments.stream()
            .map(Payment::getAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        return totalAmount.compareTo(new BigDecimal("100000")) > 0 || // ₹1 Lakh per hour
               recentPayments.size() > 50; // 50 transactions per hour
    }
}
```

## 15. Monitoring and Alerts

### Metrics Collection
```java
@Component
public class PaymentMetricsCollector {
    
    private final MeterRegistry meterRegistry;
    private final Counter successfulPayments;
    private final Counter failedPayments;
    private final Timer paymentProcessingTime;
    
    public PaymentMetricsCollector(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        this.successfulPayments = Counter.builder("payments.successful")
            .description("Number of successful payments")
            .register(meterRegistry);
        this.failedPayments = Counter.builder("payments.failed")
            .description("Number of failed payments")
            .register(meterRegistry);
        this.paymentProcessingTime = Timer.builder("payments.processing.time")
            .description("Payment processing time")
            .register(meterRegistry);
    }
    
    public void recordSuccessfulPayment(String bankName) {
        successfulPayments.increment(Tags.of("bank", bankName));
    }
    
    public void recordFailedPayment(String bankName, String errorCode) {
        failedPayments.increment(Tags.of("bank", bankName, "error", errorCode));
    }
    
    public Timer.Sample startTimer() {
        return Timer.start(meterRegistry);
    }
}
```

### Health Checks
```java
@Component
public class BankApiHealthIndicator implements HealthIndicator {
    
    @Autowired
    private BankApiFactory bankApiFactory;
    
    @Override
    public Health health() {
        Health.Builder builder = new Health.Builder();
        
        for (String bankName : bankApiFactory.getSupportedBanks()) {
            try {
                BankApiService service = bankApiFactory.getBankService(bankName);
                boolean isHealthy = service.healthCheck();
                
                if (isHealthy) {
                    builder.withDetail(bankName, "UP");
                } else {
                    builder.withDetail(bankName, "DOWN");
                    builder.down();
                }
            } catch (Exception e) {
                builder.withDetail(bankName, "ERROR: " + e.getMessage());
                builder.down();
            }
        }
        
        return builder.build();
    }
}
```

### Key Metrics to Monitor
- Payment success rates by bank
- API response times
- Webhook delivery success rates
- Settlement accuracy
- Failed transaction patterns
- Fraud detection rates
- System availability

### Alert Conditions
- Bank API downtime
- High failure rates (>5%)
- Webhook delivery failures
- Settlement discrepancies
- Unusual transaction patterns
- Fraud detection triggers
- System performance degradation

## 16. Compliance and Audit

### Audit Trail Service
```java
@Service
public class AuditService {
    
    @Autowired
    private AuditLogRepository auditLogRepository;
    
    @EventListener
    public void handlePaymentEvent(PaymentEvent event) {
        AuditLog auditLog = new AuditLog();
        auditLog.setTransactionId(event.getTransactionId());
        auditLog.setEventType(event.getType());
        auditLog.setEventData(event.getData());
        auditLog.setUserId(event.getUserId());
        auditLog.setTimestamp(LocalDateTime.now());
        auditLog.setIpAddress(event.getIpAddress());
        
        auditLogRepository.save(auditLog);
    }
}
```

### Compliance Checks
- PCI DSS compliance for card data
- RBI guidelines for payment aggregators
- Data localization requirements
- KYC/AML compliance
- Regular security audits

This comprehensive integration guide provides a complete framework for connecting your payment gateway with bank APIs, handling real transactions, managing multi-bank scenarios, implementing fraud detection, and ensuring compliance with regulatory requirements.