package com.paymentgateway.merchant.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "merchants")
public class Merchant {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", unique = true, nullable = false)
    private Long userId;

    @Column(name = "business_name", nullable = false)
    private String businessName;

    @Column(name = "api_key", unique = true, nullable = false)
    private String apiKey;

    @Column(name = "webhook_url")
    private String webhookUrl;

    @Column(name = "upi_id")
    private String upiId;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Enumerated(EnumType.STRING)
    @Column(name = "operation_mode")
    private OperationMode operationMode = OperationMode.FULL_PROCESSOR;
    
    @Column(name = "fee_structure", columnDefinition = "TEXT")
    private String feeStructure;
    
    @Column(name = "bank_config", columnDefinition = "TEXT")
    private String bankConfig;
    
    @Column(name = "settlement_config", columnDefinition = "TEXT")
    private String settlementConfig;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "preferred_bank")
    private BankProvider preferredBank = BankProvider.AXIS;

    @CreationTimestamp
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Constructors
    public Merchant() {}

    public Merchant(Long userId, String businessName, String apiKey) {
        this.userId = userId;
        this.businessName = businessName;
        this.apiKey = apiKey;
    }

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getBusinessName() { return businessName; }
    public void setBusinessName(String businessName) { this.businessName = businessName; }

    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }

    public String getWebhookUrl() { return webhookUrl; }
    public void setWebhookUrl(String webhookUrl) { this.webhookUrl = webhookUrl; }

    public String getUpiId() { return upiId; }
    public void setUpiId(String upiId) { this.upiId = upiId; }

    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public OperationMode getOperationMode() { return operationMode; }
    public void setOperationMode(OperationMode operationMode) { this.operationMode = operationMode; }

    public String getFeeStructure() { return feeStructure; }
    public void setFeeStructure(String feeStructure) { this.feeStructure = feeStructure; }

    public String getBankConfig() { return bankConfig; }
    public void setBankConfig(String bankConfig) { this.bankConfig = bankConfig; }

    public String getSettlementConfig() { return settlementConfig; }
    public void setSettlementConfig(String settlementConfig) { this.settlementConfig = settlementConfig; }

    public BankProvider getPreferredBank() { return preferredBank; }
    public void setPreferredBank(BankProvider preferredBank) { this.preferredBank = preferredBank; }

    public enum OperationMode {
        GATEWAY_ONLY,
        FULL_PROCESSOR,
        HYBRID
    }
    
    public enum BankProvider {
        HDFC("HDFC Bank"),
        ICICI("ICICI Bank"),
        KOTAK("Kotak Mahindra Bank"),
        AXIS("Axis Bank");
        
        private final String displayName;
        
        BankProvider(String displayName) {
            this.displayName = displayName;
        }
        
        public String getDisplayName() {
            return displayName;
        }
    }
}