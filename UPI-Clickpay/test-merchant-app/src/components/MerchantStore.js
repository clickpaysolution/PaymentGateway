import React, { useState } from 'react';
import axios from 'axios';

const MerchantStore = () => {
  const [customAmount, setCustomAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  // Test merchant credentials (these would be provided by the payment gateway)
  const MERCHANT_API_KEY = 'test_api_key_123'; // This should be stored securely
  const PAYMENT_GATEWAY_URL = 'http://localhost:8080'; // Your payment gateway URL

  const products = [
    {
      id: 1,
      name: 'Premium Headphones',
      description: 'High-quality wireless headphones with noise cancellation',
      price: 2999,
      emoji: '🎧'
    },
    {
      id: 2,
      name: 'Smart Watch',
      description: 'Feature-rich smartwatch with health monitoring',
      price: 8999,
      emoji: '⌚'
    },
    {
      id: 3,
      name: 'Wireless Speaker',
      description: 'Portable Bluetooth speaker with premium sound',
      price: 1499,
      emoji: '🔊'
    },
    {
      id: 4,
      name: 'Gaming Mouse',
      description: 'High-precision gaming mouse with RGB lighting',
      price: 1299,
      emoji: '🖱️'
    },
    {
      id: 5,
      name: 'Mechanical Keyboard',
      description: 'Professional mechanical keyboard for gaming and work',
      price: 3499,
      emoji: '⌨️'
    },
    {
      id: 6,
      name: 'Phone Case',
      description: 'Protective case with premium materials',
      price: 599,
      emoji: '📱'
    }
  ];

  const initiatePayment = async (amount, description = 'Product Purchase') => {
    setLoading(true);
    setMessage('');

    try {
      // Step 1: Create payment with your payment gateway
      const paymentRequest = {
        amount: parseFloat(amount),
        paymentMethod: 'UPI_QR',
        description: description,
        callbackUrl: `${window.location.origin}/payment-success`,
        currency: 'INR'
      };

      console.log('Creating payment with request:', paymentRequest);

      const response = await axios.post('/api/test-merchant/create-payment', paymentRequest, {
        headers: {
          'Authorization': `Bearer ${MERCHANT_API_KEY}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.data.success) {
        const paymentData = response.data.data;
        console.log('Payment created successfully:', paymentData);
        
        // Step 2: Redirect to payment gateway page
        const paymentUrl = `${PAYMENT_GATEWAY_URL}/payment/${paymentData.transactionId}`;
        window.location.href = paymentUrl;
      } else {
        setMessage('Failed to create payment: ' + response.data.error);
      }
    } catch (error) {
      console.error('Payment creation error:', error);
      setMessage('Error creating payment: ' + (error.response?.data?.error || error.message));
    } finally {
      setLoading(false);
    }
  };

  const handleProductPurchase = (product) => {
    initiatePayment(product.price, `Purchase: ${product.name}`);
  };

  const handleCustomAmountPayment = () => {
    if (!customAmount || parseFloat(customAmount) <= 0) {
      setMessage('Please enter a valid amount');
      return;
    }
    initiatePayment(customAmount, 'Custom Amount Payment');
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR'
    }).format(amount);
  };

  return (
    <div className="container">
      {/* Header */}
      <div className="header">
        <h1>🛍️ Test Merchant Store</h1>
        <p>Demo store showcasing Payment Gateway Integration</p>
        <p><strong>Merchant ID:</strong> testmerchant | <strong>Integration:</strong> UPI Payment Gateway</p>
      </div>

      {/* Message Display */}
      {message && (
        <div className={message.includes('Error') || message.includes('Failed') ? 'error-message' : 'success-message'}>
          {message}
        </div>
      )}

      {/* Products Grid */}
      <div className="store-grid">
        {products.map(product => (
          <div key={product.id} className="product-card">
            <div className="product-image">
              {product.emoji}
            </div>
            <div className="product-title">{product.name}</div>
            <div className="product-description">{product.description}</div>
            <div className="product-price">{formatCurrency(product.price)}</div>
            <button 
              className="buy-button"
              onClick={() => handleProductPurchase(product)}
              disabled={loading}
            >
              {loading ? <span className="loading"></span> : 'Buy with UPI'}
            </button>
          </div>
        ))}
      </div>

      {/* Custom Amount Section */}
      <div className="custom-amount-section">
        <h2>💰 Pay Custom Amount</h2>
        <p>Enter any amount to test the payment gateway</p>
        
        <div className="amount-input-group">
          <span className="currency-symbol">₹</span>
          <input
            type="number"
            className="amount-input"
            placeholder="Enter amount"
            value={customAmount}
            onChange={(e) => setCustomAmount(e.target.value)}
            min="1"
            step="0.01"
          />
        </div>

        <div className="payment-methods">
          <button 
            className="payment-method-btn upi"
            onClick={handleCustomAmountPayment}
            disabled={loading || !customAmount}
          >
            {loading ? <span className="loading"></span> : '📱 Pay with UPI'}
          </button>
        </div>
      </div>

      {/* Integration Information */}
      <div className="integration-info">
        <h3>🔧 Integration Details</h3>
        <p>This demo shows how merchants can integrate with our payment gateway:</p>
        
        <div className="api-endpoint">
          <strong>API Endpoint:</strong> POST /api/payments/create
        </div>

        <div className="code-block">
{`// Sample Integration Code
const paymentRequest = {
  amount: 100.00,
  paymentMethod: 'UPI_QR',
  description: 'Product Purchase',
  callbackUrl: 'https://yoursite.com/success',
  currency: 'INR'
};

const response = await fetch('/api/payments/create', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_API_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(paymentRequest)
});

const payment = await response.json();
// Redirect to: /payment/\${payment.data.transactionId}`}
        </div>

        <h4>🔄 Payment Flow:</h4>
        <ol>
          <li>Customer selects product/enters amount</li>
          <li>Merchant calls payment gateway API</li>
          <li>Customer redirected to payment page</li>
          <li>Customer completes UPI payment</li>
          <li>Payment status updated in real-time</li>
          <li>Customer redirected back to merchant</li>
        </ol>

        <h4>💳 Supported Payment Methods:</h4>
        <ul>
          <li>UPI QR Code (All UPI apps)</li>
          <li>UPI Intent (PhonePe, Google Pay, Paytm, etc.)</li>
          <li>UPI ID (Direct payment requests)</li>
        </ul>

        <h4>🔐 Security Features:</h4>
        <ul>
          <li>JWT-based API authentication</li>
          <li>Secure webhook callbacks</li>
          <li>Real-time transaction status</li>
          <li>Fraud detection and prevention</li>
        </ul>
      </div>
    </div>
  );
};

export default MerchantStore;