# AWS Infrastructure as Code - FastAPI Application

Complete Infrastructure as Code (IaC) solution for deploying the FastAPI application to AWS with production-ready configurations.

## 📁 Directory Structure

```
infra/aws/
├── cloudformation/
│   ├── main.yaml                    # Complete CloudFormation stack
│   └── parameters.json.example      # Parameter template
├── terraform/
│   ├── main.tf                      # Root Terraform configuration
│   ├── variables.tf                 # Input variables
│   ├── terraform.tfvars.example     # Example values
│   └── modules/                     # Modular infrastructure components
│       ├── vpc/                     # VPC, subnets, NAT, routing
│       ├── security/                # Security groups
│       ├── rds/                     # PostgreSQL database
│       ├── alb/                     # Application Load Balancer
│       └── ecs/                     # ECS cluster and service
├── DEPLOYMENT.md                    # 📘 Complete deployment guide (60+ pages)
├── SECURITY.md                      # 🔒 Security best practices
├── QUICKSTART.md                    # ⚡ 30-minute quick start
├── ARCHITECTURE.md                  # 🏗️ Architecture documentation
└── README.md                        # This file
```

## 🚀 Quick Start

Choose one of three deployment methods:

### Option 1: CloudFormation (AWS Native)
```bash
# Build and push image
bash scripts/build-and-push-ecr.sh

# Deploy infrastructure
export CONTAINER_IMAGE="<your-ecr-uri>"
export DB_PASSWORD="SecurePassword123!"
bash scripts/deploy-cloudformation.sh
```

### Option 2: Terraform (Multi-Cloud Ready)
```bash
# Build and push image
bash scripts/build-and-push-ecr.sh

# Configure and deploy
cd infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
bash ../../../scripts/deploy-terraform.sh
```

### Option 3: Elastic Beanstalk (Easiest)
```bash
pip install awsebcli
eb init -p docker fastapi-app --region us-east-1
eb create fastapi-production
```

## 📚 Documentation

| Document | Description | Pages |
|----------|-------------|-------|
| [QUICKSTART.md](QUICKSTART.md) | 30-minute deployment guide | Quick |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Complete deployment guide with all options | 60+ |
| [SECURITY.md](SECURITY.md) | Security best practices and compliance | 40+ |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Architecture diagrams and explanations | 30+ |

## 🏗️ Infrastructure Components

The IaC creates a complete production-ready infrastructure:

### Network Layer
- **VPC** with public/private subnets across 2 AZs
- **Internet Gateway** for public internet access
- **NAT Gateways** for private subnet internet access
- **Route Tables** for traffic routing
- **Security Groups** with least-privilege access

### Compute Layer
- **ECS Fargate Cluster** for serverless containers
- **Task Definitions** with secrets integration
- **ECS Service** with rolling deployments
- **Auto Scaling** based on CPU/Memory (2-6 tasks)

### Data Layer
- **RDS PostgreSQL 15.4** with encryption at rest
- **Multi-AZ** deployment for high availability
- **Automated backups** with 7-day retention
- **Performance Insights** (production)

### Load Balancing
- **Application Load Balancer** across AZs
- **Target Groups** with health checks
- **HTTP/HTTPS** listeners (HTTPS optional)

### Security & Secrets
- **Secrets Manager** for database credentials
- **IAM Roles** for ECS tasks
- **Security Groups** for network isolation
- **Encryption** at rest and in transit

### Monitoring
- **CloudWatch Logs** for centralized logging
- **CloudWatch Metrics** for performance monitoring
- **CloudWatch Alarms** for auto-scaling
- **Container Insights** for ECS metrics

### Container Registry
- **ECR Repository** with image scanning
- **Lifecycle Policies** for image retention
- **Encryption** at rest (AES-256)

## 💰 Cost Estimate

| Environment | Monthly Cost | Details |
|-------------|--------------|---------|
| Development | ~$50-70 | Single AZ, minimal instances |
| Production | ~$94-150 | Multi-AZ, auto-scaling |

**Breakdown:**
- ECS Fargate (2 tasks): ~$30
- RDS db.t3.micro: ~$15-30
- Application Load Balancer: ~$16
- NAT Gateway: ~$32
- Data Transfer & Storage: ~$5-10

## 🔒 Security Features

✅ **Network Security**
- VPC isolation with public/private subnets
- Security groups with least privilege
- Private RDS with no public access

✅ **Data Security**
- RDS encryption at rest (AES-256)
- Secrets Manager for credentials
- SSL/TLS for database connections

✅ **Application Security**
- JWT authentication
- Input validation
- CORS configuration
- Rate limiting ready

✅ **Monitoring**
- CloudWatch Logs and Metrics
- Security scanning for container images
- IAM roles with minimal permissions

## 📊 Architecture Overview

```
Internet → ALB → ECS Tasks (Fargate) → RDS PostgreSQL
           ↓           ↓                    ↓
       Security    CloudWatch          Secrets Manager
        Groups        Logs
```

**Multi-AZ High Availability:**
- ALB distributes traffic across 2 AZs
- ECS tasks run in multiple AZs
- RDS Multi-AZ with automatic failover

## 🛠️ Deployment Methods Comparison

| Feature | CloudFormation | Terraform | Elastic Beanstalk |
|---------|---------------|-----------|-------------------|
| AWS Native | ✅ Yes | ❌ No | ✅ Yes |
| Learning Curve | Medium | Medium | Easy |
| Flexibility | High | Very High | Medium |
| State Management | AWS Managed | Manual (S3) | AWS Managed |
| Multi-Cloud | ❌ No | ✅ Yes | ❌ No |
| **Best For** | AWS-only | Complex/Multi-cloud | Quick prototypes |

## 📖 Step-by-Step Guides

### 1. First-Time Setup (30 minutes)
See [QUICKSTART.md](QUICKSTART.md) for a condensed guide that gets you from zero to deployed in 30 minutes.

### 2. Complete Deployment (1 hour)
See [DEPLOYMENT.md](DEPLOYMENT.md) for comprehensive instructions including:
- Prerequisites and tools setup
- All deployment options detailed
- Post-deployment configuration
- Domain and HTTPS setup
- Monitoring configuration
- Troubleshooting guide

### 3. Security Hardening
See [SECURITY.md](SECURITY.md) for security best practices:
- Network security configuration
- Encryption setup
- IAM policies
- Compliance checklist
- Incident response procedures

### 4. Architecture Understanding
See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams and explanations:
- Network topology
- Component interactions
- Data flow diagrams
- High availability setup
- Disaster recovery

## 🔧 Common Tasks

### Deploy New Version
```bash
# Build and push new image
export IMAGE_TAG=v2.0.0
bash scripts/build-and-push-ecr.sh

# Update ECS service (CloudFormation)
export CONTAINER_IMAGE="<new-image-uri>"
bash scripts/deploy-cloudformation.sh

# Or update Terraform
cd infra/aws/terraform
terraform apply -var="container_image=<new-image-uri>"
```

### Run Database Migrations
```bash
TASK_ARN=$(aws ecs list-tasks \
  --cluster fastapi-app-production-cluster \
  --service-name fastapi-app-production-service \
  --query 'taskArns[0]' --output text)

aws ecs execute-command \
  --cluster fastapi-app-production-cluster \
  --task $TASK_ARN \
  --container fastapi-app-container \
  --interactive \
  --command "alembic upgrade head"
```

### View Logs
```bash
# CloudWatch Logs
aws logs tail /ecs/fastapi-app-production --follow

# Or using Makefile
make logs
```

### Scale Services
```bash
# Update desired count
aws ecs update-service \
  --cluster fastapi-app-production-cluster \
  --service fastapi-app-production-service \
  --desired-count 4
```

### Clean Up
```bash
# CloudFormation
aws cloudformation delete-stack --stack-name fastapi-app-production

# Terraform
cd infra/aws/terraform && terraform destroy

# Elastic Beanstalk
eb terminate fastapi-production
```

## 📋 Requirements

### Tools Required
- **AWS CLI** v2+ (configured with credentials)
- **Docker** (for building images)
- **Terraform** 1.5+ (for Terraform deployment)
- **Python** 3.11+ (for local development)

### AWS Permissions
IAM user/role needs permissions for:
- VPC, EC2, RDS
- ECS, ECR
- Application Load Balancer
- Secrets Manager
- CloudWatch Logs
- CloudFormation or Terraform deployment

## 🆘 Troubleshooting

### Common Issues

**Tasks not starting:**
```bash
aws ecs describe-tasks --cluster <cluster> --tasks <task-arn>
# Check stopped reason and logs
```

**Health checks failing:**
```bash
aws elbv2 describe-target-health --target-group-arn <tg-arn>
# Verify /healthz endpoint is accessible
```

**Database connection errors:**
```bash
# Check security groups allow ECS → RDS traffic
# Verify secrets in Secrets Manager
aws secretsmanager get-secret-value --secret-id <secret-id>
```

See [DEPLOYMENT.md](DEPLOYMENT.md#troubleshooting) for detailed troubleshooting guide.

## 🎯 Next Steps

After deployment:

1. **Configure Custom Domain** - See [DEPLOYMENT.md](DEPLOYMENT.md#configure-domain-name-optional)
2. **Enable HTTPS** - Request ACM certificate and add HTTPS listener
3. **Set Up Monitoring** - Configure CloudWatch dashboards and alarms
4. **Review Security** - Follow checklist in [SECURITY.md](SECURITY.md)
5. **Enable CI/CD** - Use included GitHub Actions workflow
6. **Plan Disaster Recovery** - Set up cross-region backups

## 📞 Support

- **Documentation Issues**: Check the comprehensive guides in this directory
- **AWS Services**: [AWS Support](https://aws.amazon.com/support/)
- **FastAPI**: [FastAPI Documentation](https://fastapi.tiangolo.com/)

## 📄 License

See main project README for license information.

---

**Ready to deploy?** Start with the [Quick Start Guide](QUICKSTART.md)!
