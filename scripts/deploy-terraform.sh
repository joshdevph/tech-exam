#!/bin/bash
set -e

# Terraform Deployment Script
# This script deploys the FastAPI application to AWS using Terraform

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="infra/aws/terraform"
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

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

# Navigate to Terraform directory
cd $TERRAFORM_DIR

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warn "terraform.tfvars not found. Creating from example..."
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        print_warn "Please edit terraform.tfvars with your actual values before continuing."
        exit 1
    else
        print_error "terraform.tfvars.example not found!"
        exit 1
    fi
fi

print_info "Starting Terraform deployment..."
print_info "Working directory: $(pwd)"

# Initialize Terraform
print_info "Initializing Terraform..."
terraform init

# Validate Terraform configuration
print_info "Validating Terraform configuration..."
terraform validate

# Format Terraform files
print_info "Formatting Terraform files..."
terraform fmt -recursive

# Plan deployment
print_info "Planning Terraform deployment..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "Do you want to apply this plan? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    print_warn "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

# Apply Terraform plan
print_info "Applying Terraform plan..."
terraform apply tfplan

# Remove plan file
rm -f tfplan

# Get outputs
print_info "Retrieving outputs..."
terraform output

# Get Load Balancer URL
LB_URL=$(terraform output -raw load_balancer_url 2>/dev/null || echo "")
if [ -n "$LB_URL" ]; then
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
fi

print_info "Deployment finished successfully!"
print_info "To destroy the infrastructure, run: terraform destroy"
