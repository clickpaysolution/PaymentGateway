#!/bin/bash

echo "🛍️ Starting Test Merchant Application..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 16+ first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Check if payment gateway is running
echo "🔍 Checking if Payment Gateway is running..."
if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
    echo "✅ Payment Gateway is running on port 8080"
else
    echo "⚠️  Payment Gateway is not running on port 8080"
    echo "   Please start the payment gateway first:"
    echo "   cd .. && docker-compose up -d"
    echo ""
    echo "   Or manually start the services:"
    echo "   1. Start Auth Service (port 8081)"
    echo "   2. Start Payment Service (port 8083)"
    echo "   3. Start API Gateway (port 8080)"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Set environment variables
export PORT=3001
export REACT_APP_PAYMENT_GATEWAY_URL=http://localhost:8080
export REACT_APP_MERCHANT_API_KEY=test_api_key_123

echo "🚀 Starting Test Merchant App on port 3001..."
echo ""
echo "📋 Configuration:"
echo "   - Merchant App: http://localhost:3001"
echo "   - Payment Gateway: http://localhost:8080"
echo "   - API Key: test_api_key_123"
echo ""
echo "🛍️ Test Products Available:"
echo "   - Premium Headphones (₹2,999)"
echo "   - Smart Watch (₹8,999)"
echo "   - Wireless Speaker (₹1,499)"
echo "   - Gaming Mouse (₹1,299)"
echo "   - Mechanical Keyboard (₹3,499)"
echo "   - Phone Case (₹599)"
echo ""
echo "💰 Custom Amount Testing:"
echo "   - Enter any amount to test payment flow"
echo "   - Supports amounts from ₹1 to ₹1,00,000"
echo ""
echo "🔄 Payment Flow:"
echo "   1. Select product or enter amount"
echo "   2. Click 'Buy with UPI'"
echo "   3. Redirected to Payment Gateway"
echo "   4. Complete UPI payment"
echo "   5. Return to merchant success/failure page"
echo ""

# Start the application
npm start