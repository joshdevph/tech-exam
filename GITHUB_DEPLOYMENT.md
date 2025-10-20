# GitHub Deployment Guide - FastAPI to AWS

This guide provides complete instructions for deploying your FastAPI application to AWS using GitHub Actions CI/CD pipeline.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [AWS Configuration](#aws-configuration)
- [GitHub Repository Setup](#github-repository-setup)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Deployment Methods](#deployment-methods)
- [Triggering Deployments](#triggering-deployments)
- [Monitoring Deployments](#monitoring-deployments)
- [Troubleshooting](#troubleshooting)

## Overview

The GitHub Actions workflow automatically:
1. Builds your Docker image
2. Pushes it to Amazon ECR
3. Scans for security vulnerabilities
4. Deploys infrastructure using Terraform
5. Runs database migrations
6. Performs health checks

**Deployment Time**: ~15-20 minutes for first deployment, ~5-10 minutes for updates

## Prerequisites

### Required Accounts
- ✅ AWS Account with admin access
- ✅ GitHub Account
- ✅ Your FastAPI code in a GitHub repository

### Required Tools (for local testing)
- AWS CLI v2+
- Docker
- Git
- Terraform 1.5+ (optional, for local testing)

## Initial Setup

### Step 1: Fork or Clone This Repository

If you haven't already, push your code to GitHub:

```bash
# Initialize git repository (if not already initialized)
cd c:\Users\Juswa\Desktop\tech-exam
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit - FastAPI AWS deployment"

# Add remote (replace with your GitHub repository URL)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## AWS Configuration

### Step 2: Create AWS IAM User for GitHub Actions

#### Option A: Using IAM User with Access Keys (Simpler)

1. **Create IAM User:**
```bash
aws iam create-user --user-name github-actions-deploy
```

2. **Create and attach policy:**

Save this as `github-actions-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*",
        "ecs:*",
        "ec2:*",
        "rds:*",
        "elasticloadbalancing:*",
        "secretsmanager:*",
        "logs:*",
        "iam:*",
        "cloudwatch:*",
        "application-autoscaling:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Create and attach the policy:
```bash
aws iam create-policy \
  --policy-name GitHubActionsDeployPolicy \
  --policy-document file://github-actions-policy.json

aws iam attach-user-policy \
  --user-name github-actions-deploy \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/GitHubActionsDeployPolicy
```

3. **Create access keys:**
```bash
aws iam create-access-key --user-name github-actions-deploy
```

**IMPORTANT**: Save the `AccessKeyId` and `SecretAccessKey` - you'll need them for GitHub Secrets.

#### Option B: Using OIDC (More Secure, Recommended)

1. **Create OIDC Provider:**
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

2. **Create IAM Role:**

Save this as `github-trust-policy.json` (replace YOUR_GITHUB_USERNAME and YOUR_REPO):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

Create the role:
```bash
aws iam create-role \
  --role-name GitHubActionsDeployRole \
  --assume-role-policy-document file://github-trust-policy.json

aws iam attach-role-policy \
  --role-name GitHubActionsDeployRole \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/GitHubActionsDeployPolicy
```

### Step 3: Set Up Terraform State Backend (Optional but Recommended)

Create S3 bucket for Terraform state:

```bash
# Create S3 bucket (replace UNIQUE-BUCKET-NAME)
aws s3 mb s3://YOUR-UNIQUE-BUCKET-NAME-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket YOUR-UNIQUE-BUCKET-NAME-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Update `infra/aws/terraform/main.tf` to use the backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "YOUR-UNIQUE-BUCKET-NAME-terraform-state"
    key            = "fastapi-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

## GitHub Repository Setup

### Step 4: Enable GitHub Actions

1. Go to your GitHub repository
2. Click on **Settings** tab
3. Click on **Actions** → **General** in the left sidebar
4. Under "Actions permissions", select **Allow all actions and reusable workflows**
5. Click **Save**

### Step 5: Configure GitHub Secrets

Navigate to your repository → **Settings** → **Secrets and variables** → **Actions**

#### Required Secrets

Click **New repository secret** for each of the following:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCOUNT_ID` | Your AWS account ID | 12-digit AWS account number |
| `AWS_REGION` | `us-east-1` | AWS region for deployment |
| `DB_PASSWORD` | Strong password | Database password (min 8 chars) |

#### If Using IAM User (Option A):

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your access key | From Step 2 |
| `AWS_SECRET_ACCESS_KEY` | Your secret key | From Step 2 |

#### If Using OIDC (Option B):

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ROLE_ARN` | Role ARN | From Step 2 (e.g., arn:aws:iam::123456789012:role/GitHubActionsDeployRole) |

#### Example Secret Values:

```
AWS_ACCOUNT_ID: 123456789012
AWS_REGION: us-east-1
DB_PASSWORD: MySecurePassword123!
AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Step 6: Update GitHub Actions Workflow

The workflow file is already created at `.github/workflows/deploy-aws.yml`

**For IAM User authentication**, update this section:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ secrets.AWS_REGION }}
```

**For OIDC authentication**, use this (already in the workflow):

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ secrets.AWS_REGION }}
```

### Step 7: Update Terraform Variables for GitHub Actions

Create `infra/aws/terraform/terraform.auto.tfvars` (this will be gitignored):

```hcl
# This file is for local development only
# GitHub Actions will use environment variables
```

The workflow automatically sets these variables:
- `container_image` - from build step
- `db_password` - from GitHub secrets
- `environment` - from workflow input or branch

## Deployment Methods

### Method 1: Automatic Deployment on Push (Recommended)

The workflow is configured to automatically deploy when you push to `main` or `production` branches.

```bash
# Make changes to your code
git add .
git commit -m "Update application"

# Push to main branch (triggers deployment)
git push origin main
```

### Method 2: Manual Deployment via GitHub UI

1. Go to your GitHub repository
2. Click **Actions** tab
3. Click **Deploy to AWS** workflow
4. Click **Run workflow** button
5. Select:
   - **Branch**: Choose branch to deploy
   - **Environment**: development, staging, or production
6. Click **Run workflow**

### Method 3: Manual Deployment via GitHub CLI

Install GitHub CLI:
```bash
# Windows (using winget)
winget install GitHub.cli

# Or download from: https://cli.github.com/
```

Trigger deployment:
```bash
# Authenticate
gh auth login

# Trigger workflow
gh workflow run deploy-aws.yml \
  --ref main \
  -f environment=production
```

## Triggering Deployments

### Initial Deployment

For the **first deployment**, you need to prepare Terraform:

1. **Commit and push Terraform backend configuration:**
```bash
git add infra/aws/terraform/main.tf
git commit -m "Configure Terraform backend"
git push origin main
```

2. **Run the deployment manually:**
   - Go to GitHub Actions
   - Select "Deploy to AWS"
   - Click "Run workflow"
   - Select environment: `production`
   - Click "Run workflow"

3. **Monitor the deployment:**
   - Click on the running workflow
   - Watch each step complete
   - First deployment takes ~15-20 minutes

### Subsequent Deployments

After initial setup, deployments are automatic:

```bash
# Make code changes
vim app/main.py

# Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# Deployment starts automatically
# Check progress at: https://github.com/YOUR_USERNAME/YOUR_REPO/actions
```

## Monitoring Deployments

### GitHub Actions UI

1. Go to **Actions** tab in your repository
2. Click on the running workflow
3. Monitor each job:
   - ✅ Build and Push Docker Image
   - ✅ Deploy with Terraform
   - ✅ Run Database Migrations
   - ✅ Health Check

### Deployment Logs

Click on each step to see detailed logs:

```
Build and Push Docker Image
├─ Checkout code
├─ Configure AWS credentials
├─ Login to Amazon ECR
├─ Build, tag, and push image
└─ Scan image for vulnerabilities

Deploy with Terraform
├─ Checkout code
├─ Configure AWS credentials
├─ Setup Terraform
├─ Terraform Init
├─ Terraform Validate
├─ Terraform Plan
└─ Terraform Apply

Run Database Migrations
├─ Get ECS task ARN
└─ Execute Alembic migration

Health Check
├─ Get Load Balancer URL
├─ Wait for service
├─ Test /healthz endpoint
└─ Test /docs endpoint
```

### AWS Console

Monitor in AWS Console:
- **ECS**: Services → fastapi-app-production-cluster
- **CloudWatch**: Logs → /ecs/fastapi-app-production
- **ECR**: Repositories → fastapi-app-production

### Get Deployment URL

After successful deployment, get your application URL:

**From GitHub Actions logs:**
Look for the output in the "Terraform Apply" step

**From AWS CLI:**
```bash
aws cloudformation describe-stacks \
  --stack-name fastapi-app-production \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text
```

**From Terraform (if you have it locally):**
```bash
cd infra/aws/terraform
terraform output load_balancer_url
```

## Testing Deployment

### Automated Tests

The workflow includes automated health checks. You can also add more tests:

Create `.github/workflows/test.yml`:
```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov

      - name: Run tests
        run: pytest tests/ -v --cov=app
```

### Manual Testing

After deployment completes:

```bash
# Get your load balancer URL from GitHub Actions output
export API_URL="http://your-alb-dns.amazonaws.com"

# Test health endpoint
curl $API_URL/healthz

# Test API documentation
curl $API_URL/docs

# Register a user
curl -X POST $API_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!",
    "full_name": "Test User"
  }'

# Login
curl -X POST $API_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!"
  }'
```

## Environment-Specific Deployments

### Multiple Environments

You can deploy to different environments:

1. **Development Environment:**
```bash
gh workflow run deploy-aws.yml -f environment=development
```

2. **Staging Environment:**
```bash
gh workflow run deploy-aws.yml -f environment=staging
```

3. **Production Environment:**
```bash
gh workflow run deploy-aws.yml -f environment=production
```

### Branch-Based Deployments

Configure branch protection and deployment rules:

**In `.github/workflows/deploy-aws.yml`:**
```yaml
on:
  push:
    branches:
      - main        # Deploys to production
      - develop     # Deploys to development
      - staging     # Deploys to staging
```

## Rollback Procedures

### Rollback via GitHub

1. Go to **Actions** tab
2. Find the last successful deployment
3. Click **Re-run all jobs**

### Rollback via AWS ECS

```bash
# List task definitions
aws ecs list-task-definitions \
  --family-prefix fastapi-app-production

# Update service to use previous version
aws ecs update-service \
  --cluster fastapi-app-production-cluster \
  --service fastapi-app-production-service \
  --task-definition fastapi-app-production:PREVIOUS_REVISION
```

### Rollback via Terraform

```bash
# Locally, revert to previous commit
git log --oneline
git checkout PREVIOUS_COMMIT_SHA infra/aws/terraform/

# Commit and push
git add infra/aws/terraform/
git commit -m "Rollback infrastructure"
git push origin main
```

## Troubleshooting

### Common Issues

#### 1. Workflow Fails: "AWS credentials not configured"

**Solution:**
- Verify GitHub secrets are set correctly
- Check secret names match exactly (case-sensitive)
- For OIDC, verify role ARN is correct

```bash
# Test AWS credentials locally
aws sts get-caller-identity
```

#### 2. Terraform Apply Fails: "Resource already exists"

**Solution:**
- First deployment might have partially completed
- Import existing resources or destroy and retry

```bash
# Check Terraform state
cd infra/aws/terraform
terraform state list

# Import existing resource (example)
terraform import aws_ecr_repository.app fastapi-app-production
```

#### 3. ECS Tasks Not Starting

**Solution:**
- Check CloudWatch logs
- Verify ECR image was pushed successfully
- Check security group rules

```bash
# View logs
aws logs tail /ecs/fastapi-app-production --follow

# Describe service
aws ecs describe-services \
  --cluster fastapi-app-production-cluster \
  --services fastapi-app-production-service
```

#### 4. Health Check Fails

**Solution:**
- Wait longer (service might still be starting)
- Check if /healthz endpoint is accessible
- Verify security groups allow ALB → ECS traffic

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <your-target-group-arn>
```

#### 5. Database Migration Fails

**Solution:**
- Check if ECS tasks are running
- Verify database credentials in Secrets Manager
- Check security groups allow ECS → RDS traffic

```bash
# List running tasks
aws ecs list-tasks \
  --cluster fastapi-app-production-cluster \
  --service-name fastapi-app-production-service

# Check secrets
aws secretsmanager get-secret-value \
  --secret-id fastapi-app-production-db-credentials
```

### Debug Workflow

Enable debug logging in GitHub Actions:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add these secrets:
   - `ACTIONS_STEP_DEBUG` = `true`
   - `ACTIONS_RUNNER_DEBUG` = `true`

### Get Help

- **GitHub Actions Logs**: Check detailed logs in Actions tab
- **AWS CloudWatch**: Check application logs
- **Terraform Output**: Review Terraform plan/apply output
- **AWS Support**: For AWS-specific issues

## Advanced Configuration

### Custom Domain and HTTPS

After deployment, configure custom domain:

1. **Request ACM Certificate:**
```bash
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS \
  --region us-east-1
```

2. **Add HTTPS listener** (update Terraform or CloudFormation)

3. **Configure Route 53:**
```bash
# Create A record pointing to ALB
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch file://dns-changes.json
```

### Notifications

Set up Slack/Discord notifications:

Add to `.github/workflows/deploy-aws.yml`:

```yaml
- name: Notify deployment status
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Scheduled Deployments

Deploy on schedule:

```yaml
on:
  schedule:
    - cron: '0 2 * * 0'  # Every Sunday at 2 AM
  push:
    branches: [main]
```

## Security Best Practices

### 1. Protect Secrets
- ✅ Never commit secrets to Git
- ✅ Use GitHub Secrets for all sensitive data
- ✅ Rotate AWS access keys regularly

### 2. Branch Protection
- ✅ Require pull request reviews
- ✅ Require status checks to pass
- ✅ Restrict who can push to main

**Settings** → **Branches** → **Add branch protection rule**:
- Branch name pattern: `main`
- ☑️ Require pull request reviews before merging
- ☑️ Require status checks to pass before merging

### 3. Environment Protection

Configure deployment environments:

**Settings** → **Environments** → **New environment**:
- Name: `production`
- ☑️ Required reviewers (add team members)
- ☑️ Wait timer: 5 minutes

### 4. Audit Logging

Enable audit logs:
- GitHub: Settings → Audit log
- AWS: CloudTrail for all API calls

## Cost Management

### Monitor Costs

- **AWS Cost Explorer**: Track daily costs
- **Budgets**: Set up alerts for unexpected costs
- **Tags**: All resources are tagged for cost tracking

```bash
# Get estimated monthly cost
aws ce get-cost-forecast \
  --time-period Start=2024-11-01,End=2024-12-01 \
  --metric UNBLENDED_COST \
  --granularity MONTHLY
```

### Optimize Costs

- Use Fargate Spot for non-production
- Schedule scaling down during off-hours
- Use RDS Reserved Instances for production

## Next Steps

After successful deployment:

1. ✅ **Test all API endpoints**
2. ✅ **Configure custom domain**
3. ✅ **Enable HTTPS**
4. ✅ **Set up monitoring alerts**
5. ✅ **Configure backup strategy**
6. ✅ **Document your deployment process**
7. ✅ **Train team on GitHub Actions workflow**

## Quick Reference

### Useful Commands

```bash
# Trigger deployment
gh workflow run deploy-aws.yml -f environment=production

# View workflow runs
gh run list --workflow=deploy-aws.yml

# Watch workflow execution
gh run watch

# View logs
gh run view --log

# Cancel running workflow
gh run cancel <run-id>

# Get application URL
aws cloudformation describe-stacks \
  --stack-name fastapi-app-production \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text
```

### Important URLs

After deployment:
- **Application**: http://YOUR-ALB-DNS.amazonaws.com
- **API Docs**: http://YOUR-ALB-DNS.amazonaws.com/docs
- **Health Check**: http://YOUR-ALB-DNS.amazonaws.com/healthz
- **GitHub Actions**: https://github.com/YOUR_USERNAME/YOUR_REPO/actions
- **AWS Console**: https://console.aws.amazon.com/

---

**Congratulations!** 🎉 You now have a fully automated CI/CD pipeline for deploying your FastAPI application to AWS!

For questions or issues, check the comprehensive guides in `infra/aws/` directory.
