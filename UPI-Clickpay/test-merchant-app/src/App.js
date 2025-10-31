import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import MerchantStore from './components/MerchantStore';
import PaymentSuccess from './components/PaymentSuccess';
import PaymentFailed from './components/PaymentFailed';

function App() {
  return (
    <Router>
      <div className="App">
        <Routes>
          <Route path="/" element={<MerchantStore />} />
          <Route path="/payment-success" element={<PaymentSuccess />} />
          <Route path="/payment-failed" element={<PaymentFailed />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;