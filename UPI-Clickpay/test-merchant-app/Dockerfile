FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Set environment variables
ENV PORT=3001
ENV REACT_APP_PAYMENT_GATEWAY_URL=http://localhost:8080
ENV REACT_APP_MERCHANT_API_KEY=test_api_key_123

# Expose port
EXPOSE 3001

# Start the application
CMD ["npm", "start"]