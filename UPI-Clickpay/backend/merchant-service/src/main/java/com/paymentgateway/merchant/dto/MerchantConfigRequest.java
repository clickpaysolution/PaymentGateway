package com.paymentgateway.merchant.dto;

import com.paymentgateway.merchant.entity.Merchant;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public class MerchantConfigRequest {
    
    @NotNull
    private Merchant.OperationMode operationMode;
    
    private Merchant.BankProvider preferredBank;
    
    private FeeStructureDto feeStructure;
    
    private BankConfigDto bankConfig;
    
    private SettlementConfigDto settlementConfig;

    // Getters and setters
    public Merchant.OperationMode getOperationMode() { return operationMode; }
    public void setOperationMode(Merchant.OperationMode operationMode) { this.operationMode = operationMode; }

    public Merchant.BankProvider getPreferredBank() { return preferredBank; }
    public void setPreferredBank(Merchant.BankProvider preferredBank) { this.preferredBank = preferredBank; }

    public FeeStructureDto getFeeStructure() { return feeStructure; }
    public void setFeeStructure(FeeStructureDto feeStructure) { this.feeStructure = feeStructure; }

    public BankConfigDto getBankConfig() { return bankConfig; }
    public void setBankConfig(BankConfigDto bankConfig) { this.bankConfig = bankConfig; }

    public SettlementConfigDto getSettlementConfig() { return settlementConfig; }
    public void setSettlementConfig(SettlementConfigDto settlementConfig) { this.settlementConfig = settlementConfig; }

    public static class FeeStructureDto {
        private BigDecimal setupFee;
        private BigDecimal monthlyFee;
        private BigDecimal transactionFee;
        private BigDecimal percentageFee;

        // Getters and setters
        public BigDecimal getSetupFee() { return setupFee; }
        public void setSetupFee(BigDecimal setupFee) { this.setupFee = setupFee; }

        public BigDecimal getMonthlyFee() { return monthlyFee; }
        public void setMonthlyFee(BigDecimal monthlyFee) { this.monthlyFee = monthlyFee; }

        public BigDecimal getTransactionFee() { return transactionFee; }
        public void setTransactionFee(BigDecimal transactionFee) { this.transactionFee = transactionFee; }

        public BigDecimal getPercentageFee() { return percentageFee; }
        public void setPercentageFee(BigDecimal percentageFee) { this.percentageFee = percentageFee; }
    }

    public static class BankConfigDto {
        private String provider; // HDFC, ICICI, KOTAK, AXIS
        private String merchantId;
        private String apiKey;
        private String apiSecret;
        private String apiUrl;
        private boolean directSettlement;
        private String settlementAccount;

        // Getters and setters
        public String getProvider() { return provider; }
        public void setProvider(String provider) { this.provider = provider; }

        public String getMerchantId() { return merchantId; }
        public void setMerchantId(String merchantId) { this.merchantId = merchantId; }

        public String getApiKey() { return apiKey; }
        public void setApiKey(String apiKey) { this.apiKey = apiKey; }

        public String getApiSecret() { return apiSecret; }
        public void setApiSecret(String apiSecret) { this.apiSecret = apiSecret; }

        public String getApiUrl() { return apiUrl; }
        public void setApiUrl(String apiUrl) { this.apiUrl = apiUrl; }

        public boolean isDirectSettlement() { return directSettlement; }
        public void setDirectSettlement(boolean directSettlement) { this.directSettlement = directSettlement; }

        public String getSettlementAccount() { return settlementAccount; }
        public void setSettlementAccount(String settlementAccount) { this.settlementAccount = settlementAccount; }
    }

    public static class SettlementConfigDto {
        private String settlementMode; // DIRECT, POOLED
        private String settlementCycle; // T+0, T+1, T+2
        private boolean autoSettlement;
        private BigDecimal minimumSettlementAmount;
        private String settlementAccount;

        // Getters and setters
        public String getSettlementMode() { return settlementMode; }
        public void setSettlementMode(String settlementMode) { this.settlementMode = settlementMode; }

        public String getSettlementCycle() { return settlementCycle; }
        public void setSettlementCycle(String settlementCycle) { this.settlementCycle = settlementCycle; }

        public boolean isAutoSettlement() { return autoSettlement; }
        public void setAutoSettlement(boolean autoSettlement) { this.autoSettlement = autoSettlement; }

        public BigDecimal getMinimumSettlementAmount() { return minimumSettlementAmount; }
        public void setMinimumSettlementAmount(BigDecimal minimumSettlementAmount) { this.minimumSettlementAmount = minimumSettlementAmount; }

        public String getSettlementAccount() { return settlementAccount; }
        public void setSettlementAccount(String settlementAccount) { this.settlementAccount = settlementAccount; }
    }
}