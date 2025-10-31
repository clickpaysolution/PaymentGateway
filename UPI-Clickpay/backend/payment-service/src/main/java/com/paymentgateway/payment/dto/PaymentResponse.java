package com.paymentgateway.payment.dto;

import com.paymentgateway.payment.entity.Payment;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class PaymentResponse {
    private Long id;
    private String transactionId;
    private BigDecimal amount;
    private String currency;
    private Payment.PaymentStatus status;
    private Payment.PaymentMethod paymentMethod;
    private String upiId;
    private String upiProvider;
    private String qrCodeData;
    private String paymentUrl;
    private LocalDateTime createdAt;
    private String bankProvider;
    private String bankTransactionId;
    private BigDecimal refundAmount;
    private LocalDateTime refundedAt;

    public PaymentResponse() {}

    public PaymentResponse(Payment payment) {
        this.id = payment.getId();
        this.transactionId = payment.getTransactionId();
        this.amount = payment.getAmount();
        this.currency = payment.getCurrency();
        this.status = payment.getStatus();
        this.paymentMethod = payment.getPaymentMethod();
        this.upiId = payment.getUpiId();
        this.upiProvider = payment.getUpiProvider();
        this.qrCodeData = payment.getQrCodeData();
        this.paymentUrl = payment.getPaymentUrl();
        this.createdAt = payment.getCreatedAt();
        this.bankProvider = payment.getBankProvider();
        this.bankTransactionId = payment.getBankTransactionId();
        this.refundAmount = payment.getRefundAmount();
        this.refundedAt = payment.getRefundedAt();
    }

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public Payment.PaymentStatus getStatus() { return status; }
    public void setStatus(Payment.PaymentStatus status) { this.status = status; }

    public Payment.PaymentMethod getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(Payment.PaymentMethod paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getUpiId() { return upiId; }
    public void setUpiId(String upiId) { this.upiId = upiId; }

    public String getUpiProvider() { return upiProvider; }
    public void setUpiProvider(String upiProvider) { this.upiProvider = upiProvider; }

    public String getQrCodeData() { return qrCodeData; }
    public void setQrCodeData(String qrCodeData) { this.qrCodeData = qrCodeData; }

    public String getPaymentUrl() { return paymentUrl; }
    public void setPaymentUrl(String paymentUrl) { this.paymentUrl = paymentUrl; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public String getBankProvider() { return bankProvider; }
    public void setBankProvider(String bankProvider) { this.bankProvider = bankProvider; }

    public String getBankTransactionId() { return bankTransactionId; }
    public void setBankTransactionId(String bankTransactionId) { this.bankTransactionId = bankTransactionId; }

    public BigDecimal getRefundAmount() { return refundAmount; }
    public void setRefundAmount(BigDecimal refundAmount) { this.refundAmount = refundAmount; }

    public LocalDateTime getRefundedAt() { return refundedAt; }
    public void setRefundedAt(LocalDateTime refundedAt) { this.refundedAt = refundedAt; }
}