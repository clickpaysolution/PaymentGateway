package com.paymentgateway.merchant.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.paymentgateway.merchant.dto.MerchantConfigRequest;
import com.paymentgateway.merchant.entity.Merchant;
import com.paymentgateway.merchant.repository.MerchantRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

@Service
public class MerchantConfigService {

    @Autowired
    private MerchantRepository merchantRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @Transactional
    public void updateMerchantConfiguration(Long merchantId, MerchantConfigRequest request) {
        Merchant merchant = merchantRepository.findByUserId(merchantId)
            .orElseThrow(() -> new RuntimeException("Merchant not found"));

        // Update operation mode
        merchant.setOperationMode(request.getOperationMode());
        
        // Update preferred bank
        if (request.getPreferredBank() != null) {
            merchant.setPreferredBank(request.getPreferredBank());
        }

        // Update fee structure
        if (request.getFeeStructure() != null) {
            try {
                String feeStructureJson = objectMapper.writeValueAsString(request.getFeeStructure());
                merchant.setFeeStructure(feeStructureJson);
            } catch (Exception e) {
                throw new RuntimeException("Failed to serialize fee structure", e);
            }
        } else {
            // Set default fee structure based on operation mode
            merchant.setFeeStructure(createDefaultFeeStructure(request.getOperationMode()));
        }

        // Update bank configuration
        if (request.getBankConfig() != null) {
            try {
                String bankConfigJson = objectMapper.writeValueAsString(request.getBankConfig());
                merchant.setBankConfig(bankConfigJson);
            } catch (Exception e) {
                throw new RuntimeException("Failed to serialize bank configuration", e);
            }
        }

        // Update settlement configuration
        if (request.getSettlementConfig() != null) {
            try {
                String settlementConfigJson = objectMapper.writeValueAsString(request.getSettlementConfig());
                merchant.setSettlementConfig(settlementConfigJson);
            } catch (Exception e) {
                throw new RuntimeException("Failed to serialize settlement configuration", e);
            }
        }

        merchantRepository.save(merchant);
    }

    public MerchantConfigRequest getMerchantConfiguration(Long merchantId) {
        Merchant merchant = merchantRepository.findByUserId(merchantId)
            .orElseThrow(() -> new RuntimeException("Merchant not found"));

        MerchantConfigRequest config = new MerchantConfigRequest();
        config.setOperationMode(merchant.getOperationMode());
        config.setPreferredBank(merchant.getPreferredBank());

        try {
            if (merchant.getFeeStructure() != null) {
                MerchantConfigRequest.FeeStructureDto feeStructure = 
                    objectMapper.readValue(merchant.getFeeStructure(), MerchantConfigRequest.FeeStructureDto.class);
                config.setFeeStructure(feeStructure);
            }

            if (merchant.getBankConfig() != null) {
                MerchantConfigRequest.BankConfigDto bankConfig = 
                    objectMapper.readValue(merchant.getBankConfig(), MerchantConfigRequest.BankConfigDto.class);
                config.setBankConfig(bankConfig);
            }

            if (merchant.getSettlementConfig() != null) {
                MerchantConfigRequest.SettlementConfigDto settlementConfig = 
                    objectMapper.readValue(merchant.getSettlementConfig(), MerchantConfigRequest.SettlementConfigDto.class);
                config.setSettlementConfig(settlementConfig);
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to deserialize merchant configuration", e);
        }

        return config;
    }

    private String createDefaultFeeStructure(Merchant.OperationMode operationMode) {
        try {
            MerchantConfigRequest.FeeStructureDto feeStructure = new MerchantConfigRequest.FeeStructureDto();
            
            switch (operationMode) {
                case GATEWAY_ONLY:
                    feeStructure.setSetupFee(BigDecimal.ZERO);
                    feeStructure.setMonthlyFee(new BigDecimal("2000"));
                    feeStructure.setTransactionFee(new BigDecimal("2.00"));
                    feeStructure.setPercentageFee(BigDecimal.ZERO);
                    break;
                    
                case FULL_PROCESSOR:
                    feeStructure.setSetupFee(new BigDecimal("5000"));
                    feeStructure.setMonthlyFee(new BigDecimal("1000"));
                    feeStructure.setTransactionFee(new BigDecimal("2.00"));
                    feeStructure.setPercentageFee(new BigDecimal("1.5"));
                    break;
                    
                case HYBRID:
                    feeStructure.setSetupFee(new BigDecimal("2500"));
                    feeStructure.setMonthlyFee(new BigDecimal("1500"));
                    feeStructure.setTransactionFee(new BigDecimal("2.00"));
                    feeStructure.setPercentageFee(new BigDecimal("0.75")); // Average
                    break;
            }
            
            return objectMapper.writeValueAsString(feeStructure);
        } catch (Exception e) {
            throw new RuntimeException("Failed to create default fee structure", e);
        }
    }

    public Map<String, Object> calculateFeeEstimate(Merchant.OperationMode mode, 
                                                   BigDecimal monthlyVolume, 
                                                   BigDecimal avgTransactionSize) {
        
        Map<String, Object> estimate = new HashMap<>();
        
        int transactions = monthlyVolume.divide(avgTransactionSize, 0, BigDecimal.ROUND_UP).intValue();
        
        BigDecimal setupFee = BigDecimal.ZERO;
        BigDecimal monthlyFee = BigDecimal.ZERO;
        BigDecimal transactionFees = BigDecimal.ZERO;
        BigDecimal percentageFees = BigDecimal.ZERO;
        
        switch (mode) {
            case GATEWAY_ONLY:
                setupFee = BigDecimal.ZERO;
                monthlyFee = new BigDecimal("2000");
                transactionFees = new BigDecimal("2.00").multiply(new BigDecimal(transactions));
                percentageFees = BigDecimal.ZERO;
                break;
                
            case FULL_PROCESSOR:
                setupFee = new BigDecimal("5000");
                monthlyFee = new BigDecimal("1000");
                transactionFees = new BigDecimal("2.00").multiply(new BigDecimal(transactions));
                percentageFees = monthlyVolume.multiply(new BigDecimal("0.015"));
                break;
                
            case HYBRID:
                // Assume 70% small transactions (processor), 30% large (gateway)
                BigDecimal smallVolume = monthlyVolume.multiply(new BigDecimal("0.3"));
                
                setupFee = new BigDecimal("2500");
                monthlyFee = new BigDecimal("1500");
                transactionFees = new BigDecimal("2.00").multiply(new BigDecimal(transactions));
                percentageFees = smallVolume.multiply(new BigDecimal("0.015"));
                break;
        }
        
        BigDecimal totalMonthlyFee = monthlyFee.add(transactionFees).add(percentageFees);
        BigDecimal effectiveRate = totalMonthlyFee.divide(monthlyVolume, 4, BigDecimal.ROUND_HALF_UP)
                                                 .multiply(new BigDecimal("100"));
        
        estimate.put("setupFee", setupFee);
        estimate.put("monthlyFee", monthlyFee);
        estimate.put("transactionFees", transactionFees);
        estimate.put("percentageFees", percentageFees);
        estimate.put("totalMonthlyFee", totalMonthlyFee);
        estimate.put("effectiveRate", effectiveRate);
        estimate.put("transactions", transactions);
        
        return estimate;
    }

    public boolean validateBankConfiguration(MerchantConfigRequest.BankConfigDto bankConfig) {
        // Validate required fields for gateway mode
        if (bankConfig.getProvider() == null || bankConfig.getProvider().trim().isEmpty()) {
            return false;
        }
        
        if (bankConfig.getMerchantId() == null || bankConfig.getMerchantId().trim().isEmpty()) {
            return false;
        }
        
        if (bankConfig.getApiKey() == null || bankConfig.getApiKey().trim().isEmpty()) {
            return false;
        }
        
        // Additional validation logic can be added here
        // e.g., test API connectivity, validate credentials format, etc.
        
        return true;
    }

    public Map<String, Object> getMerchantInfo(Long merchantId) {
        Merchant merchant = merchantRepository.findById(merchantId)
            .orElseThrow(() -> new RuntimeException("Merchant not found"));

        Map<String, Object> info = new HashMap<>();
        info.put("id", merchant.getId());
        info.put("businessName", merchant.getBusinessName());
        info.put("upiId", merchant.getUpiId());
        info.put("webhookUrl", merchant.getWebhookUrl());
        info.put("preferredBank", merchant.getPreferredBank() != null ? merchant.getPreferredBank().name() : "AXIS");
        info.put("operationMode", merchant.getOperationMode());
        info.put("isActive", merchant.getIsActive());

        return info;
    }
}