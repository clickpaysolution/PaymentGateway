# API Reference

## Base URL
```
Production: https://api.your-gateway.com
Sandbox: http://localhost:8080
```

## Authentication
All API requests require authentication using Bearer token:
```http
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

## Endpoints

### 1. Create Payment

Create a new payment transaction.

**Endpoint:** `POST /api/payments/create`

**Headers:**
```http
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

**Request Body:**
```json
{
  "amount": 100.00,
  "currency": "INR",
  "paymentMethod": "UPI_QR",
  "description": "Product Purchase",
  "callbackUrl": "https://yoursite.com/payment-success",
  "webhookUrl": "https://yoursite.com/webhook",
  "customerInfo": {
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+919876543210"
  },
  "orderInfo": {
    "orderId": "ORDER_123",
    "items": [
      {
        "name": "Product Name",
        "quantity": 1,
        "price": 100.00
      }
    ]
  }
}
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `amount` | number | Yes | Payment amount (min: 1.00) |
| `currency` | string | No | Currency code (default: "INR") |
| `paymentMethod` | string | Yes | Payment method: "UPI_QR", "UPI_ID", "UPI_INTENT" |
| `description` | string | Yes | Payment description |
| `callbackUrl` | string | Yes | URL to redirect after payment |
| `webhookUrl` | string | No | URL for webhook notifications |
| `customerInfo` | object | No | Customer information |
| `orderInfo` | object | No | Order details |

**Response:**
```json
{
  "success": true,
  "message": "Payment created successfully",
  "data": {
    "transactionId": "TXN_1234567890",
    "amount": 100.00,
    "currency": "INR",
    "status": "PENDING",
    "paymentMethod": "UPI_QR",
    "paymentUrl": "https://gateway.com/payment/TXN_1234567890",
    "qrCodeData": "base64_encoded_qr_code",
    "createdAt": "2024-01-01T10:00:00Z"
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Invalid amount",
  "timestamp": "2024-01-01T10:00:00Z"
}
```

---

### 2. Get Payment Status

Retrieve the current status of a payment.

**Endpoint:** `GET /api/payments/status/{transactionId}`

**Headers:**
```http
Authorization: Bearer YOUR_API_KEY
```

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `transactionId` | string | Yes | Transaction ID from payment creation |

**Response:**
```json
{
  "success": true,
  "data": {
    "transactionId": "TXN_1234567890",
    "status": "SUCCESS",
    "amount": 100.00,
    "currency": "INR",
    "paymentMethod": "UPI_QR",
    "bankReference": "BANK_REF_123",
    "createdAt": "2024-01-01T10:00:00Z",
    "completedAt": "2024-01-01T10:05:00Z"
  }
}
```

**Status Values:**
- `PENDING` - Payment initiated, waiting for completion
- `SUCCESS` - Payment completed successfully
- `FAILED` - Payment failed
- `CANCELLED` - Payment cancelled by user
- `EXPIRED` - Payment link expired

---

### 3. Get Transaction History

Retrieve transaction history for the merchant.

**Endpoint:** `GET /api/transactions/merchant/{merchantId}`

**Headers:**
```http
Authorization: Bearer YOUR_API_KEY
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `range` | string | No | Time range: "today", "week", "month", "year", "lifetime" |
| `status` | string | No | Filter by status: "SUCCESS", "FAILED", "PENDING" |
| `limit` | number | No | Number of records (default: 50, max: 100) |
| `offset` | number | No | Pagination offset (default: 0) |

**Response:**
```json
{
  "success": true,
  "data": {
    "transactions": [
      {
        "transactionId": "TXN_1234567890",
        "amount": 100.00,
        "currency": "INR",
        "status": "SUCCESS",
        "paymentMethod": "UPI_QR",
        "description": "Product Purchase",
        "createdAt": "2024-01-01T10:00:00Z",
        "completedAt": "2024-01-01T10:05:00Z"
      }
    ],
    "pagination": {
      "total": 150,
      "limit": 50,
      "offset": 0,
      "hasMore": true
    }
  }
}
```

---

### 4. Get Transaction Statistics

Get aggregated statistics for the merchant.

**Endpoint:** `GET /api/transactions/stats/{merchantId}`

**Headers:**
```http
Authorization: Bearer YOUR_API_KEY
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `range` | string | No | Time range: "today", "week", "month", "year", "lifetime" |

**Response:**
```json
{
  "success": true,
  "data": {
    "totalTransactions": 150,
    "successfulTransactions": 142,
    "failedTransactions": 8,
    "totalAmount": 15000.00,
    "successfulAmount": 14200.00,
    "successRate": 94.67,
    "averageAmount": 100.00,
    "period": {
      "start": "2024-01-01T00:00:00Z",
      "end": "2024-01-31T23:59:59Z"
    }
  }
}
```

---

### 5. Webhook Events

Webhook notifications are sent to your configured webhook URL.

**Webhook Headers:**
```http
Content-Type: application/json
X-Webhook-Signature: sha256=signature_hash
X-Webhook-ID: unique_webhook_id
```

**Event Types:**

#### Payment Success
```json
{
  "type": "payment.success",
  "timestamp": "2024-01-01T10:05:00Z",
  "data": {
    "transactionId": "TXN_1234567890",
    "merchantId": "MERCHANT_123",
    "amount": 100.00,
    "currency": "INR",
    "status": "SUCCESS",
    "bankReference": "BANK_REF_123",
    "paymentMethod": "UPI_QR",
    "completedAt": "2024-01-01T10:05:00Z"
  }
}
```

#### Payment Failed
```json
{
  "type": "payment.failed",
  "timestamp": "2024-01-01T10:05:00Z",
  "data": {
    "transactionId": "TXN_1234567890",
    "merchantId": "MERCHANT_123",
    "amount": 100.00,
    "currency": "INR",
    "status": "FAILED",
    "failureReason": "Insufficient funds",
    "completedAt": "2024-01-01T10:05:00Z"
  }
}
```

---

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_API_KEY` | 401 | API key is invalid or missing |
| `INSUFFICIENT_PERMISSIONS` | 403 | API key doesn't have required permissions |
| `INVALID_AMOUNT` | 400 | Amount is invalid (negative, zero, or too large) |
| `INVALID_PAYMENT_METHOD` | 400 | Unsupported payment method |
| `TRANSACTION_NOT_FOUND` | 404 | Transaction ID not found |
| `DUPLICATE_TRANSACTION` | 409 | Transaction with same ID already exists |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Internal server error |

## Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| Create Payment | 100 requests | 1 minute |
| Get Status | 1000 requests | 1 minute |
| Get History | 50 requests | 1 minute |
| Get Stats | 20 requests | 1 minute |

## SDKs

### Node.js
```bash
npm install @your-gateway/node-sdk
```

```javascript
const PaymentGateway = require('@your-gateway/node-sdk');

const gateway = new PaymentGateway({
  apiKey: 'your_api_key',
  environment: 'sandbox' // or 'production'
});

// Create payment
const payment = await gateway.payments.create({
  amount: 100.00,
  description: 'Test Payment'
});

// Check status
const status = await gateway.payments.getStatus('TXN_123');
```

### Python
```bash
pip install your-gateway-python
```

```python
import your_gateway

gateway = your_gateway.Client(
    api_key='your_api_key',
    environment='sandbox'
)

# Create payment
payment = gateway.payments.create(
    amount=100.00,
    description='Test Payment'
)

# Check status
status = gateway.payments.get_status('TXN_123')
```

### PHP
```bash
composer require your-gateway/php-sdk
```

```php
use YourGateway\Client;

$gateway = new Client([
    'api_key' => 'your_api_key',
    'environment' => 'sandbox'
]);

// Create payment
$payment = $gateway->payments->create([
    'amount' => 100.00,
    'description' => 'Test Payment'
]);

// Check status
$status = $gateway->payments->getStatus('TXN_123');
```

## Testing

### Test API Keys
```
Sandbox API Key: test_sk_1234567890abcdef
Test Merchant ID: test_merchant_123
```

### Test Scenarios

#### Successful Payment
```json
{
  "amount": 100.00,
  "paymentMethod": "UPI_QR",
  "description": "Test Success"
}
```

#### Failed Payment
```json
{
  "amount": 1.00,
  "paymentMethod": "UPI_QR", 
  "description": "Test Failure"
}
```

### Test UPI IDs
- `success@test` - Always succeeds
- `failure@test` - Always fails
- `timeout@test` - Times out

## Postman Collection

Import our Postman collection for easy testing:
```
https://api.your-gateway.com/postman/collection.json
```

## Support

- **Documentation:** https://docs.your-gateway.com
- **Support Email:** developers@your-gateway.com
- **Status Page:** https://status.your-gateway.com