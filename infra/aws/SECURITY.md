# AWS Security Best Practices

This document outlines security best practices implemented in the FastAPI AWS deployment and recommendations for production environments.

## Table of Contents
- [Network Security](#network-security)
- [Data Encryption](#data-encryption)
- [Identity and Access Management](#identity-and-access-management)
- [Secrets Management](#secrets-management)
- [Application Security](#application-security)
- [Monitoring and Logging](#monitoring-and-logging)
- [Compliance and Auditing](#compliance-and-auditing)
- [Incident Response](#incident-response)

## Network Security

### VPC Isolation

✅ **Implemented**:
- Dedicated VPC with CIDR block 10.0.0.0/16
- Public subnets for ALB (internet-facing)
- Private subnets for ECS tasks and RDS (no internet access)
- Multi-AZ deployment for high availability

```
Public Subnets (10.0.1.0/24, 10.0.2.0/24)
  └─ Application Load Balancer only

Private Subnets (10.0.11.0/24, 10.0.12.0/24)
  └─ ECS Tasks, RDS Database
  └─ Internet access via NAT Gateway only
```

### Security Groups (Least Privilege)

✅ **Implemented**:

**ALB Security Group**:
- Inbound: HTTP (80), HTTPS (443) from 0.0.0.0/0
- Outbound: All traffic to ECS security group

**ECS Security Group**:
- Inbound: Port 8000 from ALB security group only
- Outbound: All traffic (for internet access, AWS API calls)

**RDS Security Group**:
- Inbound: PostgreSQL (5432) from ECS security group only
- Outbound: None required

### Network Access Control Lists (NACLs)

🔄 **Recommended** (Optional additional security):

```bash
# Create NACL for private subnets
aws ec2 create-network-acl --vpc-id vpc-xxx

# Deny all inbound traffic from specific IPs
aws ec2 create-network-acl-entry \
  --network-acl-id acl-xxx \
  --ingress \
  --rule-number 100 \
  --protocol -1 \
  --rule-action deny \
  --cidr-block 192.0.2.0/24
```

### VPC Flow Logs

🔄 **Recommended for Production**:

```bash
# Enable VPC Flow Logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs
```

### VPC Endpoints (Cost Optimization + Security)

🔄 **Recommended** to avoid NAT Gateway charges and improve security:

```bash
# Create VPC endpoint for ECR
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxx \
  --service-name com.amazonaws.us-east-1.ecr.api \
  --route-table-ids rtb-xxx

# Create VPC endpoint for Secrets Manager
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxx \
  --service-name com.amazonaws.us-east-1.secretsmanager \
  --subnet-ids subnet-xxx subnet-yyy \
  --security-group-ids sg-xxx
```

## Data Encryption

### Encryption at Rest

✅ **Implemented**:

**RDS PostgreSQL**:
- Storage encryption enabled (AES-256)
- Automated backups encrypted
- Snapshot encryption enabled

**Secrets Manager**:
- All secrets encrypted using AWS KMS
- Default AWS managed key or customer managed key

**ECR**:
- Container images encrypted at rest (AES-256)

**CloudWatch Logs**:
- Log data encrypted at rest

### Encryption in Transit

✅ **Implemented**:

**Application to ALB**:
- HTTP/HTTPS support
- TLS 1.2+ recommended

**ALB to ECS Tasks**:
- Internal communication over private network
- Can be encrypted with additional configuration

**Application to RDS**:
- PostgreSQL SSL/TLS connection enforced

**Enable SSL for PostgreSQL** (add to RDS parameter group):
```bash
aws rds modify-db-parameter-group \
  --db-parameter-group-name fastapi-app-pg \
  --parameters "ParameterName=rds.force_ssl,ParameterValue=1,ApplyMethod=immediate"
```

**Update connection string** in application:
```python
# app/core/config.py
DATABASE_URL = "postgresql://user:pass@host:5432/db?sslmode=require"
```

### KMS Customer Managed Keys

🔄 **Recommended for Production**:

```bash
# Create KMS key
aws kms create-key \
  --description "FastAPI App Encryption Key" \
  --key-policy file://key-policy.json

# Create alias
aws kms create-alias \
  --alias-name alias/fastapi-app \
  --target-key-id <key-id>

# Update RDS to use KMS key
aws rds modify-db-instance \
  --db-instance-identifier fastapi-app-db \
  --kms-key-id <key-id> \
  --apply-immediately
```

## Identity and Access Management

### IAM Roles and Policies

✅ **Implemented**:

**ECS Task Execution Role**:
- Pulls images from ECR
- Writes logs to CloudWatch
- Retrieves secrets from Secrets Manager

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:region:account:secret:fastapi-app-*"
    }
  ]
}
```

**ECS Task Role**:
- Application-level permissions
- CloudWatch Logs access
- Minimal permissions required

### IAM Users and Access

🔄 **Best Practices**:

1. **Enable MFA for all IAM users**:
```bash
aws iam enable-mfa-device \
  --user-name admin-user \
  --serial-number arn:aws:iam::account:mfa/device \
  --authentication-code1 123456 \
  --authentication-code2 789012
```

2. **Use IAM roles instead of access keys for applications**

3. **Implement password policy**:
```bash
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --max-password-age 90
```

4. **Enable IAM Access Analyzer**:
```bash
aws accessanalyzer create-analyzer \
  --analyzer-name fastapi-app-analyzer \
  --type ACCOUNT
```

## Secrets Management

### AWS Secrets Manager

✅ **Implemented**:

- Database credentials stored in Secrets Manager
- Automatic rotation supported (configure separately)
- Encrypted with KMS
- Access controlled via IAM policies

### Secret Rotation

🔄 **Recommended for Production**:

```bash
# Enable automatic rotation for database credentials
aws secretsmanager rotate-secret \
  --secret-id fastapi-app-production-db-credentials \
  --rotation-lambda-arn arn:aws:lambda:region:account:function:SecretsManagerRotation \
  --rotation-rules AutomaticallyAfterDays=30
```

### Application Secrets

🔄 **Best Practices**:

1. **Never hardcode secrets in code**
2. **Use environment variables from Secrets Manager**
3. **Rotate secrets regularly** (database passwords, API keys, JWT secrets)
4. **Audit secret access** via CloudTrail

**Add JWT secret to Secrets Manager**:
```bash
aws secretsmanager create-secret \
  --name fastapi-app/jwt-secret \
  --secret-string "$(openssl rand -base64 32)"
```

**Update ECS task definition** to include JWT secret:
```json
{
  "secrets": [
    {
      "name": "JWT_SECRET",
      "valueFrom": "arn:aws:secretsmanager:region:account:secret:fastapi-app/jwt-secret"
    }
  ]
}
```

## Application Security

### Input Validation

✅ **Implemented**:
- Pydantic models for request validation
- FastAPI automatic validation
- SQL injection prevention via SQLAlchemy ORM

### Authentication and Authorization

✅ **Implemented**:
- JWT-based authentication
- Password hashing with bcrypt
- Token expiration (configurable)
- Protected routes with dependencies

### Additional Security Headers

🔄 **Recommended**:

Add security headers in FastAPI middleware:

```python
# app/main.py
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.sessions import SessionMiddleware

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["yourdomain.com", "*.yourdomain.com"]
)

@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    return response
```

### Rate Limiting

🔄 **Recommended**:

**Option 1: Application-level** (using slowapi):
```bash
pip install slowapi
```

```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.post("/auth/login")
@limiter.limit("5/minute")
async def login(request: Request):
    ...
```

**Option 2: AWS WAF**:
```bash
# Create rate-based rule
aws wafv2 create-web-acl \
  --name fastapi-app-waf \
  --scope REGIONAL \
  --default-action Allow={} \
  --rules file://waf-rules.json
```

### CORS Configuration

✅ **Implemented** (configure for production):

```python
# Update app/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],  # Specific domains only
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

## Monitoring and Logging

### CloudWatch Logs

✅ **Implemented**:
- ECS task logs in CloudWatch
- Log retention configured (7-30 days)
- Centralized logging

### CloudWatch Metrics and Alarms

✅ **Implemented**:
- CPU/Memory utilization tracking
- Auto-scaling based on metrics

🔄 **Additional Recommended Alarms**:

```bash
# Failed login attempts
aws cloudwatch put-metric-alarm \
  --alarm-name fastapi-high-failed-logins \
  --metric-name FailedLoginAttempts \
  --namespace FastAPI/Security \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold

# Database connection errors
aws cloudwatch put-metric-alarm \
  --alarm-name fastapi-db-connection-errors \
  --metric-name DatabaseErrors \
  --namespace FastAPI/Application \
  --statistic Sum \
  --period 60 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold
```

### AWS CloudTrail

🔄 **Recommended for Production**:

```bash
# Enable CloudTrail for API auditing
aws cloudtrail create-trail \
  --name fastapi-app-audit-trail \
  --s3-bucket-name fastapi-app-cloudtrail-logs

aws cloudtrail start-logging \
  --name fastapi-app-audit-trail

# Enable insights
aws cloudtrail put-insight-selectors \
  --trail-name fastapi-app-audit-trail \
  --insight-selectors '[{"InsightType": "ApiCallRateInsight"}]'
```

### AWS GuardDuty

🔄 **Recommended**:

```bash
# Enable GuardDuty for threat detection
aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES
```

## Compliance and Auditing

### AWS Config

🔄 **Recommended for Compliance**:

```bash
# Enable AWS Config
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=arn:aws:iam::account:role/config-role

aws configservice put-delivery-channel \
  --delivery-channel name=default,s3BucketName=config-bucket

# Start recording
aws configservice start-configuration-recorder \
  --configuration-recorder-name default
```

### Security Hub

🔄 **Recommended**:

```bash
# Enable Security Hub
aws securityhub enable-security-hub

# Enable CIS AWS Foundations Benchmark
aws securityhub batch-enable-standards \
  --standards-subscription-requests StandardsArn=arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0
```

### Compliance Standards

Consider implementing:
- **HIPAA**: If handling health data
- **PCI DSS**: If processing payments
- **SOC 2**: For service organization controls
- **GDPR**: If handling EU citizen data

## Incident Response

### Backup and Recovery

✅ **Implemented**:
- RDS automated backups (7 days retention for production)
- Final snapshot on deletion

🔄 **Enhanced Backup Strategy**:

```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier fastapi-app-production-db \
  --db-snapshot-identifier fastapi-manual-$(date +%Y%m%d)

# Copy snapshot to another region
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:us-east-1:account:snapshot:source \
  --target-db-snapshot-identifier target-snapshot \
  --region us-west-2

# Enable backup retention
aws backup create-backup-plan \
  --backup-plan file://backup-plan.json
```

### Disaster Recovery Plan

🔄 **Production Checklist**:

1. **Multi-Region Deployment** (for critical applications)
2. **Database Replication** to secondary region
3. **Regular DR Drills** (quarterly recommended)
4. **Documented Recovery Procedures**
5. **RTO/RPO Targets** defined

### Incident Response Procedure

1. **Detection**: CloudWatch Alarms, GuardDuty, Security Hub
2. **Containment**: Isolate affected resources
3. **Investigation**: Review CloudTrail logs, VPC Flow Logs
4. **Remediation**: Patch vulnerabilities, rotate credentials
5. **Recovery**: Restore from backups if needed
6. **Post-Incident**: Document lessons learned

### Emergency Contacts

🔄 **Set up SNS topic for security alerts**:

```bash
# Create SNS topic
aws sns create-topic --name fastapi-security-alerts

# Subscribe email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:account:fastapi-security-alerts \
  --protocol email \
  --notification-endpoint security-team@company.com

# Link CloudWatch alarms to SNS
aws cloudwatch put-metric-alarm \
  --alarm-name critical-security-event \
  --alarm-actions arn:aws:sns:us-east-1:account:fastapi-security-alerts
```

## Security Checklist

Use this checklist before going to production:

### Network
- [ ] VPC configured with public/private subnets
- [ ] Security groups follow least privilege
- [ ] Network ACLs configured (optional)
- [ ] VPC Flow Logs enabled
- [ ] VPC Endpoints for AWS services (recommended)

### Encryption
- [ ] RDS encryption at rest enabled
- [ ] RDS SSL/TLS in transit enabled
- [ ] Secrets Manager encryption enabled
- [ ] KMS customer managed keys (recommended)

### IAM
- [ ] IAM roles use least privilege
- [ ] MFA enabled for all users
- [ ] No hardcoded credentials
- [ ] IAM Access Analyzer enabled
- [ ] Password policy configured

### Application
- [ ] Input validation implemented
- [ ] JWT authentication configured
- [ ] Security headers added
- [ ] Rate limiting implemented
- [ ] CORS configured for specific origins
- [ ] Error messages don't leak sensitive info

### Monitoring
- [ ] CloudWatch Logs enabled
- [ ] CloudWatch Alarms configured
- [ ] CloudTrail enabled
- [ ] GuardDuty enabled (recommended)
- [ ] Security Hub enabled (recommended)

### Compliance
- [ ] AWS Config enabled (if required)
- [ ] Backup strategy implemented
- [ ] Disaster recovery plan documented
- [ ] Incident response procedure defined
- [ ] Regular security audits scheduled

### Container Security
- [ ] ECR image scanning enabled
- [ ] Base images from trusted sources
- [ ] Regular image updates
- [ ] No secrets in Docker images
- [ ] Container running as non-root user

## Additional Resources

- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

---

**Security is a shared responsibility**. While AWS secures the infrastructure, you are responsible for securing your application, data, and configurations.

**Last Updated**: October 2024
