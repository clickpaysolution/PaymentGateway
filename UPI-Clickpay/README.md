# Payment Gateway & Processor

A comprehensive payment gateway and processor application with merchant management, transaction processing, and multi-bank API integration.

## Features

- Merchant signup/signin with JWT authentication
- Transaction management (in/out) with detailed reports
- Admin dashboard for merchant management
- API key generation and management
- UPI payment integration with multiple providers
- QR code generation for payments
- Real-time transaction status tracking
- Multi-bank API integration

## Architecture

- Frontend: React.js
- Backend: Java Microservices
- Authentication: JWT tokens
- Database: PostgreSQL
- Payment Processing: UPI integration

## Services

1. **Auth Service** - User authentication and authorization
2. **Merchant Service** - Merchant management
3. **Payment Service** - Payment processing and UPI integration
4. **Transaction Service** - Transaction management and reporting
5. **API Gateway** - Request routing and rate limiting
6. **Notification Service** - Payment notifications

## Getting Started

### Prerequisites
- Java 17+
- Node.js 16+
- PostgreSQL
- Maven

### Quick Start with Docker
```bash
docker-compose up -d
```

### Access Applications
- **Payment Gateway Dashboard:** http://localhost:3000
- **Test Merchant Store:** http://localhost:3001
- **API Gateway:** http://localhost:8080

### Manual Installation
1. Clone the repository
2. Set up database
3. Configure application properties
4. Run microservices
5. Start React frontend
6. Start test merchant app

## Test Merchant Application

We've included a complete test merchant application that demonstrates payment gateway integration:

### Features
- 🛍️ **Product Store:** Pre-built e-commerce interface
- 💰 **Custom Payments:** Enter any amount for testing
- 🔄 **Complete Flow:** Full payment journey demonstration
- 📱 **UPI Integration:** All UPI payment methods supported

### Quick Test
1. Start the payment gateway: `docker-compose up -d`
2. Open test merchant: http://localhost:3001
3. Select a product or enter custom amount
4. Click "Buy with UPI"
5. Complete payment on gateway page
6. Return to merchant success page

## API Documentation

API documentation available at `/swagger-ui` for each service.