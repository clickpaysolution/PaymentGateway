package com.paymentgateway.payment.service;

import com.paymentgateway.payment.dto.BankPaymentRequest;
import com.paymentgateway.payment.dto.BankPaymentResponse;
import com.paymentgateway.payment.dto.PaymentRequest;
import com.paymentgateway.payment.dto.PaymentResponse;
import com.paymentgateway.payment.entity.Payment;
import com.paymentgateway.payment.repository.PaymentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
public class PaymentService {

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private QRCodeService qrCodeService;

    @Autowired
    private UPIService upiService;

    @Autowired
    private BankApiServiceFactory bankApiServiceFactory;

    @Autowired
    private MerchantService merchantService;

    public PaymentResponse createPayment(Long merchantId, PaymentRequest request) {
        // Get merchant information including preferred bank
        MerchantService.MerchantInfo merchantInfo = merchantService.getMerchantInfo(merchantId);
        
        // Get the appropriate bank API service based on merchant's preference
        BankApiService bankApiService = bankApiServiceFactory.getBankApiService(merchantInfo.getPreferredBank());
        
        Payment payment = new Payment();
        payment.setMerchantId(merchantId);
        payment.setTransactionId(generateTransactionId());
        payment.setAmount(request.getAmount());
        payment.setCurrency(request.getCurrency());
        payment.setPaymentMethod(request.getPaymentMethod());
        payment.setStatus(Payment.PaymentStatus.PENDING);
        payment.setCallbackUrl(request.getCallbackUrl());
        payment.setDescription(request.getDescription());
        payment.setBankProvider(merchantInfo.getPreferredBank().name());

        // Create bank payment request
        BankPaymentRequest bankRequest = new BankPaymentRequest();
        bankRequest.setTransactionId(payment.getTransactionId());
        bankRequest.setAmount(request.getAmount());
        bankRequest.setCurrency(request.getCurrency());
        bankRequest.setCallbackUrl(request.getCallbackUrl());
        bankRequest.setDescription(request.getDescription());
        bankRequest.setUpiId(request.getUpiId());

        // Handle different payment methods
        switch (request.getPaymentMethod()) {
            case UPI_QR:
                // Create payment with bank and get QR code
                BankPaymentResponse bankResponse = bankApiService.createPayment(bankRequest);
                if (bankResponse.getQrCodeData() != null) {
                    payment.setQrCodeData(bankResponse.getQrCodeData());
                } else {
                    // Fallback to local QR generation
                    String qrCode = qrCodeService.generateDynamicQRCode(
                        merchantInfo.getUpiId() != null ? merchantInfo.getUpiId() : "merchant@" + merchantInfo.getPreferredBank().name().toLowerCase(),
                        request.getAmount(),
                        request.getDescription()
                    );
                    payment.setQrCodeData(qrCode);
                }
                payment.setBankTransactionId(bankResponse.getBankTransactionId());
                break;
                
            case UPI_ID:
                payment.setUpiId(request.getUpiId());
                bankRequest.setUpiId(request.getUpiId());
                BankPaymentResponse upiResponse = bankApiService.createPayment(bankRequest);
                payment.setBankTransactionId(upiResponse.getBankTransactionId());
                // Send payment request to UPI ID
                upiService.sendPaymentRequest(request.getUpiId(), request.getAmount(), payment.getTransactionId());
                break;
                
            case UPI_INTENT:
                payment.setUpiProvider(request.getUpiProvider());
                BankPaymentResponse intentResponse = bankApiService.createPayment(bankRequest);
                payment.setBankTransactionId(intentResponse.getBankTransactionId());
                if (intentResponse.getPaymentUrl() != null) {
                    payment.setPaymentUrl(intentResponse.getPaymentUrl());
                }
                break;
        }

        payment = paymentRepository.save(payment);
        
        PaymentResponse response = new PaymentResponse(payment);
        response.setBankProvider(merchantInfo.getPreferredBank().getDisplayName());
        
        if (payment.getPaymentMethod() == Payment.PaymentMethod.UPI_INTENT && payment.getPaymentUrl() == null) {
            response.setPaymentUrl(generateUPIIntentUrl(payment, merchantInfo));
        }
        
        return response;
    }

    public PaymentResponse getPaymentStatus(String transactionId) {
        Payment payment = paymentRepository.findByTransactionId(transactionId)
            .orElseThrow(() -> new RuntimeException("Payment not found"));
        
        // If payment is still pending and we have a bank transaction ID, check with bank
        if (payment.getStatus() == Payment.PaymentStatus.PENDING && payment.getBankTransactionId() != null) {
            try {
                // Get merchant info to determine which bank API to use
                MerchantService.MerchantInfo merchantInfo = merchantService.getMerchantInfo(payment.getMerchantId());
                BankApiService bankApiService = bankApiServiceFactory.getBankApiService(merchantInfo.getPreferredBank());
                
                // Check status with bank
                BankPaymentResponse bankStatus = bankApiService.checkPaymentStatus(payment.getBankTransactionId());
                
                // Update payment status based on bank response
                if ("SUCCESS".equalsIgnoreCase(bankStatus.getStatus()) || "COMPLETED".equalsIgnoreCase(bankStatus.getStatus())) {
                    payment.setStatus(Payment.PaymentStatus.SUCCESS);
                    payment.setCompletedAt(LocalDateTime.now());
                    paymentRepository.save(payment);
                } else if ("FAILED".equalsIgnoreCase(bankStatus.getStatus()) || "CANCELLED".equalsIgnoreCase(bankStatus.getStatus())) {
                    payment.setStatus(Payment.PaymentStatus.FAILED);
                    payment.setCompletedAt(LocalDateTime.now());
                    paymentRepository.save(payment);
                }
            } catch (Exception e) {
                System.out.println("Error checking payment status with bank: " + e.getMessage());
            }
        }
        
        return new PaymentResponse(payment);
    }

    public PaymentResponse updatePaymentStatus(String transactionId, Payment.PaymentStatus status, String bankReference) {
        Payment payment = paymentRepository.findByTransactionId(transactionId)
            .orElseThrow(() -> new RuntimeException("Payment not found"));
        
        payment.setStatus(status);
        payment.setBankReference(bankReference);
        
        if (status == Payment.PaymentStatus.SUCCESS || status == Payment.PaymentStatus.FAILED) {
            payment.setCompletedAt(LocalDateTime.now());
        }
        
        payment = paymentRepository.save(payment);
        return new PaymentResponse(payment);
    }

    private String generateTransactionId() {
        return "TXN" + System.currentTimeMillis() + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
    }

    private String generateUPIIntentUrl(Payment payment, MerchantService.MerchantInfo merchantInfo) {
        String merchantUpiId = merchantInfo.getUpiId() != null ? 
            merchantInfo.getUpiId() : 
            "merchant@" + merchantInfo.getPreferredBank().name().toLowerCase();
            
        return String.format(
            "upi://pay?pa=%s&am=%.2f&tr=%s&tn=%s&cu=INR",
            merchantUpiId,
            payment.getAmount(),
            payment.getTransactionId(),
            payment.getDescription() != null ? payment.getDescription() : "Payment"
        );
    }

    /**
     * Refund a payment using the appropriate bank API
     */
    public PaymentResponse refundPayment(String transactionId, String refundAmount) {
        Payment payment = paymentRepository.findByTransactionId(transactionId)
            .orElseThrow(() -> new RuntimeException("Payment not found"));

        if (payment.getStatus() != Payment.PaymentStatus.SUCCESS) {
            throw new RuntimeException("Can only refund successful payments");
        }

        try {
            // Get merchant info to determine which bank API to use
            MerchantService.MerchantInfo merchantInfo = merchantService.getMerchantInfo(payment.getMerchantId());
            BankApiService bankApiService = bankApiServiceFactory.getBankApiService(merchantInfo.getPreferredBank());

            // Process refund with bank
            BankPaymentResponse refundResponse = bankApiService.refundPayment(
                payment.getBankTransactionId(), 
                refundAmount
            );

            if ("SUCCESS".equalsIgnoreCase(refundResponse.getStatus()) || "COMPLETED".equalsIgnoreCase(refundResponse.getStatus())) {
                payment.setStatus(Payment.PaymentStatus.REFUNDED);
                payment.setRefundAmount(new java.math.BigDecimal(refundAmount));
                payment.setRefundedAt(LocalDateTime.now());
                payment = paymentRepository.save(payment);
            }

        } catch (Exception e) {
            System.out.println("Error processing refund: " + e.getMessage());
            throw new RuntimeException("Failed to process refund");
        }

        return new PaymentResponse(payment);
    }
}