package com.paymentgateway.payment.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class BankPaymentResponse {
    private String bankTransactionId;
    private String merchantTransactionId;
    private String status;
    private BigDecimal amount;
    private String currency;
    private String paymentUrl;
    private String qrCodeData;
    private String errorCode;
    private String errorMessage;
    private LocalDateTime createdAt;
    private LocalDateTime expiresAt;

    public BankPaymentResponse() {}

    public BankPaymentResponse(String bankTransactionId, String merchantTransactionId, 
                              String status, BigDecimal amount, String currency) {
        this.bankTransactionId = bankTransactionId;
        this.merchantTransactionId = merchantTransactionId;
        this.status = status;
        this.amount = amount;
        this.currency = currency;
        this.createdAt = LocalDateTime.now();
    }

    // Getters and setters
    public String getBankTransactionId() { return bankTransactionId; }
    public void setBankTransactionId(String bankTransactionId) { this.bankTransactionId = bankTransactionId; }

    public String getMerchantTransactionId() { return merchantTransactionId; }
    public void setMerchantTransactionId(String merchantTransactionId) { this.merchantTransactionId = merchantTransactionId; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getPaymentUrl() { return paymentUrl; }
    public void setPaymentUrl(String paymentUrl) { this.paymentUrl = paymentUrl; }

    public String getQrCodeData() { return qrCodeData; }
    public void setQrCodeData(String qrCodeData) { this.qrCodeData = qrCodeData; }

    public String getErrorCode() { return errorCode; }
    public void setErrorCode(String errorCode) { this.errorCode = errorCode; }

    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDateTime expiresAt) { this.expiresAt = expiresAt; }

    public boolean isSuccess() {
        return "SUCCESS".equalsIgnoreCase(status) || "PENDING".equalsIgnoreCase(status);
    }
}