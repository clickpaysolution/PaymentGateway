#!/bin/bash

# Payment Gateway Local Development Setup Script
# This script sets up the complete development environment

set -e

echo "🚀 Setting up Payment Gateway Local Development Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on supported OS
check_os() {
    print_status "Checking operating system..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        print_success "Linux detected"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_success "macOS detected"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        print_success "Windows detected"
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Java
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [ "$JAVA_VERSION" -ge 17 ]; then
            print_success "Java $JAVA_VERSION found"
        else
            print_error "Java 17 or higher required. Found Java $JAVA_VERSION"
            exit 1
        fi
    else
        print_error "Java not found. Please install Java 17 or higher"
        exit 1
    fi
    
    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 16 ]; then
            print_success "Node.js v$(node -v) found"
        else
            print_error "Node.js 16 or higher required. Found Node.js v$(node -v)"
            exit 1
        fi
    else
        print_error "Node.js not found. Please install Node.js 16 or higher"
        exit 1
    fi
    
    # Check Maven
    if command -v mvn &> /dev/null; then
        print_success "Maven $(mvn -v | head -n 1 | cut -d' ' -f3) found"
    else
        print_error "Maven not found. Please install Maven"
        exit 1
    fi
    
    # Check Docker (optional)
    if command -v docker &> /dev/null; then
        print_success "Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1) found"
        DOCKER_AVAILABLE=true
    else
        print_warning "Docker not found. Manual database setup will be required"
        DOCKER_AVAILABLE=false
    fi
    
    # Check PostgreSQL (if Docker not available)
    if [ "$DOCKER_AVAILABLE" = false ]; then
        if command -v psql &> /dev/null; then
            print_success "PostgreSQL found"
        else
            print_error "PostgreSQL not found. Please install PostgreSQL or Docker"
            exit 1
        fi
    fi
}

# Setup database
setup_database() {
    print_status "Setting up database..."
    
    if [ "$DOCKER_AVAILABLE" = true ]; then
        print_status "Using Docker for database setup..."
        
        # Check if container already exists
        if docker ps -a | grep -q payment-gateway-db; then
            print_warning "Database container already exists. Stopping and removing..."
            docker stop payment-gateway-db || true
            docker rm payment-gateway-db || true
        fi
        
        # Start PostgreSQL container
        print_status "Starting PostgreSQL container..."
        docker run --name payment-gateway-db \
            -e POSTGRES_DB=payment_gateway \
            -e POSTGRES_USER=admin \
            -e POSTGRES_PASSWORD=password \
            -p 5432:5432 \
            -v "$(pwd)/database/init.sql:/docker-entrypoint-initdb.d/init.sql" \
            -d postgres:15
        
        # Wait for database to be ready
        print_status "Waiting for database to be ready..."
        sleep 10
        
        # Test connection
        for i in {1..30}; do
            if docker exec payment-gateway-db pg_isready -U admin -d payment_gateway; then
                print_success "Database is ready"
                break
            fi
            if [ $i -eq 30 ]; then
                print_error "Database failed to start"
                exit 1
            fi
            sleep 2
        done
        
        # Start Redis container
        print_status "Starting Redis container..."
        if docker ps -a | grep -q payment-gateway-redis; then
            docker stop payment-gateway-redis || true
            docker rm payment-gateway-redis || true
        fi
        
        docker run --name payment-gateway-redis \
            -p 6379:6379 \
            -d redis:7-alpine
        
        print_success "Database containers started successfully"
        
    else
        print_status "Setting up local PostgreSQL database..."
        
        # Create database and user
        sudo -u postgres createdb payment_gateway 2>/dev/null || print_warning "Database already exists"
        sudo -u postgres psql -c "CREATE USER admin WITH PASSWORD 'password';" 2>/dev/null || print_warning "User already exists"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE payment_gateway TO admin;"
        
        # Initialize database
        if [ -f "database/init.sql" ]; then
            print_status "Initializing database schema..."
            PGPASSWORD=password psql -h localhost -U admin -d payment_gateway -f database/init.sql
            print_success "Database initialized"
        else
            print_warning "Database initialization script not found"
        fi
    fi
}

# Build backend services
build_backend() {
    print_status "Building backend services..."
    
    cd backend
    
    # Clean and install dependencies
    print_status "Installing Maven dependencies..."
    mvn clean install -DskipTests
    
    if [ $? -eq 0 ]; then
        print_success "Backend build completed successfully"
    else
        print_error "Backend build failed"
        exit 1
    fi
    
    cd ..
}

# Setup frontend
setup_frontend() {
    print_status "Setting up frontend..."
    
    cd frontend
    
    # Install npm dependencies
    print_status "Installing npm dependencies..."
    npm install
    
    if [ $? -eq 0 ]; then
        print_success "Frontend dependencies installed"
    else
        print_error "Frontend setup failed"
        exit 1
    fi
    
    cd ..
}

# Setup test merchant app
setup_test_merchant() {
    print_status "Setting up test merchant application..."
    
    cd test-merchant-app
    
    # Install npm dependencies
    print_status "Installing test merchant dependencies..."
    npm install
    
    if [ $? -eq 0 ]; then
        print_success "Test merchant app setup completed"
    else
        print_error "Test merchant app setup failed"
        exit 1
    fi
    
    cd ..
}

# Create environment files
create_env_files() {
    print_status "Creating environment configuration files..."
    
    # Backend environment files
    for service in auth-service payment-service merchant-service transaction-service api-gateway; do
        if [ ! -f "backend/$service/.env" ]; then
            cat > "backend/$service/.env" << EOF
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=payment_gateway
DB_USERNAME=admin
DB_PASSWORD=password

# JWT Configuration
JWT_SECRET=mySecretKeyForPaymentGatewayApplication
JWT_EXPIRATION=86400000

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379

# Application Configuration
SPRING_PROFILES_ACTIVE=development
EOF
            print_success "Created .env file for $service"
        else
            print_warning ".env file already exists for $service"
        fi
    done
    
    # Frontend environment file
    if [ ! -f "frontend/.env" ]; then
        cat > "frontend/.env" << EOF
# API Configuration
REACT_APP_API_URL=http://localhost:8080
REACT_APP_PAYMENT_GATEWAY_URL=http://localhost:8080

# Development Configuration
PORT=3000
GENERATE_SOURCEMAP=false
EOF
        print_success "Created .env file for frontend"
    else
        print_warning ".env file already exists for frontend"
    fi
    
    # Test merchant environment file
    if [ ! -f "test-merchant-app/.env" ]; then
        cat > "test-merchant-app/.env" << EOF
# API Configuration
REACT_APP_PAYMENT_GATEWAY_URL=http://localhost:8080
REACT_APP_MERCHANT_API_KEY=test_api_key_123

# Development Configuration
PORT=3001
EOF
        print_success "Created .env file for test merchant app"
    else
        print_warning ".env file already exists for test merchant app"
    fi
}

# Create startup scripts
create_startup_scripts() {
    print_status "Creating startup scripts..."
    
    # Backend startup script
    cat > "start-backend.sh" << 'EOF'
#!/bin/bash

echo "Starting Payment Gateway Backend Services..."

# Function to start service in background
start_service() {
    local service=$1
    local port=$2
    
    echo "Starting $service on port $port..."
    cd backend/$service
    mvn spring-boot:run > "../../logs/$service.log" 2>&1 &
    echo $! > "../../logs/$service.pid"
    cd ../..
    
    # Wait for service to start
    for i in {1..30}; do
        if curl -s http://localhost:$port/actuator/health > /dev/null 2>&1; then
            echo "✅ $service started successfully"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "❌ $service failed to start"
            return 1
        fi
        sleep 2
    done
}

# Create logs directory
mkdir -p logs

# Start services in order
start_service auth-service 8081
start_service payment-service 8083
start_service merchant-service 8082
start_service transaction-service 8084
start_service api-gateway 8080

echo "🚀 All backend services started successfully!"
echo "📊 API Gateway: http://localhost:8080"
echo "🔐 Auth Service: http://localhost:8081"
echo "💳 Payment Service: http://localhost:8083"
echo "📋 Logs available in ./logs/ directory"
EOF
    
    chmod +x start-backend.sh
    print_success "Created start-backend.sh"
    
    # Frontend startup script
    cat > "start-frontend.sh" << 'EOF'
#!/bin/bash

echo "Starting Payment Gateway Frontend..."

cd frontend
npm start &
FRONTEND_PID=$!
echo $FRONTEND_PID > ../logs/frontend.pid

echo "🚀 Frontend started successfully!"
echo "🌐 Dashboard: http://localhost:3000"
EOF
    
    chmod +x start-frontend.sh
    print_success "Created start-frontend.sh"
    
    # Test merchant startup script
    cat > "start-test-merchant.sh" << 'EOF'
#!/bin/bash

echo "Starting Test Merchant Application..."

cd test-merchant-app
npm start &
TEST_MERCHANT_PID=$!
echo $TEST_MERCHANT_PID > ../logs/test-merchant.pid

echo "🚀 Test Merchant App started successfully!"
echo "🛍️ Test Store: http://localhost:3001"
EOF
    
    chmod +x start-test-merchant.sh
    print_success "Created start-test-merchant.sh"
    
    # Stop all services script
    cat > "stop-all.sh" << 'EOF'
#!/bin/bash

echo "Stopping all Payment Gateway services..."

# Stop services using PID files
if [ -d "logs" ]; then
    for pidfile in logs/*.pid; do
        if [ -f "$pidfile" ]; then
            pid=$(cat "$pidfile")
            service=$(basename "$pidfile" .pid)
            
            if kill -0 "$pid" 2>/dev/null; then
                echo "Stopping $service (PID: $pid)..."
                kill "$pid"
                rm "$pidfile"
            else
                echo "$service is not running"
                rm "$pidfile"
            fi
        fi
    done
fi

# Stop Docker containers if running
if command -v docker &> /dev/null; then
    if docker ps | grep -q payment-gateway-db; then
        echo "Stopping database container..."
        docker stop payment-gateway-db
    fi
    
    if docker ps | grep -q payment-gateway-redis; then
        echo "Stopping Redis container..."
        docker stop payment-gateway-redis
    fi
fi

echo "✅ All services stopped"
EOF
    
    chmod +x stop-all.sh
    print_success "Created stop-all.sh"
}

# Create development guide
create_dev_guide() {
    print_status "Creating development guide..."
    
    cat > "DEV_GUIDE.md" << 'EOF'
# Development Guide

## Quick Start

### Start All Services
```bash
# Option 1: Using Docker Compose (Recommended)
docker-compose up -d

# Option 2: Manual startup
./start-backend.sh    # Start backend services
./start-frontend.sh   # Start frontend (in new terminal)
./start-test-merchant.sh  # Start test merchant (in new terminal)
```

### Stop All Services
```bash
# Docker Compose
docker-compose down

# Manual
./stop-all.sh
```

## Service URLs

- **API Gateway:** http://localhost:8080
- **Frontend Dashboard:** http://localhost:3000
- **Test Merchant Store:** http://localhost:3001
- **Auth Service:** http://localhost:8081
- **Payment Service:** http://localhost:8083

## Default Credentials

### Admin Login
- Username: `admin`
- Password: `password`

### Test Merchant Login
- Username: `testmerchant`
- Password: `password`
- API Key: `test_api_key_123`

## Development Workflow

1. **Make Changes:** Edit code in your IDE
2. **Restart Service:** Kill and restart the specific service
3. **Test Changes:** Use the test merchant app or Postman
4. **Check Logs:** View logs in `./logs/` directory

## Database Access

```bash
# Using Docker
docker exec -it payment-gateway-db psql -U admin -d payment_gateway

# Local PostgreSQL
psql -h localhost -U admin -d payment_gateway
```

## Useful Commands

```bash
# Check service status
curl http://localhost:8080/actuator/health

# View logs
tail -f logs/auth-service.log

# Restart specific service
cd backend/auth-service && mvn spring-boot:run

# Run tests
cd backend && mvn test
cd frontend && npm test
```

## Troubleshooting

### Port Already in Use
```bash
# Find process using port
lsof -i :8080

# Kill process
kill -9 <PID>
```

### Database Connection Issues
```bash
# Restart database container
docker restart payment-gateway-db

# Check database logs
docker logs payment-gateway-db
```

### Build Issues
```bash
# Clean and rebuild
cd backend && mvn clean install
cd frontend && rm -rf node_modules && npm install
```
EOF
    
    print_success "Created DEV_GUIDE.md"
}

# Main setup function
main() {
    echo "=================================================="
    echo "🚀 Payment Gateway Local Development Setup"
    echo "=================================================="
    
    check_os
    check_prerequisites
    setup_database
    build_backend
    setup_frontend
    setup_test_merchant
    create_env_files
    create_startup_scripts
    create_dev_guide
    
    echo ""
    echo "=================================================="
    print_success "🎉 Setup completed successfully!"
    echo "=================================================="
    echo ""
    echo "📋 Next Steps:"
    echo "1. Start all services:"
    if [ "$DOCKER_AVAILABLE" = true ]; then
        echo "   docker-compose up -d"
    else
        echo "   ./start-backend.sh"
        echo "   ./start-frontend.sh (in new terminal)"
        echo "   ./start-test-merchant.sh (in new terminal)"
    fi
    echo ""
    echo "2. Access applications:"
    echo "   🌐 Dashboard: http://localhost:3000"
    echo "   🛍️ Test Store: http://localhost:3001"
    echo "   🔧 API Gateway: http://localhost:8080"
    echo ""
    echo "3. Login credentials:"
    echo "   👤 Admin: admin / password"
    echo "   🏪 Merchant: testmerchant / password"
    echo ""
    echo "📖 Read DEV_GUIDE.md for detailed development instructions"
    echo ""
}

# Run main function
main "$@"