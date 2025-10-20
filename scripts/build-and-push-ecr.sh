#!/bin/bash
set -e

# Build and Push Docker Image to ECR
# This script builds the Docker image and pushes it to Amazon ECR

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="${PROJECT_NAME:-fastapi-app}"
ENVIRONMENT="${ENVIRONMENT:-production}"
REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

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

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

# Get AWS Account ID if not set
if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_info "Getting AWS Account ID..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

# Set ECR repository details
REPOSITORY_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR_URI}/${REPOSITORY_NAME}:${IMAGE_TAG}"

print_info "Starting Docker build and push process..."
print_info "AWS Account ID: $AWS_ACCOUNT_ID"
print_info "Region: $REGION"
print_info "Repository: $REPOSITORY_NAME"
print_info "Image URI: $IMAGE_URI"

# Create ECR repository if it doesn't exist
print_info "Checking if ECR repository exists..."
if ! aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION &> /dev/null; then
    print_info "Creating ECR repository..."
    aws ecr create-repository \
        --repository-name $REPOSITORY_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
    print_info "ECR repository created successfully"
else
    print_info "ECR repository already exists"
fi

# Login to ECR
print_info "Logging in to ECR..."
aws ecr get-login-password --region $REGION | \
    docker login --username AWS --password-stdin $ECR_URI

# Build Docker image
print_info "Building Docker image..."
docker build -t $REPOSITORY_NAME:$IMAGE_TAG .

# Tag image for ECR
print_info "Tagging image for ECR..."
docker tag $REPOSITORY_NAME:$IMAGE_TAG $IMAGE_URI

# Push image to ECR
print_info "Pushing image to ECR..."
docker push $IMAGE_URI

# Get image digest
IMAGE_DIGEST=$(aws ecr describe-images \
    --repository-name $REPOSITORY_NAME \
    --image-ids imageTag=$IMAGE_TAG \
    --region $REGION \
    --query 'imageDetails[0].imageDigest' \
    --output text)

print_info "Image pushed successfully!"
print_info "Image URI: $IMAGE_URI"
print_info "Image Digest: $IMAGE_DIGEST"

# Run security scan
print_info "Initiating security scan..."
aws ecr start-image-scan \
    --repository-name $REPOSITORY_NAME \
    --image-id imageTag=$IMAGE_TAG \
    --region $REGION || true

print_info "Build and push completed successfully!"
print_info "You can now use this image URI in your deployment: $IMAGE_URI"
