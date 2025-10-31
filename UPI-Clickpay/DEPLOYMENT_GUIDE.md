# Production Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the Payment Gateway application to production using Docker Compose with comprehensive monitoring, security, and backup solutions.

## Architecture

### Production Stack
- **Application Services**: Java Spring Boot microservices
- **Database**: PostgreSQL with automated backups
- **Cache**: Redis for sessions and caching
- **Reverse Proxy**: Nginx with SSL termination
- **Monitoring**: Prometheus + Grafana
- **Logging**: ELK Stack (Elasticsearch + Kibana)
- **Container Orchestration**: Docker Compose

### Network Architecture
```
Internet → Nginx (SSL) → API Gateway → Microservices
                      → Frontend (React)
                      → Monitoring (Grafana/Kibana)
```

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB recommended)
- **Storage**: 100GB+ SSD
- **Network**: Static IP with domain name

### Software Requirements
- Docker 20.10+
- Docker Compose 2.0+
- Git
- SSL certificates for your domain

### Domain Setup
You'll need the following subdomains:
- `yourdomain.com` - Main application
- `api.yourdomain.com` - API endpoints
- `admin.yourdomain.com` - Monitoring dashboards

## Pre-Deployment Setup

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login to apply docker group changes
```

### 2. Clone Repository

```bash
git clone https://github.com/your-org/payment-gateway.git
cd payment-gateway
```

### 3. SSL Certificate Setup

#### Option A: Let's Encrypt (Recommended)
```bash
# Install Certbot
sudo apt install certbot

# Generate certificates
sudo certbot certonly --standalone -d yourdomain.com -d api.yourdomain.com -d admin.yourdomain.com

# Copy certificates
sudo mkdir -p ssl
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ssl/private.key
sudo chown -R $USER:$USER ssl/
```

#### Option B: Custom Certificates
```bash
# Create ssl directory
mkdir -p ssl

# Copy your certificates
cp your-cert.pem ssl/cert.pem
cp your-private-key.pem ssl/private.key
```

### 4. Environment Configuration

```bash
# Copy environment template
cp .env.prod.example .env.prod

# Edit configuration
nano .env.prod
```

#### Required Environment Variables

```bash
# Database Configuration
DB_NAME=payment_gateway_prod
DB_USER=pguser
DB_PASSWORD=your_very_secure_password_here

# Redis Configuration
REDIS_PASSWORD=your_redis_password_here

# JWT Configuration (minimum 32 characters)
JWT_SECRET=your_very_long_and_secure_jwt_secret_key_here_minimum_256_bits
JWT_EXPIRATION=86400000

# UPI Configuration
UPI_MERCHANT_ID=your_upi_merchant_id
UPI_MERCHANT_NAME=Your Company Name

# Bank API Configuration
BANK_API_URL=https://api.bank.com
BANK_API_KEY=your_bank_api_key

# HDFC Bank Configuration
HDFC_MERCHANT_ID=your_hdfc_merchant_id
HDFC_API_KEY=your_hdfc_api_key
HDFC_WEBHOOK_SECRET=your_hdfc_webhook_secret

# Frontend Configuration
FRONTEND_API_URL=https://api.yourdomain.com

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# Monitoring Configuration
GRAFANA_USER=admin
GRAFANA_PASSWORD=your_secure_grafana_password

# Domain Configuration
DOMAIN_NAME=yourdomain.com
API_DOMAIN=api.yourdomain.com
```

### 5. Update Nginx Configuration

Edit `nginx/conf.d/default.conf` and replace `yourdomain.com` with your actual domain:

```bash
sed -i 's/yourdomain.com/your-actual-domain.com/g' nginx/conf.d/default.conf
```

## Deployment Process

### 1. Automated Deployment (Recommended)

```bash
# Make deployment script executable
chmod +x scripts/deploy-production.sh

# Run deployment
./scripts/deploy-production.sh
```

The script will:
- ✅ Check prerequisites
- ✅ Validate environment variables
- ✅ Create necessary directories
- ✅ Backup existing deployment
- ✅ Build Docker images
- ✅ Deploy services in correct order
- ✅ Perform health checks
- ✅ Show deployment status

### 2. Manual Deployment

If you prefer manual control:

```bash
# Build backend services
cd backend
mvn clean package -DskipTests
cd ..

# Build and start infrastructure
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d postgres redis

# Wait for database
sleep 30

# Start application services
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d auth-service merchant-service transaction-service notification-service payment-service

# Start API Gateway
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d api-gateway

# Start frontend and proxy
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d frontend nginx

# Start monitoring
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d prometheus grafana elasticsearch kibana
```

## Post-Deployment Verification

### 1. Service Health Checks

```bash
# Check all services
docker-compose -f docker-compose.prod.yml ps

# Check specific service logs
docker-compose -f docker-compose.prod.yml logs -f api-gateway

# Test API endpoints
curl -f https://api.yourdomain.com/actuator/health
```

### 2. Application Testing

```bash
# Test frontend
curl -f https://yourdomain.com

# Test API authentication
curl -X POST https://api.yourdomain.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}'

# Test payment creation
curl -X POST https://api.yourdomain.com/api/payments/create \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount":100.00,"paymentMethod":"UPI_QR","description":"Test"}'
```

### 3. Monitoring Setup

Access monitoring dashboards:
- **Grafana**: https://admin.yourdomain.com/grafana/
- **Prometheus**: https://admin.yourdomain.com/prometheus/
- **Kibana**: https://admin.yourdomain.com/kibana/

Default Grafana credentials:
- Username: admin
- Password: (from GRAFANA_PASSWORD in .env.prod)

## Security Configuration

### 1. Firewall Setup

```bash
# Install UFW
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow ssh

# Allow HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Allow monitoring (restrict to your IP)
sudo ufw allow from YOUR_OFFICE_IP to any port 3001
sudo ufw allow from YOUR_OFFICE_IP to any port 9090
sudo ufw allow from YOUR_OFFICE_IP to any port 5601

# Enable firewall
sudo ufw enable
```

### 2. SSL Certificate Auto-Renewal

```bash
# Add cron job for certificate renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### 3. Database Security

```bash
# Connect to database
docker-compose -f docker-compose.prod.yml exec postgres psql -U pguser -d payment_gateway_prod

# Create read-only user for monitoring
CREATE USER monitoring WITH PASSWORD 'monitoring_password';
GRANT CONNECT ON DATABASE payment_gateway_prod TO monitoring;
GRANT USAGE ON SCHEMA public TO monitoring;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitoring;
```

## Backup and Recovery

### 1. Automated Backups

Backups are automatically created daily. To manually create a backup:

```bash
# Create manual backup
docker-compose -f docker-compose.prod.yml --profile backup up backup

# List backups
ls -la database/backup/
```

### 2. Restore from Backup

```bash
# Stop services
docker-compose -f docker-compose.prod.yml down

# Restore database
docker-compose -f docker-compose.prod.yml up -d postgres
sleep 30
docker-compose -f docker-compose.prod.yml exec -T postgres psql -U pguser -d payment_gateway_prod < database/backup/BACKUP_DATE/database.sql

# Start services
docker-compose -f docker-compose.prod.yml up -d
```

### 3. S3 Backup Configuration

Add to `.env.prod`:
```bash
BACKUP_S3_BUCKET=your-backup-bucket
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
```

## Monitoring and Alerting

### 1. Grafana Dashboards

Import pre-configured dashboards:
1. Login to Grafana
2. Go to Dashboards → Import
3. Import dashboards from `monitoring/grafana/dashboards/`

### 2. Prometheus Alerts

Configure alerts in `monitoring/prometheus/rules/`:

```yaml
# payment-gateway-alerts.yml
groups:
  - name: payment-gateway
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: High error rate detected
          
      - alert: DatabaseDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: Database is down
```

### 3. Log Analysis

Use Kibana to analyze logs:
1. Access Kibana at https://admin.yourdomain.com/kibana/
2. Create index patterns for application logs
3. Set up dashboards for error tracking

## Scaling and Performance

### 1. Horizontal Scaling

Scale specific services:
```bash
# Scale payment service
docker-compose -f docker-compose.prod.yml up -d --scale payment-service=3

# Update nginx upstream configuration
# Add multiple payment-service instances
```

### 2. Database Optimization

```sql
-- Connect to database
-- Optimize for production workload

-- Create indexes
CREATE INDEX CONCURRENTLY idx_payments_merchant_created 
ON payments(merchant_id, created_at);

CREATE INDEX CONCURRENTLY idx_payments_status_created 
ON payments(status, created_at);

-- Update statistics
ANALYZE;
```

### 3. Redis Optimization

Add to redis configuration:
```bash
# In docker-compose.prod.yml, update redis command:
command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes --maxmemory 1gb --maxmemory-policy allkeys-lru
```

## Troubleshooting

### 1. Common Issues

#### Service Won't Start
```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs service-name

# Check resource usage
docker stats

# Check disk space
df -h
```

#### Database Connection Issues
```bash
# Test database connectivity
docker-compose -f docker-compose.prod.yml exec postgres pg_isready -U pguser

# Check database logs
docker-compose -f docker-compose.prod.yml logs postgres
```

#### SSL Certificate Issues
```bash
# Test certificate
openssl x509 -in ssl/cert.pem -text -noout

# Check certificate expiry
openssl x509 -in ssl/cert.pem -noout -dates
```

### 2. Performance Issues

#### High CPU Usage
```bash
# Check container resource usage
docker stats

# Scale services if needed
docker-compose -f docker-compose.prod.yml up -d --scale payment-service=2
```

#### High Memory Usage
```bash
# Check memory usage
free -h

# Restart services if needed
docker-compose -f docker-compose.prod.yml restart
```

### 3. Emergency Procedures

#### Complete System Restart
```bash
# Stop all services
docker-compose -f docker-compose.prod.yml down

# Start infrastructure first
docker-compose -f docker-compose.prod.yml up -d postgres redis

# Wait and start applications
sleep 30
docker-compose -f docker-compose.prod.yml up -d
```

#### Rollback Deployment
```bash
# Stop current deployment
docker-compose -f docker-compose.prod.yml down

# Restore from backup
# (Follow backup restoration steps above)

# Deploy previous version
git checkout previous-tag
./scripts/deploy-production.sh
```

## Maintenance

### 1. Regular Tasks

#### Daily
- Monitor service health
- Check error logs
- Verify backup completion

#### Weekly
- Review performance metrics
- Update security patches
- Clean up old logs

#### Monthly
- Update dependencies
- Review and rotate secrets
- Capacity planning review

### 2. Update Procedure

```bash
# Create backup
./scripts/deploy-production.sh backup

# Pull latest code
git pull origin main

# Deploy updates
./scripts/deploy-production.sh

# Verify deployment
./scripts/deploy-production.sh health
```

## Support and Monitoring

### 1. Health Check Endpoints

- **API Gateway**: https://api.yourdomain.com/actuator/health
- **Individual Services**: https://api.yourdomain.com/actuator/health/{service}
- **Frontend**: https://yourdomain.com/health

### 2. Log Locations

```bash
# Application logs
docker-compose -f docker-compose.prod.yml logs -f service-name

# Nginx logs
docker-compose -f docker-compose.prod.yml exec nginx tail -f /var/log/nginx/access.log

# System logs
journalctl -u docker
```

### 3. Monitoring URLs

- **Grafana**: https://admin.yourdomain.com/grafana/
- **Prometheus**: https://admin.yourdomain.com/prometheus/
- **Kibana**: https://admin.yourdomain.com/kibana/

This production deployment provides a robust, scalable, and secure payment gateway solution with comprehensive monitoring and backup capabilities.