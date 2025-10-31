import React, { useEffect, useState } from 'react';
import { useSearchParams, Link } from 'react-router-dom';

const PaymentFailed = () => {
  const [searchParams] = useSearchParams();
  const [paymentDetails, setPaymentDetails] = useState(null);

  const transactionId = searchParams.get('transactionId');
  const amount = searchParams.get('amount');
  const error = searchParams.get('error');

  useEffect(() => {
    if (transactionId) {
      setPaymentDetails({
        transactionId,
        amount: amount || '0',
        error: error || 'Payment was declined',
        timestamp: new Date().toLocaleString()
      });
    }
  }, [transactionId, amount, error]);

  const commonFailureReasons = [
    'Insufficient funds in account',
    'Invalid UPI PIN entered',
    'Transaction timeout',
    'Bank server temporarily unavailable',
    'Daily transaction limit exceeded',
    'UPI app not responding'
  ];

  return (
    <div className="container">
      <div style={{
        background: 'white',
        borderRadius: '15px',
        padding: '40px',
        textAlign: 'center',
        boxShadow: '0 8px 25px rgba(0, 0, 0, 0.1)',
        maxWidth: '500px',
        margin: '50px auto'
      }}>
        {/* Failure Icon */}
        <div style={{
          fontSize: '80px',
          marginBottom: '20px'
        }}>
          ❌
        </div>

        <h1 style={{
          color: '#dc3545',
          marginBottom: '20px'
        }}>
          Payment Failed
        </h1>

        <p style={{
          fontSize: '18px',
          color: '#666',
          marginBottom: '30px'
        }}>
          We're sorry, but your payment could not be processed. Please try again.
        </p>

        {paymentDetails && (
          <div style={{
            background: '#f8f9fa',
            padding: '20px',
            borderRadius: '10px',
            marginBottom: '30px',
            textAlign: 'left'
          }}>
            <h3 style={{ marginBottom: '15px', color: '#333' }}>Transaction Details</h3>
            <div style={{ marginBottom: '10px' }}>
              <strong>Transaction ID:</strong> {paymentDetails.transactionId}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>Amount:</strong> ₹{paymentDetails.amount}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>Status:</strong> 
              <span style={{ 
                color: '#dc3545', 
                fontWeight: 'bold',
                marginLeft: '5px'
              }}>
                FAILED
              </span>
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>Error:</strong> {paymentDetails.error}
            </div>
            <div>
              <strong>Date & Time:</strong> {paymentDetails.timestamp}
            </div>
          </div>
        )}

        <div style={{
          display: 'flex',
          gap: '15px',
          justifyContent: 'center',
          flexWrap: 'wrap',
          marginBottom: '30px'
        }}>
          <button
            onClick={() => window.location.reload()}
            style={{
              padding: '12px 24px',
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              fontWeight: 'bold',
              cursor: 'pointer',
              transition: 'transform 0.3s ease'
            }}
            onMouseOver={(e) => e.target.style.transform = 'translateY(-2px)'}
            onMouseOut={(e) => e.target.style.transform = 'translateY(0)'}
          >
            🔄 Retry Payment
          </button>

          <Link 
            to="/"
            style={{
              padding: '12px 24px',
              background: 'white',
              color: '#667eea',
              border: '2px solid #667eea',
              textDecoration: 'none',
              borderRadius: '8px',
              fontWeight: 'bold',
              transition: 'all 0.3s ease'
            }}
            onMouseOver={(e) => {
              e.target.style.background = '#667eea';
              e.target.style.color = 'white';
            }}
            onMouseOut={(e) => {
              e.target.style.background = 'white';
              e.target.style.color = '#667eea';
            }}
          >
            🛍️ Back to Store
          </Link>
        </div>

        {/* Troubleshooting Tips */}
        <div style={{
          marginTop: '30px',
          padding: '20px',
          background: '#f8f9fa',
          borderRadius: '10px',
          textAlign: 'left'
        }}>
          <h4 style={{ marginBottom: '15px', color: '#333' }}>💡 Troubleshooting Tips</h4>
          <ul style={{ color: '#666', lineHeight: '1.6' }}>
            <li>Check your account balance</li>
            <li>Ensure you have a stable internet connection</li>
            <li>Verify your UPI PIN is correct</li>
            <li>Try using a different UPI app</li>
            <li>Check if you've reached daily transaction limits</li>
            <li>Wait a few minutes and try again</li>
          </ul>
        </div>

        {/* Common Failure Reasons */}
        <div style={{
          marginTop: '20px',
          padding: '20px',
          background: '#fff3cd',
          borderRadius: '10px',
          textAlign: 'left'
        }}>
          <h4 style={{ marginBottom: '15px', color: '#856404' }}>Common Reasons for Payment Failure</h4>
          <ul style={{ color: '#856404', lineHeight: '1.6' }}>
            {commonFailureReasons.map((reason, index) => (
              <li key={index}>{reason}</li>
            ))}
          </ul>
        </div>

        {/* Support Information */}
        <div style={{
          marginTop: '20px',
          padding: '15px',
          background: '#d1ecf1',
          borderRadius: '8px',
          border: '1px solid #bee5eb'
        }}>
          <p style={{ margin: 0, color: '#0c5460' }}>
            <strong>Still having issues?</strong> Contact our support team at support@testmerchant.com or call 1800-123-4567
          </p>
        </div>

        {/* Alternative Payment Methods */}
        <div style={{
          marginTop: '20px',
          padding: '15px',
          background: '#e2e3e5',
          borderRadius: '8px'
        }}>
          <p style={{ margin: 0, color: '#383d41' }}>
            <strong>Alternative:</strong> You can also try paying with a different UPI app or contact us for other payment options.
          </p>
        </div>
      </div>
    </div>
  );
};

export default PaymentFailed;