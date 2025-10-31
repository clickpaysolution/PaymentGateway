#!/bin/bash

echo "Starting Payment Gateway Application..."

# Start with Docker Compose
docker-compose up -d

echo "Application started successfully!"
echo "Frontend: http://localhost:3000"
echo "API Gateway: http://localhost:8080"
echo "Auth Service: http://localhost:8081"
echo "Payment Service: http://localhost:8083"

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 30

echo "Services are ready!"
echo "You can now access the application at http://localhost:3000"