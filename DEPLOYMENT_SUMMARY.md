# AWS Deployment - Infrastructure as Code Summary

## Overview

This FastAPI application now includes complete Infrastructure as Code (IaC) for AWS deployment. You can deploy using **CloudFormation**, **Terraform**, or **Elastic Beanstalk**.

## What's Included

### 1. CloudFormation Templates
Location: `infra/aws/cloudformation/`

- **main.yaml** - Complete infrastructure stack including:
  - VPC with public/private subnets (Multi-AZ)
  - RDS PostgreSQL database (encrypted)
  - ECS Fargate cluster with auto-scaling
  - Application Load Balancer
  - Security Groups
  - Secrets Manager integration
  - CloudWatch logging
  - Auto-scaling policies

- **parameters.json.example** - Example parameters file

### 2. Terraform Configuration
Location: `infra/aws/terraform/`

**Main Configuration:**
- `main.tf` - Root Terraform configuration
- `variables.tf` - Input variables with validation
- `terraform.tfvars.example` - Example values

**Modular Components:**
- `modules/vpc/` - VPC, subnets, NAT gateways, route tables
- `modules/security/` - Security groups for ALB, ECS, and RDS
- `modules/rds/` - PostgreSQL database configuration
- `modules/alb/` - Application Load Balancer and target groups
- `modules/ecs/` - ECS cluster, task definitions, services, auto-scaling

### 3. Elastic Beanstalk Configuration
Location: `.ebextensions/` and `.platform/`

- `.ebextensions/01_flask.config` - Python/WSGI configuration
- `.ebextensions/02_python.config` - Process and thread settings
- `.platform/nginx/conf.d/custom.conf` - Nginx reverse proxy configuration

### 4. Deployment Scripts
Location: `scripts/`

- **build-and-push-ecr.sh** - Builds Docker image and pushes to ECR
- **deploy-cloudformation.sh** - Automated CloudFormation deployment
- **deploy-terraform.sh** - Automated Terraform deployment

### 5. CI/CD Pipeline
Location: `.github/workflows/`

- **deploy-aws.yml** - Complete GitHub Actions workflow with:
  - Docker image building and pushing to ECR
  - Security scanning
  - Terraform deployment
  - Database migrations
  - Health checks

### 6. Documentation

- **infra/aws/DEPLOYMENT.md** - Complete deployment guide (60+ pages) covering:
  - Prerequisites and setup
  - Deployment options comparison
  - Step-by-step instructions for each method
  - Post-deployment configuration
  - Monitoring and logging
  - Troubleshooting
  - Cost optimization

- **infra/aws/SECURITY.md** - Security best practices including:
  - Network security (VPC, Security Groups, NACLs)
  - Encryption (at rest and in transit)
  - IAM policies and roles
  - Secrets management
  - Application security
  - Monitoring and incident response
  - Compliance checklist

- **infra/aws/QUICKSTART.md** - Quick 30-minute deployment guide

- **Makefile** - Convenient make commands for common tasks

## Quick Start

### Option 1: CloudFormation (Recommended for AWS-only)

```bash
# Build and push Docker image
export AWS_REGION=us-east-1
export IMAGE_TAG=v1.0.0
bash scripts/build-and-push-ecr.sh

# Deploy infrastructure
export CONTAINER_IMAGE="<your-ecr-image-uri>"
export DB_PASSWORD="YourSecurePassword123!"
bash scripts/deploy-cloudformation.sh
```

### Option 2: Terraform (Recommended for multi-cloud)

```bash
# Build and push Docker image
bash scripts/build-and-push-ecr.sh

# Configure Terraform
cd infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
bash scripts/deploy-terraform.sh
```

### Option 3: Using Makefile

```bash
# See all available commands
make help

# Quick deployment with CloudFormation
make build-push IMAGE_TAG=v1.0.0
make deploy-cf DB_PASSWORD=YourPassword CONTAINER_IMAGE=your-image-uri

# Or with Terraform
make quick-deploy-tf
```

## Infrastructure Components

### Network Architecture
```
Internet
    ↓
Application Load Balancer (Public Subnets)
    ↓
ECS Fargate Tasks (Private Subnets)
    ↓
RDS PostgreSQL (Private Subnets)
```

### Resources Created

| Component | Service | Configuration |
|-----------|---------|---------------|
| Network | VPC | 10.0.0.0/16, Multi-AZ |
| Compute | ECS Fargate | 0.5 vCPU, 1GB RAM, Auto-scaling 2-6 tasks |
| Database | RDS PostgreSQL 15.4 | db.t3.micro, 20GB, encrypted |
| Load Balancer | Application LB | Multi-AZ, health checks |
| Security | Security Groups | Least privilege access |
| Secrets | Secrets Manager | Encrypted credentials |
| Logging | CloudWatch | 7-30 day retention |
| Scaling | Auto Scaling | CPU/Memory based |

### Cost Estimate

**Development Environment:**
- ECS Fargate (1 task): ~$15/month
- RDS db.t3.micro: ~$15/month
- ALB: ~$16/month
- Data transfer: ~$5/month
- **Total: ~$50-70/month**

**Production Environment:**
- ECS Fargate (2-6 tasks): ~$30-90/month
- RDS db.t3.small (Multi-AZ): ~$30/month
- ALB: ~$16/month
- NAT Gateway: ~$32/month
- Data transfer: ~$10/month
- **Total: ~$94-150/month**

## Security Features

✅ **Implemented:**
- VPC isolation with public/private subnets
- Security Groups with least privilege
- RDS encryption at rest (AES-256)
- Secrets Manager for credentials
- SSL/TLS support for database connections
- CloudWatch logging and monitoring
- IAM roles with minimal permissions
- ECR image scanning
- Multi-AZ deployment for high availability

🔄 **Recommended for Production:**
- Enable HTTPS with ACM certificate
- Configure VPC Flow Logs
- Enable AWS WAF for rate limiting
- Set up CloudTrail for auditing
- Enable GuardDuty for threat detection
- Configure backup automation
- Implement disaster recovery plan

See [SECURITY.md](infra/aws/SECURITY.md) for complete security guide.

## Scaling Configuration

### Auto-Scaling Policies

**CPU-based:**
- Target: 70% utilization
- Scale out: When CPU > 70% for 1 minute
- Scale in: When CPU < 70% for 5 minutes

**Memory-based:**
- Target: 80% utilization
- Scale out: When memory > 80% for 1 minute
- Scale in: When memory < 80% for 5 minutes

**Task Limits:**
- Minimum: 2 tasks
- Maximum: 6 tasks
- Desired: 2 tasks

## Monitoring

### CloudWatch Metrics
- ECS: CPU/Memory utilization, task count
- ALB: Request count, response time, errors
- RDS: CPU, connections, storage, IOPS

### CloudWatch Logs
- ECS task logs: `/ecs/fastapi-app-production`
- Application logs: Structured JSON format
- Retention: 7 days (dev), 30 days (production)

### Recommended Alarms
- High CPU utilization (>80%)
- High memory utilization (>90%)
- Failed health checks
- Database connection errors
- HTTP 5xx errors

## Deployment Pipeline (CI/CD)

The included GitHub Actions workflow:

1. **Build Stage:**
   - Checkout code
   - Build Docker image
   - Push to ECR
   - Scan for vulnerabilities

2. **Deploy Stage:**
   - Initialize Terraform
   - Plan infrastructure changes
   - Apply changes (if on main branch)

3. **Migration Stage:**
   - Run database migrations
   - Verify migration success

4. **Verification Stage:**
   - Health check endpoints
   - API documentation accessibility
   - Integration tests (optional)

## Testing the Deployment

### 1. Health Check
```bash
curl http://your-alb-url.amazonaws.com/healthz
# Expected: {"status":"ok"}
```

### 2. API Documentation
```bash
# Visit in browser
http://your-alb-url.amazonaws.com/docs
```

### 3. Authentication Flow
```bash
# Register
curl -X POST http://your-alb-url/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!","full_name":"Test User"}'

# Login
curl -X POST http://your-alb-url/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}'

# Use the access_token from response for authenticated requests
```

## Troubleshooting

### Common Issues

**Issue: ECS tasks not starting**
```bash
# Check task logs
aws logs tail /ecs/fastapi-app-production --follow

# Check task status
aws ecs describe-tasks --cluster fastapi-app-production-cluster --tasks <task-arn>
```

**Issue: Health checks failing**
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Verify security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*fastapi*"
```

**Issue: Database connection errors**
```bash
# Test RDS connectivity
aws rds describe-db-instances --db-instance-identifier fastapi-app-production-db

# Check secrets
aws secretsmanager get-secret-value --secret-id fastapi-app-production-db-credentials
```

See [DEPLOYMENT.md](infra/aws/DEPLOYMENT.md#troubleshooting) for detailed troubleshooting guide.

## Cleanup

### CloudFormation
```bash
aws cloudformation delete-stack --stack-name fastapi-app-production
```

### Terraform
```bash
cd infra/aws/terraform
terraform destroy
```

### Elastic Beanstalk
```bash
eb terminate fastapi-production
```

### Using Makefile
```bash
make tf-destroy
```

## File Structure Summary

```
├── .ebextensions/                    # Elastic Beanstalk configuration
├── .github/workflows/
│   └── deploy-aws.yml               # CI/CD pipeline
├── .platform/nginx/                 # Nginx configuration for EB
├── infra/aws/
│   ├── cloudformation/
│   │   ├── main.yaml                # Complete CF stack
│   │   └── parameters.json.example  # Parameter template
│   ├── terraform/
│   │   ├── main.tf                  # Root configuration
│   │   ├── variables.tf             # Input variables
│   │   ├── terraform.tfvars.example # Example values
│   │   └── modules/                 # Modular components
│   │       ├── vpc/                 # Network infrastructure
│   │       ├── security/            # Security groups
│   │       ├── rds/                 # Database
│   │       ├── alb/                 # Load balancer
│   │       └── ecs/                 # Container service
│   ├── DEPLOYMENT.md                # Complete deployment guide
│   ├── SECURITY.md                  # Security best practices
│   └── QUICKSTART.md                # Quick start guide
├── scripts/
│   ├── build-and-push-ecr.sh       # Build and push to ECR
│   ├── deploy-cloudformation.sh     # CF deployment script
│   └── deploy-terraform.sh          # TF deployment script
├── Makefile                         # Convenient make commands
└── DEPLOYMENT_SUMMARY.md            # This file
```

## Next Steps

1. **Choose your deployment method** (CloudFormation, Terraform, or Elastic Beanstalk)
2. **Review security settings** in [SECURITY.md](infra/aws/SECURITY.md)
3. **Follow the deployment guide** in [DEPLOYMENT.md](infra/aws/DEPLOYMENT.md)
4. **Set up monitoring and alerts** for production
5. **Configure custom domain and HTTPS**
6. **Implement backup strategy**
7. **Set up CI/CD pipeline** with GitHub Actions

## Support and Resources

- **Documentation**: See `infra/aws/` directory
- **AWS Well-Architected Framework**: https://aws.amazon.com/architecture/well-architected/
- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/

## Project Requirements Met

✅ **API Development**
- RESTful API with CRUD operations
- User authentication (JWT)
- PostgreSQL database integration

✅ **Database Integration**
- RDS PostgreSQL with Secrets Manager
- Alembic migrations
- Database schema documented

✅ **Authentication & Security**
- JWT authentication
- Password hashing (bcrypt)
- Input validation
- Secure credential handling
- Error management

✅ **AWS Infrastructure**
- ECS Fargate deployment
- Multi-AZ high availability
- Auto-scaling configured
- Load balancing

✅ **Scalability & Performance**
- Auto-scaling (2-6 tasks)
- Load balancing across AZs
- Database connection pooling
- Caching ready (Redis can be added)

✅ **Documentation**
- Complete deployment guide (60+ pages)
- Security best practices
- API documentation (Swagger/OpenAPI)
- Architecture diagrams
- Troubleshooting guide

---

**Ready to deploy?** Start with the [Quick Start Guide](infra/aws/QUICKSTART.md)!

For detailed instructions, see the [Complete Deployment Guide](infra/aws/DEPLOYMENT.md).

**Estimated deployment time**: 20-30 minutes
**Estimated monthly cost**: $50-150 (depending on configuration)
