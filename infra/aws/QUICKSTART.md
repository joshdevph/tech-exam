# AWS Deployment Quick Start Guide

This is a condensed guide to get your FastAPI application deployed to AWS in under 30 minutes.

## Prerequisites (5 minutes)

1. **AWS Account** with admin access
2. **AWS CLI** configured:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and default region
   ```
3. **Docker** installed and running

## Deployment Steps

### Step 1: Build and Push Docker Image (5 minutes)

```bash
# Set environment variables
export AWS_REGION=us-east-1
export PROJECT_NAME=fastapi-app
export ENVIRONMENT=production
export IMAGE_TAG=v1.0.0

# Run the build script
bash scripts/build-and-push-ecr.sh
```

**Output**: You'll get an image URI like:
```
123456789012.dkr.ecr.us-east-1.amazonaws.com/fastapi-app-production:v1.0.0
```
**Save this URI** - you'll need it in the next step.

### Step 2: Deploy Infrastructure (15-20 minutes)

Choose **ONE** of the following methods:

#### Option A: CloudFormation (Easiest)

```bash
# Set required variables
export CONTAINER_IMAGE="<your-image-uri-from-step-1>"
export DB_PASSWORD="YourSecurePassword123!"  # Choose a strong password

# Deploy
bash scripts/deploy-cloudformation.sh
```

The script will:
- Create VPC, subnets, and networking
- Launch RDS PostgreSQL database
- Deploy ECS Fargate cluster
- Configure Application Load Balancer
- Set up auto-scaling

**Wait time**: 15-20 minutes

#### Option B: Terraform

```bash
# Configure variables
cd infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
# - Set container_image to your ECR URI
# - Set db_password to a secure password
# - Adjust other settings as needed

# Deploy
bash scripts/deploy-terraform.sh
```

**Wait time**: 15-20 minutes

#### Option C: Elastic Beanstalk (Fastest)

```bash
# Install EB CLI
pip install awsebcli

# Initialize
eb init -p docker fastapi-app --region us-east-1

# Create environment with database
eb create fastapi-production \
    --instance-type t3.small \
    --database \
    --database.engine postgres \
    --database.version 15.4

# Deploy
eb deploy
```

**Wait time**: 10-15 minutes

### Step 3: Verify Deployment (2 minutes)

**For CloudFormation/Terraform:**
```bash
# Get your application URL (CloudFormation)
aws cloudformation describe-stacks \
    --stack-name fastapi-app-production \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
    --output text

# Or for Terraform
cd infra/aws/terraform
terraform output load_balancer_url
```

**For Elastic Beanstalk:**
```bash
eb open
```

**Test the API:**
```bash
# Replace with your actual URL
export API_URL="http://your-alb-url.amazonaws.com"

# Health check
curl $API_URL/healthz

# API documentation
open $API_URL/docs
```

### Step 4: Test Authentication (3 minutes)

```bash
# Register a user
curl -X POST $API_URL/auth/register \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test@example.com",
        "password": "SecurePassword123!",
        "full_name": "Test User"
    }'

# Login
curl -X POST $API_URL/auth/login \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test@example.com",
        "password": "SecurePassword123!"
    }'
# Save the access_token from response

# Create an item (replace <TOKEN> with your actual token)
curl -X POST $API_URL/items \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer <TOKEN>" \
    -d '{
        "title": "My First Item",
        "description": "Created via API"
    }'

# List items
curl -X GET $API_URL/items \
    -H "Authorization: Bearer <TOKEN>"
```

## You're Done!

Your FastAPI application is now running on AWS with:
- ✅ Auto-scaling based on CPU/Memory
- ✅ Multi-AZ high availability
- ✅ Encrypted database with automated backups
- ✅ Load balancing across multiple instances
- ✅ Centralized logging in CloudWatch

## Next Steps

1. **Set up a custom domain**: See [DEPLOYMENT.md](DEPLOYMENT.md#configure-domain-name-optional)
2. **Enable HTTPS**: See [DEPLOYMENT.md](DEPLOYMENT.md#enable-https-recommended)
3. **Configure monitoring**: See [DEPLOYMENT.md](DEPLOYMENT.md#monitoring-and-logging)
4. **Review security**: See [SECURITY.md](SECURITY.md)

## Troubleshooting

### Issue: Health check failing

```bash
# Check ECS service status
aws ecs describe-services \
    --cluster fastapi-app-production-cluster \
    --services fastapi-app-production-service

# Check logs
aws logs tail /ecs/fastapi-app-production --follow
```

### Issue: Can't connect to database

```bash
# Verify RDS is running
aws rds describe-db-instances \
    --db-instance-identifier fastapi-app-production-db

# Check security groups allow traffic
aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=*fastapi-app*"
```

### Issue: Container won't start

```bash
# Check task definition
aws ecs describe-task-definition \
    --task-definition fastapi-app-production

# Verify secrets exist
aws secretsmanager get-secret-value \
    --secret-id fastapi-app-production-db-credentials
```

## Clean Up (To avoid charges)

**CloudFormation:**
```bash
aws cloudformation delete-stack \
    --stack-name fastapi-app-production
```

**Terraform:**
```bash
cd infra/aws/terraform
terraform destroy
```

**Elastic Beanstalk:**
```bash
eb terminate fastapi-production
```

## Cost Estimate

- **Development**: ~$50-70/month
- **Production**: ~$94-150/month

Costs include: ECS Fargate, RDS, ALB, NAT Gateway, data transfer.

## Support

For detailed documentation:
- [Complete Deployment Guide](DEPLOYMENT.md)
- [Security Best Practices](SECURITY.md)
- [Main README](../../README.md)

---

**Happy deploying!** 🚀
