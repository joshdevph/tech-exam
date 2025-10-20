# Deployment Checklist - FastAPI to AWS via GitHub Actions

Use this checklist to ensure a successful deployment.

## ✅ Pre-Deployment Checklist

### Prerequisites
- [ ] AWS Account created and accessible
- [ ] GitHub Account created
- [ ] Code pushed to GitHub repository
- [ ] AWS CLI installed and configured locally
- [ ] Docker installed (for local testing)

### AWS Setup
- [ ] IAM user created for GitHub Actions
- [ ] IAM policy created with necessary permissions
- [ ] Policy attached to IAM user
- [ ] Access keys generated and saved securely
- [ ] (Optional) S3 bucket created for Terraform state
- [ ] (Optional) DynamoDB table created for state locking

### GitHub Setup
- [ ] Repository created on GitHub
- [ ] Code committed and pushed to main branch
- [ ] GitHub Actions enabled in repository settings
- [ ] Repository secrets configured:
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `AWS_REGION`
  - [ ] `DB_PASSWORD`

### Code Configuration
- [ ] `.env.example` reviewed and understood
- [ ] Workflow file `.github/workflows/deploy-aws.yml` reviewed
- [ ] Terraform backend configured (if using remote state)
- [ ] Application settings reviewed in `app/core/config.py`

## ✅ Deployment Checklist

### Initial Deployment
- [ ] All pre-deployment items completed
- [ ] Workflow file committed to repository
- [ ] Deployment triggered (manual or automatic)
- [ ] Build and push job completed successfully
- [ ] Docker image visible in Amazon ECR
- [ ] Terraform deployment job completed
- [ ] Database migrations ran successfully
- [ ] Health check passed

### Verification
- [ ] Application URL obtained from workflow output
- [ ] Health endpoint accessible (`/healthz`)
- [ ] API documentation accessible (`/docs`)
- [ ] Can register a new user
- [ ] Can login with credentials
- [ ] Can create an item (authenticated request)
- [ ] Can list items

### AWS Console Verification
- [ ] VPC created with correct CIDR
- [ ] Subnets created (2 public, 2 private)
- [ ] Internet Gateway attached
- [ ] NAT Gateways created
- [ ] Security Groups configured correctly
- [ ] RDS instance running
- [ ] RDS in private subnet with no public access
- [ ] ECS Cluster created
- [ ] ECS Service running with desired task count
- [ ] Application Load Balancer active
- [ ] Target Group showing healthy targets
- [ ] CloudWatch Log Group created
- [ ] Secrets Manager secret created

## ✅ Post-Deployment Checklist

### Security
- [ ] Database password is strong and unique
- [ ] AWS credentials rotated if needed
- [ ] No secrets committed to Git repository
- [ ] Security groups follow least privilege
- [ ] RDS not publicly accessible
- [ ] SSL/TLS enabled for database connections
- [ ] GitHub branch protection configured
- [ ] Secrets stored in GitHub Secrets (not hardcoded)

### Monitoring
- [ ] CloudWatch Logs accessible
- [ ] CloudWatch Metrics displaying data
- [ ] Application logs showing in CloudWatch
- [ ] Auto-scaling policies active
- [ ] (Optional) CloudWatch Alarms configured
- [ ] (Optional) SNS topic created for alerts

### Performance
- [ ] Application responding within acceptable time
- [ ] Database queries performing well
- [ ] Auto-scaling configured (2-6 tasks)
- [ ] Load balancer distributing traffic

### Documentation
- [ ] Team members know how to trigger deployments
- [ ] Deployment process documented
- [ ] Rollback procedure understood
- [ ] Application URL shared with team
- [ ] API documentation URL shared

## ✅ Production Readiness Checklist

### Required for Production
- [ ] Custom domain configured
- [ ] HTTPS enabled with ACM certificate
- [ ] Database Multi-AZ enabled
- [ ] Automated backups configured (7+ day retention)
- [ ] Disaster recovery plan documented
- [ ] Monitoring dashboards created
- [ ] Alert notifications configured
- [ ] Rate limiting implemented
- [ ] CORS configured for specific origins (not *)
- [ ] Environment variables reviewed for production

### Recommended for Production
- [ ] WAF configured for security
- [ ] CloudTrail enabled for auditing
- [ ] GuardDuty enabled for threat detection
- [ ] VPC Flow Logs enabled
- [ ] Database read replicas (if needed)
- [ ] ElastiCache/Redis for caching (if needed)
- [ ] SQS/SNS for async processing (if needed)
- [ ] Multi-region deployment (for DR)
- [ ] Automated testing in CI/CD pipeline
- [ ] Performance testing completed
- [ ] Load testing completed
- [ ] Security scanning integrated
- [ ] Compliance requirements met (GDPR, HIPAA, etc.)

### Cost Optimization
- [ ] RDS instance size appropriate
- [ ] ECS task resources optimized
- [ ] Auto-scaling limits appropriate
- [ ] Fargate Spot considered for non-critical workloads
- [ ] Old ECR images cleaned up (lifecycle policy)
- [ ] CloudWatch Logs retention set appropriately
- [ ] Unused resources identified and removed
- [ ] Cost alerts configured
- [ ] Reserved Instances purchased (for production)

## ✅ Ongoing Maintenance Checklist

### Weekly
- [ ] Review CloudWatch Logs for errors
- [ ] Check application metrics
- [ ] Verify auto-scaling events
- [ ] Review CloudWatch alarms

### Monthly
- [ ] Review AWS costs
- [ ] Rotate credentials if required
- [ ] Update dependencies
- [ ] Review security patches
- [ ] Check database performance
- [ ] Review and optimize queries
- [ ] Clean up old ECR images
- [ ] Review CloudWatch Logs retention

### Quarterly
- [ ] Conduct disaster recovery drill
- [ ] Review and update security policies
- [ ] Performance testing
- [ ] Load testing
- [ ] Capacity planning review
- [ ] Cost optimization review
- [ ] Update documentation

### As Needed
- [ ] Deploy application updates
- [ ] Deploy infrastructure updates
- [ ] Scale resources based on demand
- [ ] Respond to incidents
- [ ] Apply security patches
- [ ] Upgrade database engine version

## ✅ Troubleshooting Checklist

### Deployment Fails
- [ ] Check GitHub Actions logs
- [ ] Verify AWS credentials are correct
- [ ] Check IAM permissions
- [ ] Verify all GitHub Secrets are set
- [ ] Check Terraform state
- [ ] Review error messages in workflow

### Application Not Accessible
- [ ] Check ECS service is running
- [ ] Verify tasks are healthy
- [ ] Check security group rules
- [ ] Verify ALB is active
- [ ] Check target group health
- [ ] Review CloudWatch Logs

### Database Connection Issues
- [ ] Check RDS instance is running
- [ ] Verify security groups allow ECS → RDS
- [ ] Check Secrets Manager credentials
- [ ] Verify database endpoint is correct
- [ ] Check VPC configuration

### Performance Issues
- [ ] Check CloudWatch Metrics
- [ ] Review application logs
- [ ] Check database query performance
- [ ] Verify auto-scaling is working
- [ ] Check resource utilization

## 📋 Quick Reference

### Important URLs
```
GitHub Repository: https://github.com/YOUR_USERNAME/YOUR_REPO
GitHub Actions: https://github.com/YOUR_USERNAME/YOUR_REPO/actions
AWS Console: https://console.aws.amazon.com/
Application URL: http://YOUR-ALB-DNS.amazonaws.com
API Docs: http://YOUR-ALB-DNS.amazonaws.com/docs
Health Check: http://YOUR-ALB-DNS.amazonaws.com/healthz
```

### Important Commands
```bash
# Trigger deployment
gh workflow run deploy-aws.yml -f environment=production

# View logs
aws logs tail /ecs/fastapi-app-production --follow

# Check service status
aws ecs describe-services \
  --cluster fastapi-app-production-cluster \
  --services fastapi-app-production-service

# Get load balancer URL
aws elbv2 describe-load-balancers \
  --names fastapi-app-production-alb \
  --query 'LoadBalancers[0].DNSName' --output text
```

### Emergency Contacts
- AWS Support: https://console.aws.amazon.com/support/
- Team Lead: [Name/Email]
- DevOps Team: [Email/Slack]
- On-Call Engineer: [Contact Info]

---

## 📊 Deployment Status

**Last Deployment:**
- Date: _______________
- Version: _______________
- Deployed By: _______________
- Status: ☐ Success ☐ Failed ☐ Rolled Back

**Current Environment:**
- Environment: ☐ Development ☐ Staging ☐ Production
- Application URL: _______________
- Database: _______________
- ECS Cluster: _______________

**Signatures:**
- Deployed By: _______________ Date: _______________
- Verified By: _______________ Date: _______________
- Approved By: _______________ Date: _______________

---

**Keep this checklist updated and review before each deployment!**
