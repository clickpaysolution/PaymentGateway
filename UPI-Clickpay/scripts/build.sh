#!/bin/bash

echo "Building Payment Gateway Application..."

# Build backend services
echo "Building backend services..."
cd backend

# Build parent project
mvn clean install -DskipTests

# Build individual services
cd auth-service && mvn clean package -DskipTests && cd ..
cd payment-service && mvn clean package -DskipTests && cd ..
cd merchant-service && mvn clean package -DskipTests && cd ..
cd transaction-service && mvn clean package -DskipTests && cd ..
cd api-gateway && mvn clean package -DskipTests && cd ..

cd ..

# Build frontend
echo "Building frontend..."
cd frontend
npm install
npm run build
cd ..

echo "Build completed successfully!"