# FastAPI AWS Production-Ready Application

Production-grade FastAPI application with complete AWS Infrastructure as Code (IaC) for deployment. Features JWT authentication, PostgreSQL database, automated scaling, and comprehensive security best practices.

## Features

### Application Features
- Modular FastAPI application with dedicated layers for configuration, services, and routing
- PostgreSQL integration via SQLAlchemy 2.0 and migration management through Alembic
- JWT-based authentication with password hashing and protected CRUD routes
- Docker Compose stack for local development (API + PostgreSQL) and production-ready Dockerfile
- Out-of-the-box Swagger UI ([/docs](http://localhost:8000/docs)) and OpenAPI schema ([/openapi.json](http://localhost:8000/openapi.json))
- Comprehensive input validation and error handling

### Infrastructure Features (IaC)
- **CloudFormation Templates**: Complete AWS infrastructure definition
- **Terraform Modules**: Modular, reusable infrastructure components
- **Elastic Beanstalk**: Quick deployment configuration
- **Auto-Scaling**: CPU and memory-based automatic scaling
- **Multi-AZ Deployment**: High availability across availability zones
- **Security**: VPC isolation, security groups, encrypted RDS, Secrets Manager integration
- **Monitoring**: CloudWatch logs, metrics, and alarms
- **CI/CD**: GitHub Actions workflows for automated deployment

## Project Structure
```
app/
  api/              # FastAPI routers and dependencies
  core/             # Configuration, auth, and security helpers
  db/               # SQLAlchemy session, models, and Alembic metadata
  schemas/          # Pydantic models for requests/responses
  services/         # Business logic for users and items
alembic/            # Alembic environment and versioned migrations
infra/
  aws/
    cloudformation/ # AWS CloudFormation IaC templates
      main.yaml     # Complete infrastructure stack
      parameters.json.example  # Parameter examples
    terraform/      # Terraform IaC configuration
      main.tf       # Root Terraform configuration
      variables.tf  # Input variables
      modules/      # Reusable Terraform modules
        vpc/        # VPC and networking
        security/   # Security groups
        rds/        # PostgreSQL database
        alb/        # Application Load Balancer
        ecs/        # ECS cluster and service
    DEPLOYMENT.md   # Comprehensive deployment guide
.ebextensions/      # Elastic Beanstalk configuration
.github/
  workflows/
    deploy-aws.yml  # GitHub Actions CI/CD pipeline
scripts/
  build-and-push-ecr.sh      # Build and push Docker image
  deploy-cloudformation.sh   # Deploy with CloudFormation
  deploy-terraform.sh        # Deploy with Terraform
  start.sh          # Container entry point
Dockerfile          # Production-ready container image
docker-compose.yml  # Local development stack
```

## Prerequisites
- Python 3.11+
- Docker Desktop (for containerized workflows)
- Optional: `make`, `httpie`, or `curl` for quick interactions

## Local Development (virtualenv)
1. **Create and activate a virtual environment**
   ```bash
   python -m venv .venv
   # Linux/macOS
   source .venv/bin/activate
   # Windows (PowerShell)
   .venv\Scripts\Activate.ps1
   ```
2. **Install dependencies**
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```
3. **Start PostgreSQL** (requires Docker Compose)
   ```bash
   cp .env.example .env  # edit secrets before running in production
   docker compose up db -d
   ```
4. **Apply database migrations**
   ```bash
   alembic upgrade head
   ```
5. **Run the API**
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
6. Open `http://127.0.0.1:8000/docs` for interactive Swagger documentation.

## Docker Workflow
- **One command up**
  ```bash
  docker compose up --build
  ```
  The API is available on `http://127.0.0.1:8000`. Logs show Alembic migrations executing before the server starts.
- **Tear down**
  ```bash
  docker compose down -v
  ```

## Database Migrations
- Create a new migration after updating models:
  ```bash
  alembic revision --autogenerate -m "describe change"
  ```
- Apply migrations:
  ```bash
  alembic upgrade head
  ```

## Authentication Flow
- Register: `POST /auth/register` with `email`, `password`, `full_name` (optional).
- Login: `POST /auth/login` returns a JWT access token plus TTL seconds.
- Authorized requests: add `Authorization: Bearer <token>` header to access protected routes such as `GET /items` or `POST /items`.

## Scalability & Production Notes
- **Database**: Promote to AWS RDS for managed PostgreSQL, enable IAM auth or Secrets Manager.
- **Stateless API**: JWT tokens and Dockerized runtime make horizontal scaling straightforward via ECS, App Runner, or Kubernetes.
- **Caching/Queuing**: Add Redis/ElastiCache and SQS/SNS as traffic grows. Use AWS Application Load Balancer for TLS termination and health checks (`/healthz`).
- **Observability**: Configure FastAPI logging for CloudWatch or OpenTelemetry exporters. Health and readiness endpoints are included for container orchestration.

## AWS Deployment (Infrastructure as Code)

This project includes complete Infrastructure as Code (IaC) for AWS deployment using CloudFormation, Terraform, or Elastic Beanstalk.

### Quick Start Deployment

#### Option 1: CloudFormation (Recommended for AWS-only deployments)
```bash
# Build and push Docker image to ECR
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export IMAGE_TAG=v1.0.0
bash scripts/build-and-push-ecr.sh

# Deploy infrastructure
export CONTAINER_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/fastapi-app-production:$IMAGE_TAG"
export DB_PASSWORD="YourSecurePassword123!"
bash scripts/deploy-cloudformation.sh
```

#### Option 2: Terraform (Recommended for multi-cloud or complex infrastructure)
```bash
# Build and push Docker image
bash scripts/build-and-push-ecr.sh

# Configure Terraform variables
cd infra/aws/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy with Terraform
bash scripts/deploy-terraform.sh
```

#### Option 3: Elastic Beanstalk (Quickest deployment)
```bash
# Install EB CLI
pip install awsebcli

# Initialize and deploy
eb init -p docker fastapi-app --region us-east-1
eb create fastapi-production --instance-type t3.small --database
eb deploy
```

### Infrastructure Details

The IaC templates create:
- **VPC**: Multi-AZ with public/private subnets, NAT gateways, and route tables
- **RDS PostgreSQL**: Encrypted database in private subnets with automated backups
- **ECS Fargate**: Serverless container orchestration with auto-scaling
- **Application Load Balancer**: HTTP/HTTPS traffic distribution with health checks
- **Secrets Manager**: Secure credential storage
- **CloudWatch**: Centralized logging and monitoring
- **Security Groups**: Least-privilege network access control

### Deployment Architecture

```
Internet → ALB → ECS Tasks (Fargate) → RDS PostgreSQL
           ↓           ↓                    ↓
       Security    CloudWatch          Secrets Manager
        Groups        Logs
```

### Cost Estimate
- **Development**: ~$50-70/month (single AZ, smaller instances)
- **Production**: ~$94-150/month (multi-AZ, auto-scaling)

For detailed deployment instructions, security configuration, monitoring setup, and troubleshooting, see:
**[Complete AWS Deployment Guide](infra/aws/DEPLOYMENT.md)**

## Testing the API
```bash
# Register
http POST :8000/auth/register email="jane@example.com" password="SuperSecret1"

# Login
http POST :8000/auth/login email="jane@example.com" password="SuperSecret1"
TOKEN=$(http --print=b POST :8000/auth/login email="jane@example.com" password="SuperSecret1" | jq -r .access_token)

# Create an item
http POST :8000/items title="First" description="Hello" "Authorization:Bearer $TOKEN"
```

## CI/CD with GitHub Actions

This project includes a complete GitHub Actions workflow for automated deployment to AWS.

### Quick Setup (15 minutes)

1. **Push code to GitHub**
2. **Configure AWS IAM user for GitHub Actions**
3. **Add GitHub Secrets** (AWS credentials, DB password)
4. **Push to deploy** - automatic deployment on push to main

**See**: [GITHUB_QUICKSTART.md](GITHUB_QUICKSTART.md) for 5-step setup guide

**Complete Guide**: [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md) for detailed instructions

### Automated Workflow

The GitHub Actions pipeline automatically:
- ✅ Builds Docker image
- ✅ Pushes to Amazon ECR
- ✅ Scans for vulnerabilities
- ✅ Deploys infrastructure with Terraform
- ✅ Runs database migrations
- ✅ Performs health checks

**Workflow file**: [.github/workflows/deploy-aws.yml](.github/workflows/deploy-aws.yml)

## Next Steps
- **Set up CI/CD**: Follow [GITHUB_QUICKSTART.md](GITHUB_QUICKSTART.md) for GitHub Actions deployment
- **Configure custom domain**: See [infra/aws/DEPLOYMENT.md](infra/aws/DEPLOYMENT.md#configure-domain-name-optional)
- **Enable HTTPS**: Request ACM certificate and add HTTPS listener
- **Add monitoring**: Set up CloudWatch dashboards and alarms
- **Extend functionality**: Add domain-specific routes or extend schemas/services
- **Implement rate limiting**: Use AWS WAF or application-level rate limiting
