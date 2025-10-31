package com.paymentgateway.payment.service;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.Base64;
import java.util.UUID;

@Service
public class QRCodeService {

    public String generateUPIQRCode(String merchantUPI, BigDecimal amount, String transactionId, String description) {
        try {
            // UPI URL format: upi://pay?pa=merchant@upi&pn=MerchantName&am=100.00&tr=TXN123&tn=Description
            String upiUrl = String.format(
                "upi://pay?pa=%s&am=%.2f&tr=%s&tn=%s&cu=INR",
                merchantUPI,
                amount,
                transactionId,
                description != null ? description : "Payment"
            );

            QRCodeWriter qrCodeWriter = new QRCodeWriter();
            BitMatrix bitMatrix = qrCodeWriter.encode(upiUrl, BarcodeFormat.QR_CODE, 300, 300);

            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            MatrixToImageWriter.writeToStream(bitMatrix, "PNG", outputStream);
            
            byte[] qrCodeBytes = outputStream.toByteArray();
            return Base64.getEncoder().encodeToString(qrCodeBytes);
            
        } catch (WriterException | IOException e) {
            throw new RuntimeException("Failed to generate QR code", e);
        }
    }

    public String generateDynamicQRCode(String merchantUPI, BigDecimal amount, String description) {
        String transactionId = "TXN" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        return generateUPIQRCode(merchantUPI, amount, transactionId, description);
    }
}