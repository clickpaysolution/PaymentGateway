package com.paymentgateway.payment.dto;

import com.paymentgateway.payment.entity.Payment;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public class PaymentRequest {
    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.01", message = "Amount must be greater than 0")
    private BigDecimal amount;

    private String currency = "INR";

    @NotNull(message = "Payment method is required")
    private Payment.PaymentMethod paymentMethod;

    private String upiId;
    private String upiProvider;
    private String callbackUrl;
    private String description;

    public PaymentRequest() {}

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public Payment.PaymentMethod getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(Payment.PaymentMethod paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getUpiId() { return upiId; }
    public void setUpiId(String upiId) { this.upiId = upiId; }

    public String getUpiProvider() { return upiProvider; }
    public void setUpiProvider(String upiProvider) { this.upiProvider = upiProvider; }

    public String getCallbackUrl() { return callbackUrl; }
    public void setCallbackUrl(String callbackUrl) { this.callbackUrl = callbackUrl; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
}