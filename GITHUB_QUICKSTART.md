# GitHub Deployment Quick Start

**Deploy your FastAPI app to AWS in 15 minutes using GitHub Actions**

## ⚡ Super Quick Setup (5 Steps)

### Step 1: Push Code to GitHub (2 minutes)

```bash
cd c:\Users\Juswa\Desktop\tech-exam
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

### Step 2: Create AWS IAM User (3 minutes)

```bash
# Create user
aws iam create-user --user-name github-actions-deploy

# Create policy file (save as policy.json)
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ecr:*", "ecs:*", "ec2:*", "rds:*", "elasticloadbalancing:*",
               "secretsmanager:*", "logs:*", "iam:*", "cloudwatch:*",
               "application-autoscaling:*"],
    "Resource": "*"
  }]
}

# Create and attach policy
aws iam create-policy --policy-name GitHubDeploy --policy-document file://policy.json
aws iam attach-user-policy --user-name github-actions-deploy \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/GitHubDeploy

# Create access keys
aws iam create-access-key --user-name github-actions-deploy
```

**Save the AccessKeyId and SecretAccessKey!**

### Step 3: Configure GitHub Secrets (3 minutes)

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 4 secrets:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `AWS_ACCESS_KEY_ID` | Your access key | AKIAIOSFODNN7EXAMPLE |
| `AWS_SECRET_ACCESS_KEY` | Your secret key | wJalrXUtnFEMI/K7MDENG/... |
| `AWS_REGION` | AWS region | us-east-1 |
| `DB_PASSWORD` | Database password | MySecurePass123! |

### Step 4: Update Workflow File (2 minutes)

Edit `.github/workflows/deploy-aws.yml` - change the authentication section to:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ secrets.AWS_REGION }}
```

Commit and push:
```bash
git add .github/workflows/deploy-aws.yml
git commit -m "Update workflow authentication"
git push origin main
```

### Step 5: Deploy! (5 minutes)

#### Option A: Automatic (Push to deploy)
```bash
git add .
git commit -m "Trigger deployment"
git push origin main
```

#### Option B: Manual (GitHub UI)
1. Go to **Actions** tab
2. Click **Deploy to AWS**
3. Click **Run workflow**
4. Select environment: `production`
5. Click **Run workflow**

## 📊 Monitor Deployment

Watch progress at: `https://github.com/YOUR_USERNAME/YOUR_REPO/actions`

**Deployment steps:**
1. ✅ Build Docker image (~3 min)
2. ✅ Push to ECR (~1 min)
3. ✅ Deploy with Terraform (~10 min)
4. ✅ Run migrations (~1 min)
5. ✅ Health check (~30 sec)

## 🎯 Get Your Application URL

After deployment completes, find the URL in:

**GitHub Actions Output:**
- Go to Actions → Click your workflow run
- Open "Deploy with Terraform" step
- Look for `load_balancer_url`

**Or via AWS CLI:**
```bash
aws ecs describe-services \
  --cluster fastapi-app-production-cluster \
  --services fastapi-app-production-service \
  --query 'services[0].loadBalancers[0]' --output table
```

## ✅ Test Your Deployment

```bash
# Replace with your actual URL
export API_URL="http://YOUR-ALB-DNS.amazonaws.com"

# Health check
curl $API_URL/healthz

# API documentation
open $API_URL/docs  # or visit in browser
```

## 🔄 Deploy Updates

Just push to main branch:
```bash
# Make changes
vim app/main.py

# Commit and push (automatically deploys)
git add .
git commit -m "Add new feature"
git push origin main
```

## 🚨 Troubleshooting

### Workflow fails immediately
- Check GitHub Secrets are set correctly
- Verify AWS credentials with: `aws sts get-caller-identity`

### ECS tasks not starting
```bash
# Check logs
aws logs tail /ecs/fastapi-app-production --follow

# Check service status
aws ecs describe-services \
  --cluster fastapi-app-production-cluster \
  --services fastapi-app-production-service
```

### Health check fails
- Wait 2-3 minutes (service might still be starting)
- Check target health:
```bash
aws elbv2 describe-target-health --target-group-arn <arn-from-output>
```

## 📚 Full Documentation

- **Complete Guide**: [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md)
- **Deployment Guide**: [infra/aws/DEPLOYMENT.md](infra/aws/DEPLOYMENT.md)
- **Security**: [infra/aws/SECURITY.md](infra/aws/SECURITY.md)

## 💰 Costs

**Estimated**: ~$94-150/month for production setup

To avoid charges, clean up:
```bash
cd infra/aws/terraform
terraform destroy
```

---

## Common GitHub Actions Commands

```bash
# Install GitHub CLI
winget install GitHub.cli

# Login
gh auth login

# Trigger deployment
gh workflow run deploy-aws.yml -f environment=production

# Watch deployment
gh run watch

# View logs
gh run view --log

# List recent runs
gh run list --workflow=deploy-aws.yml
```

---

**Need help?** See [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md) for detailed instructions!
