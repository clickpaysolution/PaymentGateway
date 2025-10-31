# Payment Gateway vs Payment Processor: Merchant Guide

## Overview

Our platform can operate as both a **Payment Gateway** and a **Payment Processor** depending on your business needs and configuration. Understanding the difference is crucial for choosing the right service model and pricing structure.

## Key Differences

### Payment Gateway Mode
**What it is:** A technology service that securely transmits payment information between merchants and payment processors.

**What we do:**
- Provide secure payment interface
- Handle payment form and UPI integration
- Encrypt and transmit payment data
- Return transaction results
- **We DON'T handle the actual money**

**Money Flow:**
```
Customer → Your Bank Account (via your processor)
```

### Payment Processor Mode
**What it is:** A financial service that actually processes the payment and handles money movement.

**What we do:**
- Everything a gateway does PLUS
- Actually process the payment through banks
- Handle money movement and settlement
- Manage merchant accounts and funds
- **We DO handle the actual money**

**Money Flow:**
```
Customer → Our System → Your Bank Account (after our fees)
```

## Detailed Comparison

| Aspect | Payment Gateway | Payment Processor |
|--------|----------------|-------------------|
| **Money Handling** | No | Yes |
| **Settlement** | Direct to merchant | Through our system |
| **Merchant Account** | Merchant owns | We provide |
| **Bank Relationships** | Merchant manages | We manage |
| **Compliance** | Basic PCI DSS | Full financial compliance |
| **Fees** | Lower (technology only) | Higher (includes processing) |
| **Setup Time** | Quick | Longer (due to compliance) |
| **Control** | High | Medium |
| **Risk** | Lower | Higher |

## Configuration Options

### Option 1: Gateway-Only Mode

**Best for:**
- Large merchants with existing bank relationships
- Businesses wanting full control over settlements
- Companies with compliance teams
- High-volume merchants seeking lower fees

**Requirements:**
- Existing merchant account with bank
- Direct bank API integration
- PCI DSS compliance
- Technical integration capability

**Pricing:**
- Setup fee: ₹0
- Monthly fee: ₹2,000
- Transaction fee: ₹2 per transaction
- No percentage fee

**Configuration:**
```json
{
  "merchantConfig": {
    "mode": "GATEWAY_ONLY",
    "bankIntegration": {
      "provider": "HDFC_BANK",
      "merchantId": "merchant_bank_id",
      "apiKey": "bank_api_key",
      "directSettlement": true
    },
    "fees": {
      "setupFee": 0,
      "monthlyFee": 2000,
      "transactionFee": 2.00,
      "percentageFee": 0
    }
  }
}
```

### Option 2: Full Processor Mode

**Best for:**
- Small to medium businesses
- Startups without bank relationships
- Merchants wanting hassle-free setup
- Businesses preferring all-in-one solution

**Requirements:**
- KYC documentation
- Business verification
- Our compliance approval
- Basic integration only

**Pricing:**
- Setup fee: ₹5,000
- Monthly fee: ₹1,000
- Transaction fee: ₹2 per transaction
- Percentage fee: 1.5% of transaction amount

**Configuration:**
```json
{
  "merchantConfig": {
    "mode": "FULL_PROCESSOR",
    "bankIntegration": {
      "provider": "OUR_SYSTEM",
      "merchantAccount": "our_merchant_pool",
      "directSettlement": false,
      "settlementCycle": "T+1"
    },
    "fees": {
      "setupFee": 5000,
      "monthlyFee": 1000,
      "transactionFee": 2.00,
      "percentageFee": 1.5
    }
  }
}
```

### Option 3: Hybrid Mode

**Best for:**
- Growing businesses
- Merchants wanting flexibility
- Companies transitioning between models

**Features:**
- Start as processor, migrate to gateway
- Use our processing for small amounts, direct for large
- Flexible fee structure based on volume

**Configuration:**
```json
{
  "merchantConfig": {
    "mode": "HYBRID",
    "rules": [
      {
        "condition": "amount <= 10000",
        "mode": "FULL_PROCESSOR",
        "fees": {
          "transactionFee": 2.00,
          "percentageFee": 1.5
        }
      },
      {
        "condition": "amount > 10000",
        "mode": "GATEWAY_ONLY",
        "fees": {
          "transactionFee": 2.00,
          "percentageFee": 0
        }
      }
    ]
  }
}
```

## Implementation Details

### Database Schema Enhancement

```sql
-- Add mode configuration to merchants table
ALTER TABLE merchants ADD COLUMN operation_mode VARCHAR(20) DEFAULT 'FULL_PROCESSOR';
ALTER TABLE merchants ADD COLUMN fee_structure JSONB;
ALTER TABLE merchants ADD COLUMN bank_config JSONB;
ALTER TABLE merchants ADD COLUMN settlement_config JSONB;

-- Create fee structure table
CREATE TABLE merchant_fee_structures (
    id BIGSERIAL PRIMARY KEY,
    merchant_id BIGINT NOT NULL REFERENCES merchants(id),
    mode VARCHAR(20) NOT NULL,
    setup_fee DECIMAL(10,2) DEFAULT 0,
    monthly_fee DECIMAL(10,2) DEFAULT 0,
    transaction_fee DECIMAL(10,2) DEFAULT 0,
    percentage_fee DECIMAL(5,2) DEFAULT 0,
    volume_tiers JSONB,
    effective_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    effective_until TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create settlement configuration table
CREATE TABLE settlement_configurations (
    id BIGSERIAL PRIMARY KEY,
    merchant_id BIGINT NOT NULL REFERENCES merchants(id),
    settlement_mode VARCHAR(20) NOT NULL, -- 'DIRECT', 'POOLED', 'ESCROW'
    settlement_cycle VARCHAR(10) NOT NULL, -- 'T+0', 'T+1', 'T+2', 'WEEKLY', 'MONTHLY'
    bank_account_number VARCHAR(20),
    bank_ifsc_code VARCHAR(11),
    bank_account_holder_name VARCHAR(100),
    auto_settlement BOOLEAN DEFAULT TRUE,
    minimum_settlement_amount DECIMAL(10,2) DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Enhanced Merchant Entity

```java
@Entity
@Table(name = "merchants")
public class Merchant {
    // ... existing fields ...
    
    @Enumerated(EnumType.STRING)
    @Column(name = "operation_mode")
    private OperationMode operationMode = OperationMode.FULL_PROCESSOR;
    
    @Column(name = "fee_structure", columnDefinition = "jsonb")
    private String feeStructure;
    
    @Column(name = "bank_config", columnDefinition = "jsonb")
    private String bankConfig;
    
    @Column(name = "settlement_config", columnDefinition = "jsonb")
    private String settlementConfig;
    
    public enum OperationMode {
        GATEWAY_ONLY,
        FULL_PROCESSOR,
        HYBRID
    }
    
    // ... getters and setters ...
}
```

### Payment Processing Logic

```java
@Service
public class PaymentModeService {
    
    @Autowired
    private MerchantRepository merchantRepository;
    
    @Autowired
    private BankApiService bankApiService;
    
    @Autowired
    private InternalProcessorService internalProcessorService;
    
    public PaymentResponse processPayment(Long merchantId, PaymentRequest request) {
        Merchant merchant = merchantRepository.findById(merchantId)
            .orElseThrow(() -> new RuntimeException("Merchant not found"));
        
        switch (merchant.getOperationMode()) {
            case GATEWAY_ONLY:
                return processAsGateway(merchant, request);
            case FULL_PROCESSOR:
                return processAsProcessor(merchant, request);
            case HYBRID:
                return processAsHybrid(merchant, request);
            default:
                throw new RuntimeException("Invalid operation mode");
        }
    }
    
    private PaymentResponse processAsGateway(Merchant merchant, PaymentRequest request) {
        // Use merchant's bank API directly
        BankConfig bankConfig = parseBankConfig(merchant.getBankConfig());
        
        BankPaymentRequest bankRequest = BankPaymentRequest.builder()
            .merchantBankId(bankConfig.getMerchantId())
            .apiKey(bankConfig.getApiKey())
            .amount(request.getAmount())
            .transactionId(generateTransactionId())
            .build();
        
        BankPaymentResponse bankResponse = bankApiService.initiatePayment(bankRequest);
        
        // Create payment record but don't handle money
        Payment payment = createPaymentRecord(request, bankResponse);
        payment.setProcessingMode(ProcessingMode.GATEWAY_ONLY);
        payment.setDirectSettlement(true);
        
        return new PaymentResponse(payment);
    }
    
    private PaymentResponse processAsProcessor(Merchant merchant, PaymentRequest request) {
        // Use our internal processing system
        Payment payment = createPaymentRecord(request, null);
        payment.setProcessingMode(ProcessingMode.FULL_PROCESSOR);
        payment.setDirectSettlement(false);
        
        // Process through our system
        ProcessorResponse response = internalProcessorService.processPayment(payment);
        
        // Update payment with processor response
        payment.setBankReference(response.getBankReference());
        payment.setStatus(response.getStatus());
        
        return new PaymentResponse(payment);
    }
    
    private PaymentResponse processAsHybrid(Merchant merchant, PaymentRequest request) {
        HybridConfig hybridConfig = parseHybridConfig(merchant.getBankConfig());
        
        // Determine mode based on rules
        OperationMode modeForTransaction = determineMode(hybridConfig, request);
        
        if (modeForTransaction == OperationMode.GATEWAY_ONLY) {
            return processAsGateway(merchant, request);
        } else {
            return processAsProcessor(merchant, request);
        }
    }
}
```

### Fee Calculation Service

```java
@Service
public class FeeCalculationService {
    
    public FeeBreakdown calculateFees(Merchant merchant, BigDecimal amount) {
        FeeStructure feeStructure = parseFeeStructure(merchant.getFeeStructure());
        
        FeeBreakdown breakdown = new FeeBreakdown();
        breakdown.setTransactionAmount(amount);
        
        // Calculate based on operation mode
        switch (merchant.getOperationMode()) {
            case GATEWAY_ONLY:
                breakdown.setTransactionFee(feeStructure.getTransactionFee());
                breakdown.setPercentageFee(BigDecimal.ZERO);
                break;
                
            case FULL_PROCESSOR:
                breakdown.setTransactionFee(feeStructure.getTransactionFee());
                breakdown.setPercentageFee(
                    amount.multiply(feeStructure.getPercentageFee())
                          .divide(new BigDecimal("100"))
                );
                break;
                
            case HYBRID:
                // Apply rules based on amount/volume
                breakdown = calculateHybridFees(feeStructure, amount);
                break;
        }
        
        breakdown.setTotalFee(
            breakdown.getTransactionFee().add(breakdown.getPercentageFee())
        );
        
        breakdown.setNetAmount(
            amount.subtract(breakdown.getTotalFee())
        );
        
        return breakdown;
    }
}
```

## Merchant Dashboard Configuration

### Mode Selection Interface

```jsx
const MerchantModeSelector = () => {
  const [selectedMode, setSelectedMode] = useState('FULL_PROCESSOR');
  const [feeEstimate, setFeeEstimate] = useState(null);

  const modes = [
    {
      id: 'GATEWAY_ONLY',
      name: 'Payment Gateway Only',
      description: 'Use your own bank account and processor',
      pros: [
        'Lower fees (no percentage)',
        'Direct settlement to your account',
        'Full control over funds',
        'Better for high-volume merchants'
      ],
      cons: [
        'Requires existing bank relationship',
        'More complex setup',
        'You handle compliance',
        'Technical integration needed'
      ],
      pricing: {
        setupFee: 0,
        monthlyFee: 2000,
        transactionFee: 2,
        percentageFee: 0
      }
    },
    {
      id: 'FULL_PROCESSOR',
      name: 'Full Payment Processor',
      description: 'We handle everything including money movement',
      pros: [
        'Quick setup (no bank account needed)',
        'We handle all compliance',
        'Simple integration',
        'Perfect for startups'
      ],
      cons: [
        'Higher fees (includes percentage)',
        'Settlement through our system',
        'Less control over funds',
        'Volume limits may apply'
      ],
      pricing: {
        setupFee: 5000,
        monthlyFee: 1000,
        transactionFee: 2,
        percentageFee: 1.5
      }
    },
    {
      id: 'HYBRID',
      name: 'Hybrid Mode',
      description: 'Flexible combination based on transaction size',
      pros: [
        'Best of both worlds',
        'Optimized fees based on amount',
        'Scalable as you grow',
        'Flexible configuration'
      ],
      cons: [
        'More complex fee structure',
        'Requires both setups',
        'May need dual compliance'
      ],
      pricing: {
        setupFee: 2500,
        monthlyFee: 1500,
        transactionFee: 2,
        percentageFee: 'Variable'
      }
    }
  ];

  return (
    <div className="mode-selector">
      <h2>Choose Your Payment Processing Mode</h2>
      
      {modes.map(mode => (
        <div key={mode.id} className={`mode-card ${selectedMode === mode.id ? 'selected' : ''}`}>
          <div className="mode-header">
            <input
              type="radio"
              name="mode"
              value={mode.id}
              checked={selectedMode === mode.id}
              onChange={(e) => setSelectedMode(e.target.value)}
            />
            <h3>{mode.name}</h3>
          </div>
          
          <p>{mode.description}</p>
          
          <div className="pros-cons">
            <div className="pros">
              <h4>✅ Advantages</h4>
              <ul>
                {mode.pros.map((pro, index) => (
                  <li key={index}>{pro}</li>
                ))}
              </ul>
            </div>
            
            <div className="cons">
              <h4>⚠️ Considerations</h4>
              <ul>
                {mode.cons.map((con, index) => (
                  <li key={index}>{con}</li>
                ))}
              </ul>
            </div>
          </div>
          
          <div className="pricing">
            <h4>💰 Pricing</h4>
            <div className="pricing-details">
              <span>Setup: ₹{mode.pricing.setupFee}</span>
              <span>Monthly: ₹{mode.pricing.monthlyFee}</span>
              <span>Per Transaction: ₹{mode.pricing.transactionFee}</span>
              <span>Percentage: {mode.pricing.percentageFee}%</span>
            </div>
          </div>
        </div>
      ))}
      
      <FeeCalculator selectedMode={selectedMode} />
    </div>
  );
};
```

### Fee Calculator Component

```jsx
const FeeCalculator = ({ selectedMode }) => {
  const [monthlyVolume, setMonthlyVolume] = useState(100000);
  const [avgTransactionSize, setAvgTransactionSize] = useState(500);
  const [estimate, setEstimate] = useState(null);

  useEffect(() => {
    calculateEstimate();
  }, [selectedMode, monthlyVolume, avgTransactionSize]);

  const calculateEstimate = () => {
    const transactions = monthlyVolume / avgTransactionSize;
    
    let fees = {};
    
    switch (selectedMode) {
      case 'GATEWAY_ONLY':
        fees = {
          setupFee: 0,
          monthlyFee: 2000,
          transactionFees: transactions * 2,
          percentageFees: 0,
          total: 2000 + (transactions * 2)
        };
        break;
        
      case 'FULL_PROCESSOR':
        fees = {
          setupFee: 5000,
          monthlyFee: 1000,
          transactionFees: transactions * 2,
          percentageFees: monthlyVolume * 0.015,
          total: 1000 + (transactions * 2) + (monthlyVolume * 0.015)
        };
        break;
        
      case 'HYBRID':
        // Assume 70% small transactions (processor), 30% large (gateway)
        const smallTransactions = transactions * 0.7;
        const largeTransactions = transactions * 0.3;
        const smallVolume = monthlyVolume * 0.3;
        
        fees = {
          setupFee: 2500,
          monthlyFee: 1500,
          transactionFees: transactions * 2,
          percentageFees: smallVolume * 0.015,
          total: 1500 + (transactions * 2) + (smallVolume * 0.015)
        };
        break;
    }
    
    setEstimate(fees);
  };

  return (
    <div className="fee-calculator">
      <h3>💡 Monthly Fee Estimate</h3>
      
      <div className="inputs">
        <div>
          <label>Monthly Volume (₹)</label>
          <input
            type="number"
            value={monthlyVolume}
            onChange={(e) => setMonthlyVolume(Number(e.target.value))}
          />
        </div>
        
        <div>
          <label>Average Transaction Size (₹)</label>
          <input
            type="number"
            value={avgTransactionSize}
            onChange={(e) => setAvgTransactionSize(Number(e.target.value))}
          />
        </div>
      </div>
      
      {estimate && (
        <div className="estimate-breakdown">
          <div>Monthly Fee: ₹{estimate.monthlyFee.toLocaleString()}</div>
          <div>Transaction Fees: ₹{estimate.transactionFees.toLocaleString()}</div>
          <div>Percentage Fees: ₹{estimate.percentageFees.toLocaleString()}</div>
          <div className="total">Total Monthly Cost: ₹{estimate.total.toLocaleString()}</div>
          <div className="effective-rate">
            Effective Rate: {((estimate.total / monthlyVolume) * 100).toFixed(2)}%
          </div>
        </div>
      )}
    </div>
  );
};
```

## API Endpoints for Mode Management

### Merchant Configuration API

```java
@RestController
@RequestMapping("/api/merchant/config")
public class MerchantConfigController {
    
    @PostMapping("/mode")
    public ResponseEntity<ApiResponse<String>> updateOperationMode(
            @RequestBody ModeUpdateRequest request,
            @RequestHeader("Authorization") String token) {
        
        Long merchantId = jwtUtil.extractUserId(token.replace("Bearer ", ""));
        
        merchantConfigService.updateOperationMode(merchantId, request);
        
        return ResponseEntity.ok(ApiResponse.success("Operation mode updated successfully"));
    }
    
    @GetMapping("/fees/estimate")
    public ResponseEntity<ApiResponse<FeeEstimate>> getFeeEstimate(
            @RequestParam OperationMode mode,
            @RequestParam BigDecimal monthlyVolume,
            @RequestParam BigDecimal avgTransactionSize) {
        
        FeeEstimate estimate = feeCalculationService.calculateEstimate(
            mode, monthlyVolume, avgTransactionSize
        );
        
        return ResponseEntity.ok(ApiResponse.success(estimate));
    }
}
```

## Migration Between Modes

### Automatic Migration Service

```java
@Service
public class MerchantMigrationService {
    
    public void migrateToGatewayMode(Long merchantId, BankConfig bankConfig) {
        Merchant merchant = merchantRepository.findById(merchantId)
            .orElseThrow(() -> new RuntimeException("Merchant not found"));
        
        // Validate bank configuration
        validateBankConfig(bankConfig);
        
        // Test bank connectivity
        testBankConnection(bankConfig);
        
        // Update merchant configuration
        merchant.setOperationMode(OperationMode.GATEWAY_ONLY);
        merchant.setBankConfig(objectMapper.writeValueAsString(bankConfig));
        
        // Update fee structure
        FeeStructure gatewayFees = createGatewayFeeStructure();
        merchant.setFeeStructure(objectMapper.writeValueAsString(gatewayFees));
        
        merchantRepository.save(merchant);
        
        // Send notification
        notificationService.sendModeChangeNotification(merchant, OperationMode.GATEWAY_ONLY);
    }
}
```

This comprehensive differentiation allows merchants to choose the model that best fits their business needs, technical capabilities, and growth stage. The system can seamlessly handle both modes with appropriate fee structures and processing logic.