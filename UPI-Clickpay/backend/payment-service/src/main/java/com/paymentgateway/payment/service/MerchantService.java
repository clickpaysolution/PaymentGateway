package com.paymentgateway.payment.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Service
public class MerchantService {

    @Value("${merchant.service.url:http://localhost:8082}")
    private String merchantServiceUrl;

    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * Get merchant information including preferred bank
     */
    public MerchantInfo getMerchantInfo(Long merchantId) {
        try {
            HttpHeaders headers = new HttpHeaders();
            HttpEntity<String> entity = new HttpEntity<>(headers);

            ResponseEntity<Map> response = restTemplate.exchange(
                merchantServiceUrl + "/merchants/" + merchantId + "/info",
                HttpMethod.GET,
                entity,
                Map.class
            );

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Map<String, Object> merchantData = response.getBody();
                return mapToMerchantInfo(merchantData);
            }
        } catch (Exception e) {
            System.out.println("Error fetching merchant info: " + e.getMessage());
        }

        // Return default merchant info if service call fails
        return getDefaultMerchantInfo(merchantId);
    }

    private MerchantInfo mapToMerchantInfo(Map<String, Object> merchantData) {
        MerchantInfo info = new MerchantInfo();
        info.setId(Long.valueOf(merchantData.get("id").toString()));
        info.setBusinessName((String) merchantData.get("businessName"));
        info.setUpiId((String) merchantData.get("upiId"));
        info.setWebhookUrl((String) merchantData.get("webhookUrl"));
        
        // Get preferred bank, default to AXIS if not specified
        String preferredBank = (String) merchantData.get("preferredBank");
        if (preferredBank != null) {
            try {
                info.setPreferredBank(BankApiServiceFactory.BankProvider.valueOf(preferredBank));
            } catch (IllegalArgumentException e) {
                info.setPreferredBank(BankApiServiceFactory.BankProvider.AXIS);
            }
        } else {
            info.setPreferredBank(BankApiServiceFactory.BankProvider.AXIS);
        }
        
        return info;
    }

    private MerchantInfo getDefaultMerchantInfo(Long merchantId) {
        MerchantInfo info = new MerchantInfo();
        info.setId(merchantId);
        info.setBusinessName("Default Merchant");
        info.setUpiId("merchant@axis");
        info.setPreferredBank(BankApiServiceFactory.BankProvider.AXIS); // Default to Axis
        return info;
    }

    /**
     * Inner class to hold merchant information
     */
    public static class MerchantInfo {
        private Long id;
        private String businessName;
        private String upiId;
        private String webhookUrl;
        private BankApiServiceFactory.BankProvider preferredBank;

        // Getters and setters
        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }

        public String getBusinessName() { return businessName; }
        public void setBusinessName(String businessName) { this.businessName = businessName; }

        public String getUpiId() { return upiId; }
        public void setUpiId(String upiId) { this.upiId = upiId; }

        public String getWebhookUrl() { return webhookUrl; }
        public void setWebhookUrl(String webhookUrl) { this.webhookUrl = webhookUrl; }

        public BankApiServiceFactory.BankProvider getPreferredBank() { return preferredBank; }
        public void setPreferredBank(BankApiServiceFactory.BankProvider preferredBank) { this.preferredBank = preferredBank; }
    }
}