#!/bin/bash

set -e

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up monitoring and alerting for $ENVIRONMENT environment..."

# Function to create CloudWatch alarm
create_alarm() {
    local alarm_name=$1
    local metric_name=$2
    local namespace=$3
    local statistic=$4
    local threshold=$5
    local comparison_operator=$6
    local dimensions=$7
    local description=$8
    
    echo "Creating alarm: $alarm_name"
    aws cloudwatch put-metric-alarm \
        --alarm-name "PaymentGateway-${ENVIRONMENT}-${alarm_name}" \
        --alarm-description "$description" \
        --metric-name "$metric_name" \
        --namespace "$namespace" \
        --statistic "$statistic" \
        --period 300 \
        --threshold "$threshold" \
        --comparison-operator "$comparison_operator" \
        --dimensions "$dimensions" \
        --evaluation-periods 2 \
        --alarm-actions "arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:payment-gateway-${ENVIRONMENT}-alerts" \
        --tags Key=Environment,Value=$ENVIRONMENT Key=Project,Value=payment-gateway
}

# Create SNS topic for alerts
echo "Creating SNS topic for alerts..."
SNS_TOPIC_ARN=$(aws sns create-topic \
    --name "payment-gateway-${ENVIRONMENT}-alerts" \
    --tags Key=Environment,Value=$ENVIRONMENT Key=Project,Value=payment-gateway \
    --query 'TopicArn' --output text)

echo "SNS Topic ARN: $SNS_TOPIC_ARN"

# Subscribe email to SNS topic (replace with actual email)
# aws sns subscribe \
#     --topic-arn $SNS_TOPIC_ARN \
#     --protocol email \
#     --notification-endpoint your-email@example.com

# Create CloudWatch Log Groups with retention
echo "Creating CloudWatch Log Groups..."
for service in auth-service payment-service merchant-service transaction-service api-gateway frontend; do
    aws logs create-log-group --log-group-name "/ecs/payment-gateway-${service}-${ENVIRONMENT}" || true
    
    # Set retention policy
    if [ "$ENVIRONMENT" = "prod" ]; then
        retention_days=90
    else
        retention_days=30
    fi
    
    aws logs put-retention-policy \
        --log-group-name "/ecs/payment-gateway-${service}-${ENVIRONMENT}" \
        --retention-in-days $retention_days
done

# ECS Service Alarms
echo "Creating ECS service alarms..."

# CPU Utilization alarms
create_alarm "AuthService-HighCPU" "CPUUtilization" "AWS/ECS" "Average" "80" "GreaterThanThreshold" \
    "Name=ServiceName,Value=auth-service Name=ClusterName,Value=payment-gateway-${ENVIRONMENT}" \
    "Auth service CPU utilization is high"

create_alarm "PaymentService-HighCPU" "CPUUtilization" "AWS/ECS" "Average" "80" "GreaterThanThreshold" \
    "Name=ServiceName,Value=payment-service Name=ClusterName,Value=payment-gateway-${ENVIRONMENT}" \
    "Payment service CPU utilization is high"

# Memory Utilization alarms
create_alarm "AuthService-HighMemory" "MemoryUtilization" "AWS/ECS" "Average" "80" "GreaterThanThreshold" \
    "Name=ServiceName,Value=auth-service Name=ClusterName,Value=payment-gateway-${ENVIRONMENT}" \
    "Auth service memory utilization is high"

create_alarm "PaymentService-HighMemory" "MemoryUtilization" "AWS/ECS" "Average" "80" "GreaterThanThreshold" \
    "Name=ServiceName,Value=payment-service Name=ClusterName,Value=payment-gateway-${ENVIRONMENT}" \
    "Payment service memory utilization is high"

# ALB Alarms
echo "Creating ALB alarms..."
ALB_NAME=$(aws elbv2 describe-load-balancers \
    --names "payment-gateway-${ENVIRONMENT}-alb" \
    --query 'LoadBalancers[0].LoadBalancerName' --output text)

create_alarm "ALB-HighResponseTime" "TargetResponseTime" "AWS/ApplicationELB" "Average" "2" "GreaterThanThreshold" \
    "Name=LoadBalancer,Value=${ALB_NAME}" \
    "ALB response time is high"

create_alarm "ALB-High5XXErrors" "HTTPCode_Target_5XX_Count" "AWS/ApplicationELB" "Sum" "10" "GreaterThanThreshold" \
    "Name=LoadBalancer,Value=${ALB_NAME}" \
    "ALB 5XX error rate is high"

create_alarm "ALB-High4XXErrors" "HTTPCode_Target_4XX_Count" "AWS/ApplicationELB" "Sum" "50" "GreaterThanThreshold" \
    "Name=LoadBalancer,Value=${ALB_NAME}" \
    "ALB 4XX error rate is high"

# RDS Alarms
echo "Creating RDS alarms..."
create_alarm "RDS-HighCPU" "CPUUtilization" "AWS/RDS" "Average" "80" "GreaterThanThreshold" \
    "Name=DBInstanceIdentifier,Value=payment-gateway-${ENVIRONMENT}-db" \
    "RDS CPU utilization is high"

create_alarm "RDS-HighConnections" "DatabaseConnections" "AWS/RDS" "Average" "80" "GreaterThanThreshold" \
    "Name=DBInstanceIdentifier,Value=payment-gateway-${ENVIRONMENT}-db" \
    "RDS connection count is high"

create_alarm "RDS-LowFreeSpace" "FreeStorageSpace" "AWS/RDS" "Average" "2000000000" "LessThanThreshold" \
    "Name=DBInstanceIdentifier,Value=payment-gateway-${ENVIRONMENT}-db" \
    "RDS free storage space is low"

# Create CloudWatch Dashboard
echo "Creating CloudWatch Dashboard..."
cat > /tmp/dashboard-${ENVIRONMENT}.json << EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ECS", "CPUUtilization", "ServiceName", "auth-service", "ClusterName", "payment-gateway-${ENVIRONMENT}" ],
                    [ ".", "MemoryUtilization", ".", ".", ".", "." ],
                    [ ".", "CPUUtilization", "ServiceName", "payment-service", "ClusterName", "payment-gateway-${ENVIRONMENT}" ],
                    [ ".", "MemoryUtilization", ".", ".", ".", "." ],
                    [ ".", "CPUUtilization", "ServiceName", "merchant-service", "ClusterName", "payment-gateway-${ENVIRONMENT}" ],
                    [ ".", "MemoryUtilization", ".", ".", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${AWS_REGION}",
                "title": "ECS Service Metrics",
                "period": 300,
                "stat": "Average"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${ALB_NAME}" ],
                    [ ".", "TargetResponseTime", ".", "." ],
                    [ ".", "HTTPCode_Target_2XX_Count", ".", "." ],
                    [ ".", "HTTPCode_Target_4XX_Count", ".", "." ],
                    [ ".", "HTTPCode_Target_5XX_Count", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${AWS_REGION}",
                "title": "ALB Metrics",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "payment-gateway-${ENVIRONMENT}-db" ],
                    [ ".", "DatabaseConnections", ".", "." ],
                    [ ".", "FreeStorageSpace", ".", "." ],
                    [ ".", "ReadLatency", ".", "." ],
                    [ ".", "WriteLatency", ".", "." ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${AWS_REGION}",
                "title": "RDS Metrics",
                "period": 300,
                "stat": "Average"
            }
        },
        {
            "type": "log",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "query": "SOURCE '/ecs/payment-gateway-auth-service-${ENVIRONMENT}' | fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
                "region": "${AWS_REGION}",
                "title": "Recent Errors",
                "view": "table"
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
    --dashboard-name "PaymentGateway-${ENVIRONMENT}" \
    --dashboard-body file:///tmp/dashboard-${ENVIRONMENT}.json

# Clean up temp file
rm /tmp/dashboard-${ENVIRONMENT}.json

# Create custom metrics for application-level monitoring
echo "Setting up custom metrics..."
cat > /tmp/custom-metrics.sh << 'EOF'
#!/bin/bash

# This script should be run periodically (e.g., via cron) to send custom metrics

ENVIRONMENT=$1
AWS_REGION=${AWS_REGION:-us-east-1}

# Function to put custom metric
put_metric() {
    local metric_name=$1
    local value=$2
    local unit=${3:-Count}
    
    aws cloudwatch put-metric-data \
        --namespace "PaymentGateway/${ENVIRONMENT}" \
        --metric-data MetricName=$metric_name,Value=$value,Unit=$unit,Dimensions=Environment=$ENVIRONMENT
}

# Example: Monitor payment success rate
# This would typically be called from your application
# put_metric "PaymentSuccessRate" "95.5" "Percent"
# put_metric "ActiveUsers" "1250" "Count"
# put_metric "TransactionVolume" "50000" "Count"

EOF

chmod +x /tmp/custom-metrics.sh
mv /tmp/custom-metrics.sh scripts/send-custom-metrics.sh

# Create log analysis script
cat > scripts/analyze-logs.sh << 'EOF'
#!/bin/bash

ENVIRONMENT=${1:-dev}
SERVICE=${2:-auth-service}
HOURS=${3:-1}

echo "Analyzing logs for $SERVICE in $ENVIRONMENT environment (last $HOURS hours)..."

# Calculate start time
START_TIME=$(date -d "$HOURS hours ago" +%s)000

# Get error logs
echo "=== Error Logs ==="
aws logs filter-log-events \
    --log-group-name "/ecs/payment-gateway-${SERVICE}-${ENVIRONMENT}" \
    --start-time $START_TIME \
    --filter-pattern "ERROR" \
    --query 'events[*].[timestamp,message]' \
    --output table

# Get warning logs
echo "=== Warning Logs ==="
aws logs filter-log-events \
    --log-group-name "/ecs/payment-gateway-${SERVICE}-${ENVIRONMENT}" \
    --start-time $START_TIME \
    --filter-pattern "WARN" \
    --query 'events[*].[timestamp,message]' \
    --output table

# Get performance metrics from logs
echo "=== Performance Metrics ==="
aws logs filter-log-events \
    --log-group-name "/ecs/payment-gateway-${SERVICE}-${ENVIRONMENT}" \
    --start-time $START_TIME \
    --filter-pattern "[timestamp, level, thread, logger, message=\"*response_time*\"]" \
    --query 'events[*].message' \
    --output text | grep -o 'response_time=[0-9]*' | sort -n

EOF

chmod +x scripts/analyze-logs.sh

echo "Monitoring setup completed!"
echo ""
echo "Created resources:"
echo "- SNS Topic: $SNS_TOPIC_ARN"
echo "- CloudWatch Dashboard: PaymentGateway-${ENVIRONMENT}"
echo "- CloudWatch Alarms for ECS, ALB, and RDS"
echo "- Log Groups with retention policies"
echo "- Custom monitoring scripts"
echo ""
echo "Next steps:"
echo "1. Subscribe to SNS topic: aws sns subscribe --topic-arn $SNS_TOPIC_ARN --protocol email --notification-endpoint your-email@example.com"
echo "2. Set up custom application metrics using scripts/send-custom-metrics.sh"
echo "3. Review and adjust alarm thresholds based on your requirements"
echo "4. Set up log analysis automation using scripts/analyze-logs.sh"