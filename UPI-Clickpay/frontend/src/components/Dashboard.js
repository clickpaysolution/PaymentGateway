import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useAuth } from '../context/AuthContext';
import MerchantModeSelector from './MerchantModeSelector';

const Dashboard = () => {
  const { currentUser } = useAuth();
  const [transactions, setTransactions] = useState([]);
  const [stats, setStats] = useState({
    totalTransactions: 0,
    successfulTransactions: 0,
    totalAmount: 0,
    successRate: 0
  });
  const [dateRange, setDateRange] = useState('today');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchTransactions();
    fetchStats();
  }, [dateRange]);

  const fetchTransactions = async () => {
    try {
      const response = await axios.get(`/api/transactions/merchant/${currentUser.userId}?range=${dateRange}`);
      if (response.data.success) {
        setTransactions(response.data.data);
      }
    } catch (error) {
      console.error('Error fetching transactions:', error);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await axios.get(`/api/transactions/stats/${currentUser.userId}?range=${dateRange}`);
      if (response.data.success) {
        setStats(response.data.data);
      }
    } catch (error) {
      console.error('Error fetching stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status) => {
    const statusClass = status === 'SUCCESS' ? 'status-success' : 
                       status === 'PENDING' ? 'status-pending' : 'status-failed';
    return <span className={`status-badge ${statusClass}`}>{status}</span>;
  };

  const formatAmount = (amount) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR'
    }).format(amount);
  };

  if (loading) {
    return <div className="container">Loading...</div>;
  }

  const [activeTab, setActiveTab] = useState('overview');

  return (
    <div className="container">
      <h1>Merchant Dashboard</h1>
      <p>Welcome back, {currentUser.username}!</p>

      {/* Navigation Tabs */}
      <div style={{ 
        display: 'flex', 
        gap: '10px', 
        marginBottom: '30px',
        borderBottom: '1px solid #ddd',
        paddingBottom: '10px'
      }}>
        <button 
          className={`btn ${activeTab === 'overview' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setActiveTab('overview')}
        >
          📊 Overview
        </button>
        <button 
          className={`btn ${activeTab === 'configuration' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setActiveTab('configuration')}
        >
          ⚙️ Configuration
        </button>
      </div>

      {activeTab === 'configuration' ? (
        <MerchantModeSelector />
      ) : (
        <div>

      {/* Date Range Filter */}
      <div className="card">
        <div className="form-group">
          <label htmlFor="dateRange">Select Date Range:</label>
          <select
            id="dateRange"
            className="form-control"
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value)}
            style={{ maxWidth: '200px' }}
          >
            <option value="today">Today</option>
            <option value="week">This Week</option>
            <option value="month">This Month</option>
            <option value="year">This Year</option>
            <option value="lifetime">Lifetime</option>
          </select>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-3">
        <div className="card">
          <h3>Total Transactions</h3>
          <p style={{ fontSize: '2rem', fontWeight: 'bold', color: '#007bff' }}>
            {stats.totalTransactions}
          </p>
        </div>
        <div className="card">
          <h3>Successful Transactions</h3>
          <p style={{ fontSize: '2rem', fontWeight: 'bold', color: '#28a745' }}>
            {stats.successfulTransactions}
          </p>
        </div>
        <div className="card">
          <h3>Total Amount</h3>
          <p style={{ fontSize: '2rem', fontWeight: 'bold', color: '#17a2b8' }}>
            {formatAmount(stats.totalAmount)}
          </p>
        </div>
      </div>

      {/* Success Rate */}
      <div className="card">
        <h3>Success Rate</h3>
        <div style={{ 
          width: '100%', 
          height: '20px', 
          backgroundColor: '#e9ecef', 
          borderRadius: '10px',
          overflow: 'hidden'
        }}>
          <div style={{
            width: `${stats.successRate}%`,
            height: '100%',
            backgroundColor: '#28a745',
            transition: 'width 0.3s ease'
          }}></div>
        </div>
        <p style={{ marginTop: '10px', fontSize: '1.2rem', fontWeight: 'bold' }}>
          {stats.successRate.toFixed(1)}%
        </p>
      </div>

      {/* Transactions Table */}
      <div className="card">
        <h3>Recent Transactions</h3>
        {transactions.length > 0 ? (
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
              {transactions.map((transaction) => (
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
          <p>No transactions found for the selected period.</p>
        )}
      </div>

      {/* API Integration Info */}
      <div className="card">
        <h3>API Integration</h3>
        <p><strong>API Key:</strong> <code>merchant_{currentUser.userId}_api_key</code></p>
        <p><strong>Endpoint:</strong> <code>POST /api/payments/create</code></p>
        <p><strong>Payment Page URL:</strong> <code>/payment/[transactionId]</code></p>
        
        <h4>Sample Integration Code:</h4>
        <pre style={{ 
          backgroundColor: '#f8f9fa', 
          padding: '15px', 
          borderRadius: '5px',
          overflow: 'auto'
        }}>
{`// Create Payment
const response = await fetch('/api/payments/create', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer YOUR_API_KEY'
  },
  body: JSON.stringify({
    amount: 100.00,
    paymentMethod: 'UPI_QR',
    description: 'Product Purchase',
    callbackUrl: 'https://yoursite.com/callback'
  })
});

const payment = await response.json();
// Redirect to: /payment/\${payment.data.transactionId}`}
        </pre>
      </div>
        </div>
      )}
    </div>
  );
};

export default Dashboard;