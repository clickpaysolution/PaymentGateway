import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import axios from 'axios';
import QRCode from 'react-qr-code';

const PaymentPage = () => {
  const { transactionId } = useParams();
  const [payment, setPayment] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedUPI, setSelectedUPI] = useState('');
  const [customUPI, setCustomUPI] = useState('');

  const upiProviders = [
    { id: 'phonepe', name: 'PhonePe', icon: '📱' },
    { id: 'googlepay', name: 'Google Pay', icon: '💳' },
    { id: 'paytm', name: 'Paytm', icon: '💰' },
    { id: 'amazonpay', name: 'Amazon Pay', icon: '🛒' },
    { id: 'bhim', name: 'BHIM UPI', icon: '🏛️' }
  ];

  useEffect(() => {
    fetchPaymentDetails();
    
    // Poll for payment status every 5 seconds
    const interval = setInterval(fetchPaymentDetails, 5000);
    return () => clearInterval(interval);
  }, [transactionId]);

  const fetchPaymentDetails = async () => {
    try {
      const response = await axios.get(`/api/payments/status/${transactionId}`);
      if (response.data.success) {
        setPayment(response.data.data);
        
        // Stop polling if payment is completed
        if (response.data.data.status !== 'PENDING') {
          setLoading(false);
        }
      }
    } catch (error) {
      setError('Payment not found');
    } finally {
      setLoading(false);
    }
  };

  const handleUPIAppClick = (provider) => {
    const upiUrl = generateUPIUrl();
    
    // Try to open UPI app
    window.location.href = upiUrl;
    
    // Fallback: show instructions
    setTimeout(() => {
      alert(`Please open ${provider.name} app and complete the payment`);
    }, 1000);
  };

  const handleCustomUPISubmit = async (e) => {
    e.preventDefault();
    if (!customUPI) return;

    try {
      // Send payment request to custom UPI ID
      await axios.post('/api/payments/upi-request', {
        transactionId,
        upiId: customUPI
      });
      
      alert(`Payment request sent to ${customUPI}. Please check your UPI app.`);
    } catch (error) {
      alert('Failed to send payment request');
    }
  };

  const generateUPIUrl = () => {
    if (!payment) return '';
    
    return `upi://pay?pa=merchant@upi&am=${payment.amount}&tr=${payment.transactionId}&tn=${payment.description || 'Payment'}&cu=INR`;
  };

  const formatAmount = (amount) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR'
    }).format(amount);
  };

  if (loading) {
    return (
      <div className="container">
        <div className="card text-center">
          <h2>Loading Payment Details...</h2>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container">
        <div className="card text-center">
          <h2>Error</h2>
          <p>{error}</p>
        </div>
      </div>
    );
  }

  if (payment.status === 'SUCCESS') {
    return (
      <div className="container">
        <div className="card text-center">
          <h2 style={{ color: '#28a745' }}>✅ Payment Successful!</h2>
          <p>Transaction ID: {payment.transactionId}</p>
          <p>Amount: {formatAmount(payment.amount)}</p>
          <p>Thank you for your payment!</p>
        </div>
      </div>
    );
  }

  if (payment.status === 'FAILED') {
    return (
      <div className="container">
        <div className="card text-center">
          <h2 style={{ color: '#dc3545' }}>❌ Payment Failed</h2>
          <p>Transaction ID: {payment.transactionId}</p>
          <p>Please try again or contact support.</p>
          <button 
            className="btn btn-primary"
            onClick={() => window.location.reload()}
          >
            Retry Payment
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="container">
      <div className="card" style={{ maxWidth: '500px', margin: '0 auto' }}>
        <div className="text-center">
          <h2>Complete Your Payment</h2>
          <div style={{ 
            fontSize: '2rem', 
            fontWeight: 'bold', 
            color: '#007bff',
            margin: '20px 0'
          }}>
            {formatAmount(payment.amount)}
          </div>
          <p>Transaction ID: {payment.transactionId}</p>
        </div>

        {/* UPI App Options */}
        <div style={{ marginBottom: '30px' }}>
          <h3>Pay with UPI Apps</h3>
          <div className="grid grid-2" style={{ gap: '10px' }}>
            {upiProviders.map((provider) => (
              <div
                key={provider.id}
                className="card"
                style={{ 
                  cursor: 'pointer',
                  textAlign: 'center',
                  padding: '15px',
                  border: '2px solid #ddd',
                  transition: 'all 0.3s'
                }}
                onClick={() => handleUPIAppClick(provider)}
                onMouseOver={(e) => e.target.style.borderColor = '#007bff'}
                onMouseOut={(e) => e.target.style.borderColor = '#ddd'}
              >
                <div style={{ fontSize: '2rem' }}>{provider.icon}</div>
                <div>{provider.name}</div>
              </div>
            ))}
          </div>
        </div>

        {/* QR Code */}
        <div style={{ marginBottom: '30px', textAlign: 'center' }}>
          <h3>Scan QR Code</h3>
          <p>Scan with any UPI app to pay</p>
          <div style={{ 
            display: 'inline-block',
            padding: '20px',
            backgroundColor: 'white',
            border: '1px solid #ddd',
            borderRadius: '8px'
          }}>
            <QRCode 
              value={generateUPIUrl()}
              size={200}
            />
          </div>
        </div>

        {/* Custom UPI ID */}
        <div>
          <h3>Pay with UPI ID</h3>
          <form onSubmit={handleCustomUPISubmit}>
            <div className="form-group">
              <input
                type="text"
                className="form-control"
                placeholder="Enter UPI ID (e.g., user@paytm)"
                value={customUPI}
                onChange={(e) => setCustomUPI(e.target.value)}
              />
            </div>
            <button 
              type="submit" 
              className="btn btn-success"
              style={{ width: '100%' }}
            >
              Send Payment Request
            </button>
          </form>
        </div>

        {/* Payment Status */}
        <div style={{ 
          marginTop: '30px', 
          padding: '15px',
          backgroundColor: '#fff3cd',
          borderRadius: '5px',
          textAlign: 'center'
        }}>
          <p><strong>Status:</strong> {payment.status}</p>
          <p>This page will automatically update when payment is completed.</p>
        </div>
      </div>
    </div>
  );
};

export default PaymentPage;