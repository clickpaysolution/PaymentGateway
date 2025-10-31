package com.paymentgateway.payment.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "payments")
public class Payment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "merchant_id", nullable = false)
    private Long merchantId;

    @Column(name = "transaction_id", unique = true, nullable = false)
    private String transactionId;

    @Column(name = "amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(name = "currency", nullable = false)
    private String currency = "INR";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private PaymentStatus status;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method")
    private PaymentMethod paymentMethod;

    @Column(name = "upi_id")
    private String upiId;

    @Column(name = "upi_provider")
    private String upiProvider;

    @Column(name = "bank_reference")
    private String bankReference;

    @Column(name = "qr_code_data")
    private String qrCodeData;

    @Column(name = "callback_url")
    private String callbackUrl;

    @Column(name = "description")
    private String description;

    @CreationTimestamp
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Column(name = "cancellation_reason")
    private String cancellationReason;

    @Column(name = "failure_reason")
    private String failureReason;

    @Column(name = "cancelled_by")
    private String cancelledBy; // USER, MERCHANT, SYSTEM, BANK

    @Column(name = "bank_provider")
    private String bankProvider; // HDFC, ICICI, KOTAK, AXIS

    @Column(name = "bank_transaction_id")
    private String bankTransactionId;

    @Column(name = "payment_url")
    private String paymentUrl;

    @Column(name = "refund_amount", precision = 10, scale = 2)
    private BigDecimal refundAmount;

    @Column(name = "refunded_at")
    private LocalDateTime refundedAt;

    // Constructors
    public Payment() {}

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getMerchantId() { return merchantId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }

    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public PaymentStatus getStatus() { return status; }
    public void setStatus(PaymentStatus status) { this.status = status; }

    public PaymentMethod getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(PaymentMethod paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getUpiId() { return upiId; }
    public void setUpiId(String upiId) { this.upiId = upiId; }

    public String getUpiProvider() { return upiProvider; }
    public void setUpiProvider(String upiProvider) { this.upiProvider = upiProvider; }

    public String getBankReference() { return bankReference; }
    public void setBankReference(String bankReference) { this.bankReference = bankReference; }

    public String getQrCodeData() { return qrCodeData; }
    public void setQrCodeData(String qrCodeData) { this.qrCodeData = qrCodeData; }

    public String getCallbackUrl() { return callbackUrl; }
    public void setCallbackUrl(String callbackUrl) { this.callbackUrl = callbackUrl; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }

    public String getCancellationReason() { return cancellationReason; }
    public void setCancellationReason(String cancellationReason) { this.cancellationReason = cancellationReason; }

    public String getFailureReason() { return failureReason; }
    public void setFailureReason(String failureReason) { this.failureReason = failureReason; }

    public String getCancelledBy() { return cancelledBy; }
    public void setCancelledBy(String cancelledBy) { this.cancelledBy = cancelledBy; }

    public String getBankProvider() { return bankProvider; }
    public void setBankProvider(String bankProvider) { this.bankProvider = bankProvider; }

    public String getBankTransactionId() { return bankTransactionId; }
    public void setBankTransactionId(String bankTransactionId) { this.bankTransactionId = bankTransactionId; }

    public String getPaymentUrl() { return paymentUrl; }
    public void setPaymentUrl(String paymentUrl) { this.paymentUrl = paymentUrl; }

    public BigDecimal getRefundAmount() { return refundAmount; }
    public void setRefundAmount(BigDecimal refundAmount) { this.refundAmount = refundAmount; }

    public LocalDateTime getRefundedAt() { return refundedAt; }
    public void setRefundedAt(LocalDateTime refundedAt) { this.refundedAt = refundedAt; }

    public enum PaymentStatus {
        PENDING, SUCCESS, FAILED, CANCELLED, EXPIRED, REFUNDED
    }

    public enum PaymentMethod {
        UPI_QR, UPI_ID, UPI_INTENT
    }

    public enum CancellationReason {
        USER_CANCELLED("User cancelled the payment"),
        MERCHANT_CANCELLED("Merchant cancelled the payment"),
        TIMEOUT_EXPIRED("Payment timeout expired"),
        INSUFFICIENT_FUNDS("Insufficient funds in account"),
        INVALID_UPI_ID("Invalid UPI ID provided"),
        BANK_DECLINED("Bank declined the transaction"),
        TECHNICAL_ERROR("Technical error occurred"),
        FRAUD_DETECTION("Fraud detection triggered"),
        DUPLICATE_TRANSACTION("Duplicate transaction detected"),
        AMOUNT_LIMIT_EXCEEDED("Transaction amount limit exceeded"),
        DAILY_LIMIT_EXCEEDED("Daily transaction limit exceeded"),
        ACCOUNT_BLOCKED("Account is blocked or suspended"),
        NETWORK_ERROR("Network connectivity issues"),
        UPI_APP_ERROR("UPI app returned error"),
        INVALID_CREDENTIALS("Invalid payment credentials");

        private final String description;

        CancellationReason(String description) {
            this.description = description;
        }

        public String getDescription() {
            return description;
        }
    }
}