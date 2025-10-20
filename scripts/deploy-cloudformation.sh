#!/bin/bash
set -e

# AWS CloudFormation Deployment Script
# This script deploys the FastAPI application to AWS using CloudFormation

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="${PROJECT_NAME:-fastapi-app}-${ENVIRONMENT:-production}"
TEMPLATE_FILE="infra/aws/cloudformation/main.yaml"
REGION="${AWS_REGION:-us-east-1}"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if required parameters are set
if [ -z "$DB_PASSWORD" ]; then
    print_error "DB_PASSWORD environment variable is required"
    exit 1
fi

if [ -z "$CONTAINER_IMAGE" ]; then
    print_error "CONTAINER_IMAGE environment variable is required"
    exit 1
fi

print_info "Starting CloudFormation deployment..."
print_info "Stack Name: $STACK_NAME"
print_info "Region: $REGION"
print_info "Template: $TEMPLATE_FILE"

# Validate CloudFormation template
print_info "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION

# Deploy stack
print_info "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --region $REGION \
    --parameter-overrides \
        ProjectName="${PROJECT_NAME:-fastapi-app}" \
        Environment="${ENVIRONMENT:-production}" \
        DBUsername="${DB_USERNAME:-dbadmin}" \
        DBPassword="$DB_PASSWORD" \
        DBInstanceClass="${DB_INSTANCE_CLASS:-db.t3.micro}" \
        ContainerImage="$CONTAINER_IMAGE" \
        ContainerPort="${CONTAINER_PORT:-8000}" \
        DesiredCount="${DESIRED_COUNT:-2}" \
        MinCapacity="${MIN_CAPACITY:-2}" \
        MaxCapacity="${MAX_CAPACITY:-6}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset

# Get stack outputs
print_info "Retrieving stack outputs..."
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs' \
    --output table

# Get Load Balancer URL
LB_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
    --output text)

print_info "Deployment complete!"
print_info "Application URL: $LB_URL"
print_info "Health check: $LB_URL/healthz"
print_info "API docs: $LB_URL/docs"

# Wait for service to be healthy
print_info "Waiting for service to become healthy (this may take a few minutes)..."
sleep 30

# Test health endpoint
print_info "Testing health endpoint..."
if curl -f -s "$LB_URL/healthz" > /dev/null; then
    print_info "Health check passed!"
else
    print_warn "Health check failed. The service may still be starting up."
    print_warn "Please check the ECS service logs in CloudWatch."
fi

print_info "Deployment finished successfully!"
