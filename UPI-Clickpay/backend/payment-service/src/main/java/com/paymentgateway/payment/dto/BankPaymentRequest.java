package com.paymentgateway.payment.dto;

import java.math.BigDecimal;

public class BankPaymentRequest {
    private String merchantId;
    private String transactionId;
    private BigDecimal amount;
    private String currency;
    private String paymentMethod;
    private String upiId;
    private String callbackUrl;
    private String description;
    private CustomerInfo customerInfo;

    public BankPaymentRequest() {}

    public BankPaymentRequest(String merchantId, String transactionId, BigDecimal amount, 
                             String currency, String paymentMethod, String callbackUrl) {
        this.merchantId = merchantId;
        this.transactionId = transactionId;
        this.amount = amount;
        this.currency = currency;
        this.paymentMethod = paymentMethod;
        this.callbackUrl = callbackUrl;
    }

    // Getters and setters
    public String getMerchantId() { return merchantId; }
    public void setMerchantId(String merchantId) { this.merchantId = merchantId; }

    public String getTransactionId() { return transactionId; }
    public void setTransactionId(String transactionId) { this.transactionId = transactionId; }

    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getUpiId() { return upiId; }
    public void setUpiId(String upiId) { this.upiId = upiId; }

    public String getCallbackUrl() { return callbackUrl; }
    public void setCallbackUrl(String callbackUrl) { this.callbackUrl = callbackUrl; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public CustomerInfo getCustomerInfo() { return customerInfo; }
    public void setCustomerInfo(CustomerInfo customerInfo) { this.customerInfo = customerInfo; }

    public static class CustomerInfo {
        private String name;
        private String email;
        private String phone;

        public CustomerInfo() {}

        public String getName() { return name; }
        public void setName(String name) { this.name = name; }

        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }

        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
    }
}