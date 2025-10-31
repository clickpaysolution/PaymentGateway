import React, { useState, useEffect } from 'react';
import axios from 'axios';

const AdminDashboard = () => {
  const [merchants, setMerchants] = useState([]);
  const [selectedMerchant, setSelectedMerchant] = useState(null);
  const [newApiKey, setNewApiKey] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchMerchants();
  }, []);

  const fetchMerchants = async () => {
    try {
      const response = await axios.get('/api/admin/merchants');
      if (response.data.success) {
        setMerchants(response.data.data);
      }
    } catch (error) {
      console.error('Error fetching merchants:', error);
    } finally {
      setLoading(false);
    }
  };

  const generateApiKey = async (merchantId) => {
    try {
      const response = await axios.post(`/api/admin/merchants/${merchantId}/generate-api-key`);
      if (response.data.success) {
        setNewApiKey(response.data.data.apiKey);
        fetchMerchants(); // Refresh the list
      }
    } catch (error) {
      console.error('Error generating API key:', error);
      alert('Failed to generate API key');
    }
  };

  const toggleMerchantStatus = async (merchantId, currentStatus) => {
    try {
      const response = await axios.put(`/api/admin/merchants/${merchantId}/status`, {
        isActive: !currentStatus
      });
      if (response.data.success) {
        fetchMerchants(); // Refresh the list
      }
    } catch (error) {
      console.error('Error updating merchant status:', error);
      alert('Failed to update merchant status');
    }
  };

  const viewMerchantTransactions = async (merchantId) => {
    try {
      const response = await axios.get(`/api/admin/merchants/${merchantId}/transactions`);
      if (response.data.success) {
        setSelectedMerchant({
          id: merchantId,
          transactions: response.data.data
        });
      }
    } catch (error) {
      console.error('Error fetching merchant transactions:', error);
    }
  };

  const formatAmount = (amount) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR'
    }).format(amount);
  };

  const getStatusBadge = (status) => {
    const statusClass = status === 'SUCCESS' ? 'status-success' : 
                       status === 'PENDING' ? 'status-pending' : 'status-failed';
    return <span className={`status-badge ${statusClass}`}>{status}</span>;
  };

  if (loading) {
    return <div className="container">Loading...</div>;
  }

  return (
    <div className="container">
      <h1>Admin Dashboard</h1>
      
      {/* New API Key Display */}
      {newApiKey && (
        <div className="alert alert-success">
          <h4>New API Key Generated:</h4>
          <code style={{ 
            display: 'block', 
            padding: '10px', 
            backgroundColor: '#f8f9fa',
            borderRadius: '4px',
            marginTop: '10px'
          }}>
            {newApiKey}
          </code>
          <p style={{ marginTop: '10px', fontSize: '14px' }}>
            Please save this API key securely. It won't be shown again.
          </p>
          <button 
            className="btn btn-primary"
            onClick={() => setNewApiKey('')}
          >
            Close
          </button>
        </div>
      )}

      {/* Merchants Table */}
      <div className="card">
        <h2>All Merchants</h2>
        <table className="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Username</th>
              <th>Email</th>
              <th>Business Name</th>
              <th>Status</th>
              <th>Created At</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {merchants.map((merchant) => (
              <tr key={merchant.id}>
                <td>{merchant.id}</td>
                <td>{merchant.username}</td>
                <td>{merchant.email}</td>
                <td>{merchant.businessName || 'Not Set'}</td>
                <td>
                  <span className={`status-badge ${merchant.isActive ? 'status-success' : 'status-failed'}`}>
                    {merchant.isActive ? 'Active' : 'Inactive'}
                  </span>
                </td>
                <td>{new Date(merchant.createdAt).toLocaleDateString()}</td>
                <td>
                  <div style={{ display: 'flex', gap: '5px', flexWrap: 'wrap' }}>
                    <button
                      className="btn btn-primary"
                      style={{ fontSize: '12px', padding: '5px 10px' }}
                      onClick={() => generateApiKey(merchant.id)}
                    >
                      Generate API Key
                    </button>
                    <button
                      className={`btn ${merchant.isActive ? 'btn-danger' : 'btn-success'}`}
                      style={{ fontSize: '12px', padding: '5px 10px' }}
                      onClick={() => toggleMerchantStatus(merchant.id, merchant.isActive)}
                    >
                      {merchant.isActive ? 'Deactivate' : 'Activate'}
                    </button>
                    <button
                      className="btn btn-primary"
                      style={{ fontSize: '12px', padding: '5px 10px' }}
                      onClick={() => viewMerchantTransactions(merchant.id)}
                    >
                      View Transactions
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Merchant Transactions Modal */}
      {selectedMerchant && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div style={{
            backgroundColor: 'white',
            padding: '20px',
            borderRadius: '8px',
            maxWidth: '90%',
            maxHeight: '90%',
            overflow: 'auto'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h3>Merchant Transactions</h3>
              <button
                className="btn btn-danger"
                onClick={() => setSelectedMerchant(null)}
              >
                Close
              </button>
            </div>
            
            {selectedMerchant.transactions.length > 0 ? (
              <table className="table">
                <thead>
                  <tr>
                    <th>Transaction ID</th>
                    <th>Amount</th>
                    <th>Status</th>
                    <th>Payment Method</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {selectedMerchant.transactions.map((transaction) => (
                    <tr key={transaction.id}>
                      <td>{transaction.transactionId}</td>
                      <td>{formatAmount(transaction.amount)}</td>
                      <td>{getStatusBadge(transaction.status)}</td>
                      <td>{transaction.paymentMethod}</td>
                      <td>{new Date(transaction.createdAt).toLocaleDateString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p>No transactions found for this merchant.</p>
            )}
          </div>
        </div>
      )}

      {/* System Stats */}
      <div className="grid grid-3">
        <div className="card">
          <h3>Total Merchants</h3>
          <p style={{ fontSize: '2rem', fontWeight: 'bold', color: '#007bff' }}>
            {merchants.length}
          </p>
        </div>
        <div className="card">
          <h3>Active Merchants</h3>
          <p style={{ fontSize: '2rem', fontWeight: 'bold', color: '#28a745' }}>
            {merchants.filter(m => m.isActive).length}
          </p>
        </div>
        <div className="card">
          <h3>Inactive Merchants</h3>
          <p style={{ fontSize: '2rem', fontWeight: 'bold', color: '#dc3545' }}>
            {merchants.filter(m => !m.isActive).length}
          </p>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;