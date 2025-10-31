import React, { useEffect, useState } from 'react';
import { useSearchParams, Link } from 'react-router-dom';

const PaymentSuccess = () => {
  const [searchParams] = useSearchParams();
  const [paymentDetails, setPaymentDetails] = useState(null);

  const transactionId = searchParams.get('transactionId');
  const amount = searchParams.get('amount');
  const status = searchParams.get('status');

  useEffect(() => {
    // In a real implementation, you would verify the payment status
    // by calling your backend API with the transaction ID
    if (transactionId) {
      setPaymentDetails({
        transactionId,
        amount: amount || '0',
        status: status || 'SUCCESS',
        timestamp: new Date().toLocaleString()
      });
    }
  }, [transactionId, amount, status]);

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
        {/* Success Icon */}
        <div style={{
          fontSize: '80px',
          marginBottom: '20px'
        }}>
          ✅
        </div>

        <h1 style={{
          color: '#28a745',
          marginBottom: '20px'
        }}>
          Payment Successful!
        </h1>

        <p style={{
          fontSize: '18px',
          color: '#666',
          marginBottom: '30px'
        }}>
          Thank you for your purchase. Your payment has been processed successfully.
        </p>

        {paymentDetails && (
          <div style={{
            background: '#f8f9fa',
            padding: '20px',
            borderRadius: '10px',
            marginBottom: '30px',
            textAlign: 'left'
          }}>
            <h3 style={{ marginBottom: '15px', color: '#333' }}>Payment Details</h3>
            <div style={{ marginBottom: '10px' }}>
              <strong>Transaction ID:</strong> {paymentDetails.transactionId}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>Amount:</strong> ₹{paymentDetails.amount}
            </div>
            <div style={{ marginBottom: '10px' }}>
              <strong>Status:</strong> 
              <span style={{ 
                color: '#28a745', 
                fontWeight: 'bold',
                marginLeft: '5px'
              }}>
                {paymentDetails.status}
              </span>
            </div>
            <div>
              <strong>Date & Time:</strong> {paymentDetails.timestamp}
            </div>
          </div>
        )}

        <div style={{
          background: '#e3f2fd',
          padding: '15px',
          borderRadius: '8px',
          marginBottom: '30px'
        }}>
          <p style={{ margin: 0, color: '#1976d2' }}>
            📧 A confirmation email has been sent to your registered email address.
          </p>
        </div>

        <div style={{
          display: 'flex',
          gap: '15px',
          justifyContent: 'center',
          flexWrap: 'wrap'
        }}>
          <Link 
            to="/"
            style={{
              padding: '12px 24px',
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white',
              textDecoration: 'none',
              borderRadius: '8px',
              fontWeight: 'bold',
              transition: 'transform 0.3s ease'
            }}
            onMouseOver={(e) => e.target.style.transform = 'translateY(-2px)'}
            onMouseOut={(e) => e.target.style.transform = 'translateY(0)'}
          >
            🛍️ Continue Shopping
          </Link>

          <button
            onClick={() => window.print()}
            style={{
              padding: '12px 24px',
              background: 'white',
              color: '#667eea',
              border: '2px solid #667eea',
              borderRadius: '8px',
              fontWeight: 'bold',
              cursor: 'pointer',
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
            🖨️ Print Receipt
          </button>
        </div>

        {/* Additional Information */}
        <div style={{
          marginTop: '30px',
          padding: '20px',
          background: '#f8f9fa',
          borderRadius: '10px',
          textAlign: 'left'
        }}>
          <h4 style={{ marginBottom: '15px', color: '#333' }}>What happens next?</h4>
          <ul style={{ color: '#666', lineHeight: '1.6' }}>
            <li>Your order will be processed within 24 hours</li>
            <li>You'll receive tracking information via email</li>
            <li>For any queries, contact our support team</li>
            <li>Refunds (if applicable) will be processed to the same payment method</li>
          </ul>
        </div>

        {/* Support Information */}
        <div style={{
          marginTop: '20px',
          padding: '15px',
          background: '#fff3cd',
          borderRadius: '8px',
          border: '1px solid #ffeaa7'
        }}>
          <p style={{ margin: 0, color: '#856404' }}>
            <strong>Need Help?</strong> Contact our support team at support@testmerchant.com or call 1800-123-4567
          </p>
        </div>
      </div>
    </div>
  );
};

export default PaymentSuccess;