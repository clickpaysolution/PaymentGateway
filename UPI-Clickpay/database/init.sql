-- Payment Gateway Database Schema

-- Users table (for authentication)
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'MERCHANT',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Merchants table
CREATE TABLE IF NOT EXISTS merchants (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(id),
    business_name VARCHAR(255),
    api_key VARCHAR(255) UNIQUE NOT NULL,
    webhook_url VARCHAR(500),
    upi_id VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    merchant_id BIGINT NOT NULL REFERENCES merchants(user_id),
    transaction_id VARCHAR(100) UNIQUE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    payment_method VARCHAR(20),
    upi_id VARCHAR(100),
    upi_provider VARCHAR(50),
    bank_reference VARCHAR(100),
    qr_code_data TEXT,
    callback_url VARCHAR(500),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Transactions table (for reporting)
CREATE TABLE IF NOT EXISTS transactions (
    id BIGSERIAL PRIMARY KEY,
    payment_id BIGINT NOT NULL REFERENCES payments(id),
    merchant_id BIGINT NOT NULL,
    transaction_id VARCHAR(100) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    payment_method VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- API Keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id BIGSERIAL PRIMARY KEY,
    merchant_id BIGINT NOT NULL REFERENCES merchants(id),
    api_key VARCHAR(255) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payments_merchant_id ON payments(merchant_id);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_merchant_id ON transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

-- Insert default admin user
INSERT INTO users (username, email, password, role) 
VALUES ('admin', 'admin@paymentgateway.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'ADMIN')
ON CONFLICT (username) DO NOTHING;

-- Insert sample merchant for testing
INSERT INTO users (username, email, password, role) 
VALUES ('testmerchant', 'merchant@test.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'MERCHANT')
ON CONFLICT (username) DO NOTHING;

-- Add new columns to merchants table for operation modes
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS operation_mode VARCHAR(20) DEFAULT 'FULL_PROCESSOR';
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS fee_structure TEXT;
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS bank_config TEXT;
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS settlement_config TEXT;

-- Insert merchant record for test merchant
INSERT INTO merchants (user_id, business_name, api_key, upi_id, operation_mode)
SELECT u.id, 'Test Business', 'test_api_key_123', 'testmerchant@upi', 'FULL_PROCESSOR'
FROM users u 
WHERE u.username = 'testmerchant'
ON CONFLICT (user_id) DO NOTHING;