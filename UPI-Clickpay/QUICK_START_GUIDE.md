# Quick Start Guide for Merchants

## 🚀 Get Started in 5 Minutes

This guide will help you integrate our payment gateway and process your first test payment in under 5 minutes.

## Step 1: Get Your Credentials (1 minute)

### For Testing (Immediate)
Use these test credentials to start immediately:

```
API Key: test_api_key_123
Merchant ID: testmerchant
Base URL: http://localhost:8080 (or your deployed URL)
```

### For Production
1. Sign up at our merchant portal
2. Complete KYC verification
3. Get your production API key

## Step 2: Make Your First API Call (2 minutes)

### Using cURL
```bash
curl -X POST http://localhost:8080/api/payments/create \
  -H "Authorization: Bearer test_api_key_123" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 100.00,
    "paymentMethod": "UPI_QR",
    "description": "Test Payment",
    "callbackUrl": "https://yoursite.com/success"
  }'
```

### Using JavaScript (Node.js)
```javascript
const axios = require('axios');

async function createPayment() {
  try {
    const response = await axios.post('http://localhost:8080/api/payments/create', {
      amount: 100.00,
      paymentMethod: 'UPI_QR',
      description: 'Test Payment',
      callbackUrl: 'https://yoursite.com/success'
    }, {
      headers: {
        'Authorization': 'Bearer test_api_key_123',
        'Content-Type': 'application/json'
      }
    });

    console.log('Payment URL:', response.data.data.paymentUrl);
    console.log('Transaction ID:', response.data.data.transactionId);
  } catch (error) {
    console.error('Error:', error.response.data);
  }
}

createPayment();
```

### Using Python
```python
import requests

def create_payment():
    url = "http://localhost:8080/api/payments/create"
    
    headers = {
        "Authorization": "Bearer test_api_key_123",
        "Content-Type": "application/json"
    }
    
    payload = {
        "amount": 100.00,
        "paymentMethod": "UPI_QR",
        "description": "Test Payment",
        "callbackUrl": "https://yoursite.com/success"
    }
    
    response = requests.post(url, json=payload, headers=headers)
    
    if response.status_code == 200:
        data = response.json()
        print(f"Payment URL: {data['data']['paymentUrl']}")
        print(f"Transaction ID: {data['data']['transactionId']}")
    else:
        print(f"Error: {response.text}")

create_payment()
```

## Step 3: Test the Payment Flow (2 minutes)

1. **Run the API call** from Step 2
2. **Copy the payment URL** from the response
3. **Open the URL** in your browser
4. **Complete the test payment** using the UPI options
5. **Verify the callback** to your success URL

### Expected Response
```json
{
  "success": true,
  "message": "Payment created successfully",
  "data": {
    "transactionId": "TXN_1234567890",
    "amount": 100.00,
    "status": "PENDING",
    "paymentUrl": "http://localhost:8080/payment/TXN_1234567890",
    "createdAt": "2024-01-01T10:00:00Z"
  }
}
```

## Step 4: Check Payment Status

```bash
curl -X GET http://localhost:8080/api/payments/status/TXN_1234567890 \
  -H "Authorization: Bearer test_api_key_123"
```

## Step 5: Try Our Demo Store

Visit our test merchant application to see a complete integration example:

```
http://localhost:3001
```

This demo shows:
- Product catalog with UPI payments
- Custom amount payments
- Complete payment flow
- Success/failure handling

## 🔧 Integration Patterns

### Pattern 1: Simple Redirect
```javascript
// 1. Create payment on your server
const payment = await createPayment(amount, description);

// 2. Redirect customer to payment URL
window.location.href = payment.paymentUrl;

// 3. Handle callback on success/failure URLs
```

### Pattern 2: Popup/Modal
```javascript
// 1. Create payment
const payment = await createPayment(amount, description);

// 2. Open payment in popup
const popup = window.open(payment.paymentUrl, 'payment', 'width=500,height=600');

// 3. Listen for completion
window.addEventListener('message', (event) => {
  if (event.data.type === 'PAYMENT_COMPLETE') {
    popup.close();
    handlePaymentResult(event.data);
  }
});
```

### Pattern 3: Embedded iframe
```html
<!-- 1. Create payment and get URL -->
<!-- 2. Embed in iframe -->
<iframe 
  src="payment_url_here" 
  width="400" 
  height="500"
  frameborder="0">
</iframe>
```

## 📱 Mobile Integration

### Android (Kotlin)
```kotlin
// 1. Create payment via API
val paymentUrl = createPayment(amount, description)

// 2. Open in WebView or Custom Tab
val intent = CustomTabsIntent.Builder().build()
intent.launchUrl(this, Uri.parse(paymentUrl))
```

### iOS (Swift)
```swift
// 1. Create payment via API
let paymentUrl = createPayment(amount: amount, description: description)

// 2. Open in Safari View Controller
let safariVC = SFSafariViewController(url: URL(string: paymentUrl)!)
present(safariVC, animated: true)
```

## 🔄 Webhook Setup (Optional)

### 1. Create Webhook Endpoint
```javascript
app.post('/webhook', (req, res) => {
  const event = req.body;
  
  switch (event.type) {
    case 'payment.success':
      // Update order status
      updateOrder(event.data.transactionId, 'PAID');
      break;
    case 'payment.failed':
      // Handle failure
      updateOrder(event.data.transactionId, 'FAILED');
      break;
  }
  
  res.status(200).send('OK');
});
```

### 2. Configure Webhook URL
Include webhook URL in payment creation:
```json
{
  "amount": 100.00,
  "paymentMethod": "UPI_QR",
  "description": "Test Payment",
  "callbackUrl": "https://yoursite.com/success",
  "webhookUrl": "https://yoursite.com/webhook"
}
```

## 🛠️ Development Tools

### 1. Test with Postman
Import our collection:
```
https://api.your-gateway.com/postman/collection.json
```

### 2. Use ngrok for Local Testing
```bash
# Install ngrok
npm install -g ngrok

# Expose local server
ngrok http 3000

# Use ngrok URL for callbacks
```

### 3. Debug with Browser DevTools
- Check Network tab for API calls
- Verify request/response format
- Monitor console for errors

## 🎯 Common Use Cases

### E-commerce Checkout
```javascript
// Add to your checkout page
function proceedToPayment() {
  const orderData = {
    amount: cart.total,
    description: `Order #${orderId}`,
    callbackUrl: `${window.location.origin}/order-success?orderId=${orderId}`
  };
  
  createPaymentAndRedirect(orderData);
}
```

### Subscription Payments
```javascript
// Monthly subscription
function createSubscription() {
  const subscriptionData = {
    amount: 999.00,
    description: 'Monthly Subscription',
    callbackUrl: `${window.location.origin}/subscription-success`
  };
  
  createPaymentAndRedirect(subscriptionData);
}
```

### Donation/Fundraising
```javascript
// Custom donation amount
function donate(amount) {
  const donationData = {
    amount: parseFloat(amount),
    description: 'Donation',
    callbackUrl: `${window.location.origin}/thank-you`
  };
  
  createPaymentAndRedirect(donationData);
}
```

## 🔍 Testing Scenarios

### Test Different Amounts
```javascript
// Test various amounts
const testAmounts = [1, 10, 100, 1000, 10000];

testAmounts.forEach(amount => {
  createPayment(amount, `Test payment ₹${amount}`);
});
```

### Test Error Handling
```javascript
// Test with invalid data
try {
  await createPayment(-100, 'Invalid amount'); // Should fail
} catch (error) {
  console.log('Expected error:', error.message);
}
```

## 📊 Monitor Your Integration

### 1. Check Payment Success Rate
```javascript
// Track successful vs failed payments
const successRate = (successfulPayments / totalPayments) * 100;
console.log(`Success rate: ${successRate}%`);
```

### 2. Monitor API Response Times
```javascript
const startTime = Date.now();
await createPayment(amount, description);
const responseTime = Date.now() - startTime;
console.log(`API response time: ${responseTime}ms`);
```

### 3. Log Important Events
```javascript
// Log payment events
console.log('Payment initiated:', {
  transactionId,
  amount,
  timestamp: new Date().toISOString()
});
```

## 🚀 Go Live Checklist

### Technical
- [ ] Test all payment flows
- [ ] Implement error handling
- [ ] Set up webhook endpoint
- [ ] Configure production API key
- [ ] Test with real small amounts

### Business
- [ ] Complete merchant verification
- [ ] Set up settlement account
- [ ] Review pricing and fees
- [ ] Test customer support flow

## 🆘 Need Help?

### Quick Solutions
- **Payment not working?** Check API key and endpoint URL
- **Webhook not received?** Verify webhook URL is accessible
- **Amount issues?** Ensure amount is positive number
- **CORS errors?** Make API calls from server-side

### Get Support
- **Documentation:** Full integration guide available
- **Demo App:** Check our test merchant app for examples
- **Support:** Contact developers@your-gateway.com

### Resources
- **Test Merchant App:** http://localhost:3001
- **Payment Gateway Dashboard:** http://localhost:3000
- **API Documentation:** Available in codebase
- **Sample Code:** Multiple language examples provided

---

**🎉 Congratulations!** You've successfully integrated our payment gateway. Your customers can now make UPI payments seamlessly through your application.

**Next Steps:**
1. Customize the payment experience
2. Set up webhooks for real-time updates
3. Monitor payment analytics
4. Go live with production credentials