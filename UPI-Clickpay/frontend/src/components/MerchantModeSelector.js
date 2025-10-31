import React, { useState, useEffect } from 'react';
import axios from 'axios';

const MerchantModeSelector = () => {
  const [selectedMode, setSelectedMode] = useState('FULL_PROCESSOR');
  const [selectedBank, setSelectedBank] = useState('AXIS');
  const [currentConfig, setCurrentConfig] = useState(null);
  const [feeEstimate, setFeeEstimate] = useState(null);
  const [monthlyVolume, setMonthlyVolume] = useState(100000);
  const [avgTransactionSize, setAvgTransactionSize] = useState(500);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const modes = {
    GATEWAY_ONLY: {
      name: 'Payment Gateway Only',
      description: 'Use your own bank account and processor',
      icon: '🔗',
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
    FULL_PROCESSOR: {
      name: 'Full Payment Processor',
      description: 'We handle everything including money movement',
      icon: '💳',
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
    HYBRID: {
      name: 'Hybrid Mode',
      description: 'Flexible combination based on transaction size',
      icon: '⚡',
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
  };

  useEffect(() => {
    fetchCurrentConfig();
  }, []);

  useEffect(() => {
    calculateFeeEstimate();
  }, [selectedMode, monthlyVolume, avgTransactionSize]);

  const fetchCurrentConfig = async () => {
    try {
      const response = await axios.get('/api/merchant/config/current');
      if (response.data.success) {
        setCurrentConfig(response.data.data);
        setSelectedMode(response.data.data.operationMode || 'FULL_PROCESSOR');
        setSelectedBank(response.data.data.preferredBank || 'AXIS');
      }
    } catch (error) {
      console.error('Error fetching config:', error);
    }
  };

  const calculateFeeEstimate = async () => {
    try {
      const response = await axios.get('/api/merchant/config/fee-estimate', {
        params: {
          mode: selectedMode,
          monthlyVolume,
          avgTransactionSize
        }
      });
      
      if (response.data.success) {
        setFeeEstimate(response.data.data);
      }
    } catch (error) {
      console.error('Error calculating estimate:', error);
    }
  };

  const handleModeUpdate = async () => {
    setLoading(true);
    setMessage('');

    try {
      const configRequest = {
        operationMode: selectedMode,
        preferredBank: selectedBank,
        // Add default configurations based on mode
        feeStructure: null, // Will use defaults
        bankConfig: selectedMode === 'GATEWAY_ONLY' ? {
          provider: selectedBank,
          directSettlement: true
        } : null,
        settlementConfig: {
          settlementMode: selectedMode === 'GATEWAY_ONLY' ? 'DIRECT' : 'POOLED',
          settlementCycle: 'T+1',
          autoSettlement: true,
          minimumSettlementAmount: 100
        }
      };

      const response = await axios.post('/api/merchant/config/update', configRequest);
      
      if (response.data.success) {
        setMessage('Configuration updated successfully!');
        fetchCurrentConfig();
      } else {
        setMessage('Failed to update configuration: ' + response.data.error);
      }
    } catch (error) {
      setMessage('Error updating configuration: ' + (error.response?.data?.error || error.message));
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR'
    }).format(amount);
  };

  return (
    <div className="container">
      <div className="card">
        <h2>🔧 Payment Processing Configuration</h2>
        <p>Choose how you want to process payments with our platform</p>

        {currentConfig && (
          <div className="alert alert-success">
            <strong>Current Mode:</strong> {modes[currentConfig.operationMode]?.name || currentConfig.operationMode}
          </div>
        )}

        {message && (
          <div className={`alert ${message.includes('success') ? 'alert-success' : 'alert-danger'}`}>
            {message}
          </div>
        )}

        {/* Bank Selection */}
        <div className="card" style={{ marginBottom: '30px' }}>
          <h3>🏦 Preferred Bank Partner</h3>
          <p>Select your preferred bank for payment processing (default: Axis Bank)</p>
          
          <div className="grid grid-4" style={{ gap: '15px' }}>
            {[
              { code: 'AXIS', name: 'Axis Bank', logo: '🏦', color: '#8B0000' },
              { code: 'HDFC', name: 'HDFC Bank', logo: '🏛️', color: '#004C8F' },
              { code: 'ICICI', name: 'ICICI Bank', logo: '🏢', color: '#F37021' },
              { code: 'KOTAK', name: 'Kotak Bank', logo: '🏪', color: '#ED1C24' }
            ].map((bank) => (
              <div 
                key={bank.code}
                className={`bank-card ${selectedBank === bank.code ? 'selected' : ''}`}
                style={{
                  border: selectedBank === bank.code ? `2px solid ${bank.color}` : '1px solid #ddd',
                  borderRadius: '8px',
                  padding: '15px',
                  cursor: 'pointer',
                  textAlign: 'center',
                  transition: 'all 0.3s ease',
                  backgroundColor: selectedBank === bank.code ? `${bank.color}10` : 'white'
                }}
                onClick={() => setSelectedBank(bank.code)}
              >
                <div style={{ fontSize: '32px', marginBottom: '8px' }}>{bank.logo}</div>
                <h4 style={{ margin: '0 0 5px 0', color: bank.color }}>{bank.name}</h4>
                <input
                  type="radio"
                  name="bank"
                  value={bank.code}
                  checked={selectedBank === bank.code}
                  onChange={(e) => setSelectedBank(e.target.value)}
                  style={{ marginTop: '5px' }}
                />
              </div>
            ))}
          </div>
          
          <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#fff3cd', borderRadius: '4px' }}>
            <small>
              <strong>Note:</strong> Your preferred bank will be used for all payment processing. 
              You can change this later, but it may require re-verification of your merchant account.
            </small>
          </div>
        </div>

        {/* Mode Selection */}
        <div className="grid grid-3">
          {Object.entries(modes).map(([modeKey, mode]) => (
            <div 
              key={modeKey} 
              className={`mode-card ${selectedMode === modeKey ? 'selected' : ''}`}
              style={{
                border: selectedMode === modeKey ? '2px solid #007bff' : '1px solid #ddd',
                borderRadius: '8px',
                padding: '20px',
                cursor: 'pointer',
                transition: 'all 0.3s ease'
              }}
              onClick={() => setSelectedMode(modeKey)}
            >
              <div style={{ display: 'flex', alignItems: 'center', marginBottom: '10px' }}>
                <input
                  type="radio"
                  name="mode"
                  value={modeKey}
                  checked={selectedMode === modeKey}
                  onChange={(e) => setSelectedMode(e.target.value)}
                  style={{ marginRight: '10px' }}
                />
                <span style={{ fontSize: '24px', marginRight: '10px' }}>{mode.icon}</span>
                <h3 style={{ margin: 0 }}>{mode.name}</h3>
              </div>
              
              <p style={{ color: '#666', marginBottom: '15px' }}>{mode.description}</p>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
                <div>
                  <h4 style={{ color: '#28a745', fontSize: '14px' }}>✅ Advantages</h4>
                  <ul style={{ fontSize: '12px', paddingLeft: '15px' }}>
                    {mode.pros.map((pro, index) => (
                      <li key={index}>{pro}</li>
                    ))}
                  </ul>
                </div>
                
                <div>
                  <h4 style={{ color: '#ffc107', fontSize: '14px' }}>⚠️ Considerations</h4>
                  <ul style={{ fontSize: '12px', paddingLeft: '15px' }}>
                    {mode.cons.map((con, index) => (
                      <li key={index}>{con}</li>
                    ))}
                  </ul>
                </div>
              </div>
              
              <div style={{ marginTop: '15px', padding: '10px', backgroundColor: '#f8f9fa', borderRadius: '4px' }}>
                <h4 style={{ fontSize: '14px', marginBottom: '5px' }}>💰 Pricing</h4>
                <div style={{ fontSize: '12px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '5px' }}>
                  <span>Setup: {formatCurrency(mode.pricing.setupFee)}</span>
                  <span>Monthly: {formatCurrency(mode.pricing.monthlyFee)}</span>
                  <span>Per Txn: {formatCurrency(mode.pricing.transactionFee)}</span>
                  <span>Percentage: {mode.pricing.percentageFee}%</span>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Fee Calculator */}
        <div className="card" style={{ marginTop: '30px' }}>
          <h3>💡 Monthly Fee Calculator</h3>
          
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginBottom: '20px' }}>
            <div className="form-group">
              <label>Monthly Volume (₹)</label>
              <input
                type="number"
                className="form-control"
                value={monthlyVolume}
                onChange={(e) => setMonthlyVolume(Number(e.target.value))}
                min="1000"
                step="1000"
              />
            </div>
            
            <div className="form-group">
              <label>Average Transaction Size (₹)</label>
              <input
                type="number"
                className="form-control"
                value={avgTransactionSize}
                onChange={(e) => setAvgTransactionSize(Number(e.target.value))}
                min="1"
                step="10"
              />
            </div>
          </div>
          
          {feeEstimate && (
            <div style={{ 
              padding: '20px', 
              backgroundColor: '#f8f9fa', 
              borderRadius: '8px',
              border: '1px solid #dee2e6'
            }}>
              <h4>Estimated Monthly Costs for {modes[selectedMode].name}</h4>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px' }}>
                <div>
                  <strong>Monthly Fee:</strong><br />
                  {formatCurrency(feeEstimate.monthlyFee)}
                </div>
                <div>
                  <strong>Transaction Fees:</strong><br />
                  {formatCurrency(feeEstimate.transactionFees)}
                  <small> ({feeEstimate.transactions} transactions)</small>
                </div>
                <div>
                  <strong>Percentage Fees:</strong><br />
                  {formatCurrency(feeEstimate.percentageFees)}
                </div>
                <div style={{ 
                  padding: '10px', 
                  backgroundColor: '#007bff', 
                  color: 'white', 
                  borderRadius: '4px',
                  textAlign: 'center'
                }}>
                  <strong>Total Monthly Cost:</strong><br />
                  {formatCurrency(feeEstimate.totalMonthlyFee)}
                </div>
              </div>
              <div style={{ marginTop: '15px', textAlign: 'center' }}>
                <strong>Effective Rate: {feeEstimate.effectiveRate}% of volume</strong>
              </div>
            </div>
          )}
        </div>

        {/* Update Button */}
        <div style={{ textAlign: 'center', marginTop: '30px' }}>
          <button
            className="btn btn-primary"
            onClick={handleModeUpdate}
            disabled={loading || (currentConfig && currentConfig.operationMode === selectedMode)}
            style={{ padding: '12px 30px', fontSize: '16px' }}
          >
            {loading ? 'Updating...' : 
             currentConfig && currentConfig.operationMode === selectedMode ? 
             'Current Configuration' : 
             `Switch to ${modes[selectedMode].name}`}
          </button>
        </div>

        {/* Additional Information */}
        <div className="card" style={{ marginTop: '30px', backgroundColor: '#e3f2fd' }}>
          <h4>📋 What happens after switching modes?</h4>
          <ul>
            <li><strong>Gateway Mode:</strong> You'll need to provide your bank API credentials and account details</li>
            <li><strong>Processor Mode:</strong> We'll handle KYC verification and set up your merchant account</li>
            <li><strong>Hybrid Mode:</strong> You'll get the flexibility to use both modes based on transaction rules</li>
          </ul>
          
          <p><strong>Note:</strong> Mode changes may take 24-48 hours to fully activate. During this time, your current mode will continue to work.</p>
        </div>
      </div>
    </div>
  );
};

export default MerchantModeSelector;