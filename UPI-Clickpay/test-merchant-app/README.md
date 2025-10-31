# Test Merchant Application

This is a demo merchant application that showcases how to integrate with our Payment Gateway. It simulates an e-commerce store where customers can purchase products or pay custom amounts using UPI.

## Features

### 🛍️ Product Store
- Pre-defined products with different price points
- One-click purchase with UPI payment
- Realistic e-commerce interface

### 💰 Custom Amount Payment
- Enter any amount for testing
- Instant payment processing
- Real-time status updates

### 🔧 Integration Demo
- Shows complete payment flow
- API integration examples
- Error handling demonstration

## How It Works

### 1. Customer Journey
```
Customer selects product → Clicks "Buy with UPI" → Redirected to Payment Gateway → Completes UPI payment → Returns to merchant site
```

### 2. Technical Flow
```
Merchant App → Payment Gateway API → Payment Page → UPI Processing → Status Update → Callback
```

## Setup Instructions

### Prerequisites
- Node.js 16+
- Payment Gateway running on localhost:8080

### Installation
1. **Navigate to test merchant directory:**
   ```bash
   cd test-merchant-app
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Start the application:**
   ```bash
   npm start
   ```

4. **Access the store:**
   Open http://localhost:3001 in your browser

## API Integration

### Authentication
The test merchant uses API key authentication:
```javascript
headers: {
  'Authorization': 'Bearer test_api_key_123',
  'Content-Type': 'application/json'
}
```

### Create Payment
```javascript
POST /api/test-merchant/create-payment
{
  "amount": 100.00,
  "paymentMethod": "UPI_QR",
  "description": "Product Purchase",
  "callbackUrl": "http://localhost:3001/payment-success",
  "currency": "INR"
}
```

### Response
```javascript
{
  "success": true,
  "data": {
    "transactionId": "TXN123456789",
    "amount": 100.00,
    "status": "PENDING",
    "paymentMethod": "UPI_QR",
    "createdAt": "2024-01-01T10:00:00"
  }
}
```

## Testing Scenarios

### 1. Successful Payment
- Select any product or enter custom amount
- Click "Buy with UPI"
- Complete payment on payment gateway page
- Verify success callback

### 2. Failed Payment
- Start payment process
- Cancel or fail payment on gateway page
- Verify error handling

### 3. Different Amounts
- Test with various amounts (₹1, ₹100, ₹10,000)
- Verify amount formatting and processing

## Configuration

### Environment Variables
```bash
REACT_APP_PAYMENT_GATEWAY_URL=http://localhost:8080
REACT_APP_MERCHANT_API_KEY=test_api_key_123
```

### Merchant Settings
- **Merchant ID:** testmerchant
- **API Key:** test_api_key_123
- **Callback URL:** http://localhost:3001/payment-success
- **Webhook URL:** http://localhost:3001/webhook (optional)

## Sample Products

The demo includes these test products:

| Product | Price | Description |
|---------|-------|-------------|
| Premium Headphones | ₹2,999 | High-quality wireless headphones |
| Smart Watch | ₹8,999 | Feature-rich smartwatch |
| Wireless Speaker | ₹1,499 | Portable Bluetooth speaker |
| Gaming Mouse | ₹1,299 | High-precision gaming mouse |
| Mechanical Keyboard | ₹3,499 | Professional mechanical keyboard |
| Phone Case | ₹599 | Protective case with premium materials |

## Payment Methods Supported

### UPI Options
- **QR Code:** Universal QR code for all UPI apps
- **App Intent:** Direct links to specific UPI apps
- **UPI ID:** Direct payment to UPI ID

### UPI Apps Supported
- PhonePe
- Google Pay
- Paytm
- Amazon Pay
- BHIM UPI
- Any UPI-enabled app

## Error Handling

The application handles various error scenarios:

### API Errors
- Invalid API key
- Network connectivity issues
- Server errors
- Validation failures

### Payment Errors
- Insufficient funds
- Invalid UPI PIN
- Transaction timeout
- Bank server issues

## Security Features

### API Security
- Bearer token authentication
- Request validation
- Error message sanitization

### Data Protection
- No sensitive data stored locally
- Secure API communication
- Transaction ID tracking only

## Customization

### Branding
Update the following files to customize branding:
- `src/components/MerchantStore.js` - Store name and description
- `src/index.css` - Colors and styling
- `public/index.html` - Page title and meta tags

### Products
Modify the `products` array in `MerchantStore.js`:
```javascript
const products = [
  {
    id: 1,
    name: 'Your Product',
    description: 'Product description',
    price: 999,
    emoji: '🎁'
  }
];
```

### API Configuration
Update API endpoints in `MerchantStore.js`:
```javascript
const MERCHANT_API_KEY = 'your_api_key';
const PAYMENT_GATEWAY_URL = 'your_gateway_url';
```

## Deployment

### Development
```bash
npm start
```

### Production Build
```bash
npm run build
```

### Docker Deployment
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3001
CMD ["npm", "start"]
```

## Monitoring

### Key Metrics
- Payment success rate
- Average transaction amount
- Popular products
- Error rates by type

### Logging
The application logs:
- Payment initiation attempts
- API response status
- Error conditions
- User interactions

## Support

### Common Issues
1. **Payment Gateway Not Running:** Ensure the main payment gateway is running on port 8080
2. **API Key Invalid:** Verify the API key matches the test merchant configuration
3. **CORS Issues:** Check that the payment gateway allows requests from localhost:3001

### Debug Mode
Enable debug logging by adding to localStorage:
```javascript
localStorage.setItem('debug', 'true');
```

## Integration Examples

### React Integration
```javascript
const initiatePayment = async (amount, description) => {
  const response = await fetch('/api/test-merchant/create-payment', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      amount,
      paymentMethod: 'UPI_QR',
      description,
      callbackUrl: window.location.origin + '/success'
    })
  });
  
  const payment = await response.json();
  if (payment.success) {
    window.location.href = `/payment/${payment.data.transactionId}`;
  }
};
```

### Vanilla JavaScript
```javascript
function payWithUPI(amount) {
  fetch('/api/test-merchant/create-payment', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer test_api_key_123',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      amount: amount,
      paymentMethod: 'UPI_QR',
      description: 'Purchase',
      callbackUrl: window.location.origin + '/success'
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      window.location.href = `/payment/${data.data.transactionId}`;
    }
  });
}
```

This test merchant application provides a complete example of payment gateway integration and can be used as a reference for implementing similar functionality in production applications.