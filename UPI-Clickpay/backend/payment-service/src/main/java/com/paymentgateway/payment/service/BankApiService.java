package com.paymentgateway.payment.service;

import com.paymentgateway.payment.dto.BankPaymentRequest;
import com.paymentgateway.payment.dto.BankPaymentResponse;

public interface BankApiService {
    
    /**
     * Create a payment request with the bank
     */
    BankPaymentResponse createPayment(BankPaymentRequest request);
    
    /**
     * Check payment status with the bank
     */
    BankPaymentResponse checkPaymentStatus(String bankTransactionId);
    
    /**
     * Refund a payment
     */
    BankPaymentResponse refundPayment(String bankTransactionId, String refundAmount);
    
    /**
     * Validate webhook signature from bank
     */
    boolean validateWebhookSignature(String payload, String signature);
    
    /**
     * Get bank name identifier
     */
    String getBankName();
}