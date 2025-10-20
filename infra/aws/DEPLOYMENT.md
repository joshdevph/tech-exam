# AWS Deployment Guide - FastAPI Application

This guide provides comprehensive instructions for deploying the FastAPI application to AWS using Infrastructure as Code (IaC).

## Table of Contents
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Deployment Options](#deployment-options)
- [Option 1: CloudFormation Deployment](#option-1-cloudformation-deployment)
- [Option 2: Terraform Deployment](#option-2-terraform-deployment)
- [Option 3: Elastic Beanstalk Deployment](#option-3-elastic-beanstalk-deployment)
- [Post-Deployment Steps](#post-deployment-steps)
- [Monitoring and Logging](#monitoring-and-logging)
- [Scaling Configuration](#scaling-configuration)
- [Security Best Practices](#security-best-practices)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools
1. **AWS CLI** - Version 2.x or higher
   ```bash
   # Install AWS CLI
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Configure AWS credentials
   aws configure
   ```

2. **Docker** - For building container images
   ```bash
   # Verify Docker installation
   docker --version
   ```

3. **Terraform** (Optional - for Terraform deployment)
   ```bash
   # Install Terraform
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/

   # Verify installation
   terraform --version
   ```

### AWS Account Setup
1. **IAM User/Role** with following permissions:
   - VPC, EC2, RDS management
   - ECS, ECR access
   - CloudFormation or Terraform deployment
   - Secrets Manager access
   - CloudWatch Logs access
   - Application Load Balancer management

2. **AWS Region Selection**
   - Choose a region close to your users (default: us-east-1)
   - Ensure all services are available in your chosen region

## Architecture Overview

The deployment creates the following AWS infrastructure:

```
┌─────────────────────────────────────────────────────────┐
│                     Internet                             │
└───────────────────────┬─────────────────────────────────┘
                        │
                ┌───────▼────────┐
                │ Application    │
                │ Load Balancer  │
                └───────┬────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼────────┐             ┌───────▼────────┐
│   ECS Task     │             │   ECS Task     │
│  (Container)   │             │  (Container)   │
│ Public Subnet  │             │ Public Subnet  │
│     AZ-1       │             │     AZ-2       │
└───────┬────────┘             └───────┬────────┘
        │                               │
        └───────────────┬───────────────┘
                        │
                ┌───────▼────────┐
                │  RDS Postgres  │
                │ Private Subnet │
                │   Multi-AZ     │
                └────────────────┘
```

### Key Components:
- **VPC**: Isolated network with public and private subnets across 2 AZs
- **Application Load Balancer**: Distributes traffic across ECS tasks
- **ECS Fargate**: Serverless container orchestration
- **RDS PostgreSQL**: Managed database with automated backups
- **Secrets Manager**: Secure storage for database credentials
- **CloudWatch**: Centralized logging and monitoring
- **Auto Scaling**: Automatic scaling based on CPU/Memory utilization

## Deployment Options

### Quick Comparison

| Feature | CloudFormation | Terraform | Elastic Beanstalk |
|---------|---------------|-----------|-------------------|
| AWS Native | ✅ Yes | ❌ No | ✅ Yes |
| Learning Curve | Medium | Medium | Easy |
| Flexibility | High | Very High | Medium |
| State Management | AWS Managed | Manual | AWS Managed |
| Multi-Cloud | ❌ No | ✅ Yes | ❌ No |
| Best For | AWS-only deployments | Multi-cloud or complex infra | Quick prototypes |

---

## Option 1: CloudFormation Deployment

CloudFormation is AWS's native IaC service, perfect for AWS-only deployments.

### Step 1: Build and Push Docker Image

```bash
# Set environment variables
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export PROJECT_NAME=fastapi-app
export ENVIRONMENT=production
export IMAGE_TAG=v1.0.0

# Build and push image to ECR
bash scripts/build-and-push-ecr.sh
```

The script will output the image URI. Save it for the next step:
```
Image URI: 123456789012.dkr.ecr.us-east-1.amazonaws.com/fastapi-app-production:v1.0.0
```

### Step 2: Deploy Infrastructure

```bash
# Set deployment parameters
export CONTAINER_IMAGE="123456789012.dkr.ecr.us-east-1.amazonaws.com/fastapi-app-production:v1.0.0"
export DB_PASSWORD="YourSecurePassword123!"  # Use a strong password
export DB_USERNAME="dbadmin"

# Deploy using CloudFormation
bash scripts/deploy-cloudformation.sh
```

### Step 3: Verify Deployment

```bash
# Get stack outputs
aws cloudformation describe-stacks \
    --stack-name fastapi-app-production \
    --region us-east-1 \
    --query 'Stacks[0].Outputs'

# Test the application
LOAD_BALANCER_URL=$(aws cloudformation describe-stacks \
    --stack-name fastapi-app-production \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
    --output text)

curl $LOAD_BALANCER_URL/healthz
curl $LOAD_BALANCER_URL/docs
```

### Manual CloudFormation Deployment

If you prefer manual deployment:

```bash
aws cloudformation create-stack \
    --stack-name fastapi-app-production \
    --template-body file://infra/aws/cloudformation/main.yaml \
    --parameters \
        ParameterKey=ProjectName,ParameterValue=fastapi-app \
        ParameterKey=Environment,ParameterValue=production \
        ParameterKey=DBUsername,ParameterValue=dbadmin \
        ParameterKey=DBPassword,ParameterValue=YourSecurePassword123! \
        ParameterKey=ContainerImage,ParameterValue=YOUR_ECR_IMAGE_URI \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1

# Monitor stack creation
aws cloudformation wait stack-create-complete \
    --stack-name fastapi-app-production \
    --region us-east-1
```

### Update Existing Stack

```bash
aws cloudformation update-stack \
    --stack-name fastapi-app-production \
    --template-body file://infra/aws/cloudformation/main.yaml \
    --parameters \
        ParameterKey=ContainerImage,ParameterValue=NEW_IMAGE_URI \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1
```

### Delete Stack

```bash
aws cloudformation delete-stack \
    --stack-name fastapi-app-production \
    --region us-east-1
```

---

## Option 2: Terraform Deployment

Terraform provides a declarative approach with excellent state management.

### Step 1: Initialize Terraform

```bash
cd infra/aws/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars
```

### Step 2: Configure Variables

Edit `terraform.tfvars`:

```hcl
# General Configuration
project_name = "fastapi-app"
environment  = "production"
aws_region   = "us-east-1"

# Database Configuration
db_username        = "dbadmin"
db_password        = "YourSecurePassword123!"
db_instance_class  = "db.t3.small"
db_allocated_storage = 20

# Container Configuration
container_image  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:latest"
container_port   = 8000

# Scaling Configuration
desired_count    = 2
min_capacity     = 2
max_capacity     = 6

# Task Resources
ecs_task_cpu    = "512"
ecs_task_memory = "1024"
```

### Step 3: Deploy with Terraform

```bash
# Automated deployment
bash scripts/deploy-terraform.sh

# Or manual steps:
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 4: View Outputs

```bash
terraform output

# Get specific output
terraform output -raw load_balancer_url
```

### Update Infrastructure

```bash
# Modify terraform.tfvars or .tf files
terraform plan
terraform apply
```

### Destroy Infrastructure

```bash
terraform destroy
```

### Remote State Configuration

For team collaboration, configure remote state:

```hcl
# In main.tf, uncomment and configure:
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "fastapi-app/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

Create the S3 bucket and DynamoDB table:

```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
    --bucket your-terraform-state-bucket \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

---

## Option 3: Elastic Beanstalk Deployment

Elastic Beanstalk provides the simplest deployment option with minimal configuration.

### Step 1: Install EB CLI

```bash
pip install awsebcli
eb --version
```

### Step 2: Initialize Application

```bash
# Initialize Elastic Beanstalk
eb init -p docker fastapi-app --region us-east-1

# Create environment
eb create fastapi-production \
    --instance-type t3.small \
    --envvars \
        DATABASE_URL=postgresql://user:pass@host:5432/db,\
        SECRET_KEY=your-secret-key \
    --database \
    --database.engine postgres \
    --database.version 15.4
```

### Step 3: Deploy Application

```bash
# Deploy application
eb deploy

# Open in browser
eb open

# Check health
eb health
```

### Step 4: Configure Environment

```bash
# Set environment variables
eb setenv \
    ENVIRONMENT=production \
    PROJECT_NAME=fastapi-app

# Scale application
eb scale 2
```

### Elastic Beanstalk Configuration Files

The project includes `.ebextensions` for:
- Python/FastAPI configuration
- Nginx proxy settings
- Health check endpoints

---

## Post-Deployment Steps

### 1. Database Migration

After deployment, run database migrations:

```bash
# Get ECS task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster fastapi-app-production-cluster \
    --service-name fastapi-app-production-service \
    --query 'taskArns[0]' \
    --output text \
    --region us-east-1)

# Run migration command
aws ecs execute-command \
    --cluster fastapi-app-production-cluster \
    --task $TASK_ARN \
    --container fastapi-app-container \
    --interactive \
    --command "alembic upgrade head" \
    --region us-east-1
```

### 2. Test API Endpoints

```bash
# Get Load Balancer URL
LB_URL="http://your-alb-url.amazonaws.com"

# Test health endpoint
curl $LB_URL/healthz

# Register a user
curl -X POST $LB_URL/auth/register \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test@example.com",
        "password": "SecurePassword123!",
        "full_name": "Test User"
    }'

# Login
curl -X POST $LB_URL/auth/login \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test@example.com",
        "password": "SecurePassword123!"
    }'

# Access API docs
echo "Visit: $LB_URL/docs"
```

### 3. Configure Domain Name (Optional)

```bash
# Create Route 53 hosted zone (if needed)
aws route53 create-hosted-zone \
    --name example.com \
    --caller-reference $(date +%s)

# Create A record pointing to ALB
aws route53 change-resource-record-sets \
    --hosted-zone-id YOUR_ZONE_ID \
    --change-batch '{
        "Changes": [{
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "api.example.com",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "ALB_HOSTED_ZONE_ID",
                    "DNSName": "your-alb-dns-name.amazonaws.com",
                    "EvaluateTargetHealth": true
                }
            }
        }]
    }'
```

### 4. Enable HTTPS (Recommended)

```bash
# Request SSL certificate
aws acm request-certificate \
    --domain-name api.example.com \
    --validation-method DNS \
    --region us-east-1

# Add HTTPS listener to ALB
aws elbv2 create-listener \
    --load-balancer-arn YOUR_ALB_ARN \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn=YOUR_CERT_ARN \
    --default-actions Type=forward,TargetGroupArn=YOUR_TG_ARN
```

---

## Monitoring and Logging

### CloudWatch Logs

```bash
# View ECS logs
aws logs tail /ecs/fastapi-app-production --follow

# Query logs
aws logs filter-log-events \
    --log-group-name /ecs/fastapi-app-production \
    --filter-pattern "ERROR"
```

### CloudWatch Metrics

Monitor these key metrics:
- **ECS Service**: CPU/Memory utilization, Running task count
- **ALB**: Request count, Target response time, HTTP 4xx/5xx errors
- **RDS**: CPU utilization, Database connections, Read/Write IOPS

### Set Up Alarms

```bash
# CPU utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name fastapi-high-cpu \
    --alarm-description "Alert when CPU exceeds 80%" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2

# Database connection alarm
aws cloudwatch put-metric-alarm \
    --alarm-name fastapi-high-db-connections \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold
```

---

## Scaling Configuration

### Auto-Scaling Policies

The infrastructure includes automatic scaling based on:

1. **CPU Utilization** (Target: 70%)
2. **Memory Utilization** (Target: 80%)

### Manual Scaling

```bash
# Scale ECS service
aws ecs update-service \
    --cluster fastapi-app-production-cluster \
    --service fastapi-app-production-service \
    --desired-count 4

# Scale RDS (requires downtime)
aws rds modify-db-instance \
    --db-instance-identifier fastapi-app-production-db \
    --db-instance-class db.t3.medium \
    --apply-immediately
```

---

## Security Best Practices

### 1. Secrets Management
- ✅ Use AWS Secrets Manager for sensitive data
- ✅ Never commit secrets to version control
- ✅ Rotate database credentials regularly

### 2. Network Security
- ✅ ECS tasks in private subnets
- ✅ RDS in private subnets with no public access
- ✅ Security groups with minimal required access
- ✅ Use VPC endpoints for AWS services (optional)

### 3. Data Encryption
- ✅ RDS encryption at rest enabled
- ✅ ECS task encryption in transit (TLS)
- ✅ S3 encryption for logs and backups

### 4. IAM Best Practices
- ✅ Least privilege access
- ✅ Separate roles for execution and task
- ✅ Enable MFA for AWS console access

### 5. Container Security
- ✅ ECR image scanning enabled
- ✅ Use official base images
- ✅ Regular security updates

---

## Cost Optimization

### Estimated Monthly Costs (us-east-1)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| ECS Fargate (2 tasks) | 0.5 vCPU, 1GB RAM | ~$30 |
| RDS PostgreSQL | db.t3.micro | ~$15 |
| Application Load Balancer | - | ~$16 |
| NAT Gateway | 1 gateway | ~$32 |
| Data Transfer | 10GB | ~$1 |
| **Total** | | **~$94/month** |

### Cost Optimization Tips

1. **Use Fargate Spot** for non-critical workloads (up to 70% savings)
2. **RDS Reserved Instances** for production (up to 60% savings)
3. **Remove NAT Gateway** for development environments
4. **Enable S3 lifecycle policies** for old logs
5. **Use Auto Scaling** to match demand

---

## Troubleshooting

### Common Issues

#### 1. ECS Tasks Not Starting

```bash
# Check task status
aws ecs describe-tasks \
    --cluster fastapi-app-production-cluster \
    --tasks TASK_ARN

# Common causes:
# - Incorrect container image
# - Insufficient task permissions
# - Database connectivity issues
```

#### 2. Health Check Failures

```bash
# Check target health
aws elbv2 describe-target-health \
    --target-group-arn YOUR_TG_ARN

# Solutions:
# - Verify /healthz endpoint is accessible
# - Check security group rules
# - Review application logs
```

#### 3. Database Connection Errors

```bash
# Test database connectivity from ECS task
aws ecs execute-command \
    --cluster fastapi-app-production-cluster \
    --task TASK_ARN \
    --interactive \
    --command "/bin/bash"

# Then inside container:
curl $DB_HOST:$DB_PORT
```

#### 4. Permission Denied Errors

```bash
# Verify IAM roles
aws iam get-role --role-name fastapi-app-production-ecs-execution-role
aws iam list-attached-role-policies --role-name fastapi-app-production-ecs-execution-role
```

### Useful Commands

```bash
# View ECS service events
aws ecs describe-services \
    --cluster fastapi-app-production-cluster \
    --services fastapi-app-production-service \
    --query 'services[0].events'

# Check CloudFormation stack events
aws cloudformation describe-stack-events \
    --stack-name fastapi-app-production

# Restart ECS service
aws ecs update-service \
    --cluster fastapi-app-production-cluster \
    --service fastapi-app-production-service \
    --force-new-deployment
```

---

## Next Steps

1. **Set up CI/CD** - Automate deployments with GitHub Actions or AWS CodePipeline
2. **Configure monitoring** - Set up comprehensive CloudWatch dashboards
3. **Implement caching** - Add Redis/ElastiCache for performance
4. **Add WAF** - Protect against common web exploits
5. **Enable backup automation** - Automated RDS snapshots and retention policies

---

## Support and Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

**Last Updated**: October 2024
**Maintained By**: DevOps Team
