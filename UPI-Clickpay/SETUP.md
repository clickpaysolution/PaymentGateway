# Payment Gateway Setup Guide

## Prerequisites

- Java 17+
- Node.js 16+
- PostgreSQL 12+
- Maven 3.6+
- Docker & Docker Compose (optional)

## Quick Start with Docker

1. **Clone and navigate to the project directory**
2. **Start all services with Docker Compose:**
   ```bash
   docker-compose up -d
   ```
3. **Access the application:**
   - Frontend: http://localhost:3000
   - API Gateway: http://localhost:8080

## Manual Setup

### 1. Database Setup

1. **Install PostgreSQL and create database:**
   ```sql
   CREATE DATABASE payment_gateway;
   CREATE USER admin WITH PASSWORD 'password';
   GRANT ALL PRIVILEGES ON DATABASE payment_gateway TO admin;
   ```

2. **Run the initialization script:**
   ```bash
   psql -U admin -d payment_gateway -f database/init.sql
   ```

### 2. Backend Services

1. **Build all services:**
   ```bash
   cd backend
   mvn clean install
   ```

2. **Start services in order:**
   
   **Auth Service (Port 8081):**
   ```bash
   cd auth-service
   mvn spring-boot:run
   ```
   
   **Payment Service (Port 8083):**
   ```bash
   cd payment-service
   mvn spring-boot:run
   ```
   
   **Merchant Service (Port 8082):**
   ```bash
   cd merchant-service
   mvn spring-boot:run
   ```
   
   **Transaction Service (Port 8084):**
   ```bash
   cd transaction-service
   mvn spring-boot:run
   ```
   
   **API Gateway (Port 8080):**
   ```bash
   cd api-gateway
   mvn spring-boot:run
   ```

### 3. Frontend

1. **Install dependencies:**
   ```bash
   cd frontend
   npm install
   ```

2. **Start development server:**
   ```bash
   npm start
   ```

## Default Credentials

### Admin Login
- Username: `admin`
- Password: `password`

### Test Merchant Login
- Username: `testmerchant`
- Password: `password`

## API Integration

### Authentication
All API requests require JWT token in Authorization header:
```
Authorization: Bearer <jwt_token>
```

### Create Payment
```bash
POST /api/payments/create
Content-Type: application/json
Authorization: Bearer <jwt_token>

{
  "amount": 100.00,
  "paymentMethod": "UPI_QR",
  "description": "Product Purchase",
  "callbackUrl": "https://yoursite.com/callback"
}
```

### Payment Page
Direct users to: `/payment/{transactionId}`

### Webhook Handling
Configure webhook URL in merchant settings to receive payment status updates.

## Features

### For Merchants
- ✅ Signup/Login with JWT authentication
- ✅ Transaction dashboard with reports (day/week/month/year/lifetime)
- ✅ API key management
- ✅ Payment page integration
- ✅ UPI QR code generation
- ✅ Multiple UPI provider support
- ✅ Custom UPI ID payments
- ✅ Real-time transaction status

### For Admin
- ✅ Merchant management
- ✅ API key generation for merchants
- ✅ View all merchant reports
- ✅ Activate/deactivate merchants
- ✅ System-wide analytics

### Payment Methods
- ✅ UPI QR Code (dynamic generation)
- ✅ UPI Intent (app-specific links)
- ✅ UPI ID (direct payment requests)
- ✅ Multiple UPI providers (PhonePe, Google Pay, Paytm, etc.)

## Architecture

```
Frontend (React) → API Gateway → Microservices
                                    ├── Auth Service
                                    ├── Payment Service
                                    ├── Merchant Service
                                    ├── Transaction Service
                                    └── Notification Service
```

## Database Schema

- **users**: Authentication and user management
- **merchants**: Merchant-specific data and API keys
- **payments**: Payment transactions
- **transactions**: Transaction reporting data

## Security Features

- JWT-based authentication
- API key validation
- Role-based access control (Admin/Merchant)
- Secure password hashing
- CORS configuration

## Monitoring & Logging

- Application logs for all services
- Transaction status tracking
- Payment success/failure rates
- Real-time payment status updates

## Production Deployment

1. **Environment Variables:**
   ```bash
   export DB_HOST=your-db-host
   export DB_PASSWORD=your-secure-password
   export JWT_SECRET=your-jwt-secret
   export REDIS_HOST=your-redis-host
   ```

2. **Build for production:**
   ```bash
   ./scripts/build.sh
   ```

3. **Deploy with Docker:**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

## Bank API Integration

The system is designed to integrate with multiple bank APIs. Configure bank endpoints in:
- `backend/payment-service/src/main/resources/application.yml`

## Support

For issues and questions:
1. Check the logs in each service
2. Verify database connections
3. Ensure all services are running on correct ports
4. Check JWT token validity

## Next Steps

1. **Bank API Integration**: Connect with actual bank APIs for payment processing
2. **Webhook Security**: Implement webhook signature verification
3. **Rate Limiting**: Add API rate limiting for security
4. **Monitoring**: Set up application monitoring and alerting
5. **Testing**: Add comprehensive test suites
6. **Documentation**: Generate API documentation with Swagger