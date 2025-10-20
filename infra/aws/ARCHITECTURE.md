# AWS Architecture Documentation

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud                                  │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                      VPC (10.0.0.0/16)                         │ │
│  │                                                                 │ │
│  │  ┌──────────────────┐         ┌──────────────────┐            │ │
│  │  │  Availability    │         │  Availability    │            │ │
│  │  │    Zone 1        │         │    Zone 2        │            │ │
│  │  │                  │         │                  │            │ │
│  │  │  ┌────────────┐  │         │  ┌────────────┐  │            │ │
│  │  │  │  Public    │  │         │  │  Public    │  │            │ │
│  │  │  │  Subnet    │  │         │  │  Subnet    │  │            │ │
│  │  │  │ 10.0.1.0/24│  │         │  │ 10.0.2.0/24│  │            │ │
│  │  │  │            │  │         │  │            │  │            │ │
│  │  │  │    ALB     │◄─┼─────────┼─►│    ALB     │  │            │ │
│  │  │  │  (Target)  │  │         │  │  (Target)  │  │            │ │
│  │  │  └─────┬──────┘  │         │  └──────┬─────┘  │            │ │
│  │  │        │         │         │         │        │            │ │
│  │  │  ┌─────▼──────┐  │         │  ┌──────▼─────┐  │            │ │
│  │  │  │  Private   │  │         │  │  Private   │  │            │ │
│  │  │  │  Subnet    │  │         │  │  Subnet    │  │            │ │
│  │  │  │ 10.0.11.0  │  │         │  │ 10.0.12.0  │  │            │ │
│  │  │  │    /24     │  │         │  │    /24     │  │            │ │
│  │  │  │            │  │         │  │            │  │            │ │
│  │  │  │ ┌────────┐ │  │         │  │ ┌────────┐ │  │            │ │
│  │  │  │ │  ECS   │ │  │         │  │ │  ECS   │ │  │            │ │
│  │  │  │ │  Task  │ │  │         │  │ │  Task  │ │  │            │ │
│  │  │  │ │Fargate │ │  │         │  │ │Fargate │ │  │            │ │
│  │  │  │ └───┬────┘ │  │         │  │ └───┬────┘ │  │            │ │
│  │  │  │     │      │  │         │  │     │      │  │            │ │
│  │  │  │     └──────┼──┼─────────┼──┼─────┘      │  │            │ │
│  │  │  │            │  │         │  │            │  │            │ │
│  │  │  │    ┌───────▼──▼─────────▼──▼───────┐   │  │            │ │
│  │  │  │    │     RDS PostgreSQL             │   │  │            │ │
│  │  │  │    │     (Multi-AZ)                 │   │  │            │ │
│  │  │  │    │  Primary ◄─► Standby           │   │  │            │ │
│  │  │  │    └────────────────────────────────┘   │  │            │ │
│  │  │  └────────────┘  │         │  └────────────┘  │            │ │
│  │  │                  │         │                  │            │ │
│  │  │  ┌────────────┐  │         │  ┌────────────┐  │            │ │
│  │  │  │ NAT Gateway│  │         │  │ NAT Gateway│  │            │ │
│  │  │  └─────┬──────┘  │         │  └──────┬─────┘  │            │ │
│  │  └────────┼─────────┘         └─────────┼────────┘            │ │
│  │           │                              │                     │ │
│  │  ┌────────▼──────────────────────────────▼─────┐              │ │
│  │  │         Internet Gateway                     │              │ │
│  │  └──────────────────────────────────────────────┘              │ │
│  └─────────────────────────────────────────────────────────────┬─┘ │
│                                                                  │   │
│  ┌─────────────────────────────────────────────────────────────┼─┐ │
│  │  Supporting Services                                         │ │ │
│  │                                                               │ │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │ │ │
│  │  │   Secrets    │  │  CloudWatch  │  │     ECR      │      │ │ │
│  │  │   Manager    │  │     Logs     │  │  (Container  │      │ │ │
│  │  │              │  │              │  │   Registry)  │      │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │ │ │
│  │                                                               │ │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │ │ │
│  │  │   Auto       │  │  CloudWatch  │  │   Route 53   │      │ │ │
│  │  │   Scaling    │  │   Alarms     │  │    (DNS)     │      │ │ │
│  │  │              │  │              │  │              │      │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │ │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                            ┌─────▼─────┐
                            │   Users   │
                            │ (Internet)│
                            └───────────┘
```

## Component Details

### 1. Virtual Private Cloud (VPC)

**Configuration:**
- CIDR: 10.0.0.0/16
- Availability Zones: 2 (for high availability)
- DNS Support: Enabled
- DNS Hostnames: Enabled

**Subnets:**

| Subnet | CIDR | Type | Purpose |
|--------|------|------|---------|
| Public Subnet 1 | 10.0.1.0/24 | Public | ALB, NAT Gateway (AZ-1) |
| Public Subnet 2 | 10.0.2.0/24 | Public | ALB, NAT Gateway (AZ-2) |
| Private Subnet 1 | 10.0.11.0/24 | Private | ECS Tasks, RDS (AZ-1) |
| Private Subnet 2 | 10.0.12.0/24 | Private | ECS Tasks, RDS (AZ-2) |

### 2. Application Load Balancer (ALB)

**Features:**
- Internet-facing
- Multi-AZ deployment
- Health checks on `/healthz`
- HTTP/HTTPS support
- Cross-zone load balancing enabled

**Target Group:**
- Target Type: IP (for Fargate)
- Protocol: HTTP
- Port: 8000
- Health Check Interval: 30s
- Health Check Timeout: 5s
- Healthy Threshold: 2
- Unhealthy Threshold: 3

**Listeners:**
- HTTP (Port 80) → Forward to Target Group
- HTTPS (Port 443) → Optional (requires ACM certificate)

### 3. ECS Fargate

**Cluster Configuration:**
- Launch Type: Fargate (serverless)
- Capacity Providers: Fargate, Fargate Spot
- Container Insights: Enabled

**Task Definition:**
- CPU: 512 units (0.5 vCPU)
- Memory: 1024 MB (1 GB)
- Network Mode: awsvpc
- Platform: Linux/x86_64

**Container:**
- Image: From Amazon ECR
- Port: 8000
- Health Check: HTTP GET /healthz
- Logging: CloudWatch Logs
- Environment Variables: From Secrets Manager

**Service:**
- Desired Count: 2 tasks
- Min Healthy Percent: 100%
- Max Percent: 200%
- Deployment Circuit Breaker: Enabled
- Rollback on Failure: Enabled

### 4. RDS PostgreSQL

**Configuration:**
- Engine: PostgreSQL 15.4
- Instance Class: db.t3.micro (production: db.t3.small+)
- Storage: 20 GB GP3 (auto-scaling to 100 GB)
- Multi-AZ: Yes (for production)
- Encryption: AES-256
- Backup Retention: 7 days (production)

**Network:**
- Subnet Group: Private subnets only
- Public Access: Disabled
- VPC Security Group: RDS-specific

**Features:**
- Automated backups
- Performance Insights (production)
- CloudWatch log exports (PostgreSQL, upgrade)
- Deletion protection (production)

### 5. Security Groups

```
┌───────────────────────────────────────────────────────────┐
│                    Security Architecture                   │
└───────────────────────────────────────────────────────────┘

Internet (0.0.0.0/0)
    │
    │ HTTP/HTTPS (80/443)
    ▼
┌──────────────────┐
│  ALB Security    │
│     Group        │
└────────┬─────────┘
         │ Port 8000
         ▼
┌──────────────────┐
│  ECS Security    │
│     Group        │
└────────┬─────────┘
         │ Port 5432
         ▼
┌──────────────────┐
│  RDS Security    │
│     Group        │
└──────────────────┘
```

**ALB Security Group:**
```
Inbound:
  - TCP 80 from 0.0.0.0/0 (HTTP)
  - TCP 443 from 0.0.0.0/0 (HTTPS)
Outbound:
  - All traffic to ECS Security Group
```

**ECS Security Group:**
```
Inbound:
  - TCP 8000 from ALB Security Group
Outbound:
  - All traffic (for AWS API calls, internet access via NAT)
```

**RDS Security Group:**
```
Inbound:
  - TCP 5432 from ECS Security Group
Outbound:
  - None required
```

### 6. Auto Scaling

**Scaling Policies:**

**CPU-Based Scaling:**
```yaml
Metric: ECSServiceAverageCPUUtilization
Target Value: 70%
Scale Out Cooldown: 60 seconds
Scale In Cooldown: 300 seconds
```

**Memory-Based Scaling:**
```yaml
Metric: ECSServiceAverageMemoryUtilization
Target Value: 80%
Scale Out Cooldown: 60 seconds
Scale In Cooldown: 300 seconds
```

**Task Limits:**
```yaml
Minimum Tasks: 2
Maximum Tasks: 6
Desired Tasks: 2
```

### 7. Secrets Manager

**Secrets Stored:**
- Database credentials (username, password)
- Database connection string
- Database host, port, name

**Security:**
- Encrypted with AWS KMS
- Access controlled via IAM policies
- Rotation supported (optional)

### 8. CloudWatch

**Log Groups:**
- `/ecs/fastapi-app-production` - Application logs
- Retention: 7 days (dev), 30 days (production)

**Metrics:**
- ECS: CPU, Memory, Task count
- ALB: Request count, Target response time, HTTP codes
- RDS: CPU, Connections, Storage, IOPS

**Alarms (Recommended):**
- High CPU utilization (>80%)
- High Memory utilization (>90%)
- Unhealthy targets
- Database connection errors
- HTTP 5xx errors

### 9. ECR (Elastic Container Registry)

**Configuration:**
- Image scanning on push: Enabled
- Encryption: AES-256
- Lifecycle policy: Keep last 10 tagged images
- Tag mutability: Mutable

## Network Flow

### Request Flow

```
1. User Request
   │
   ├─► Internet Gateway
   │
   ├─► Application Load Balancer (Public Subnet)
   │   ├─► Health Check /healthz
   │   └─► Route to healthy target
   │
   ├─► ECS Task (Private Subnet)
   │   ├─► Fetch secrets from Secrets Manager
   │   ├─► Connect to RDS (via private network)
   │   ├─► Execute application logic
   │   └─► Return response
   │
   └─► User receives response
```

### Database Connection Flow

```
ECS Task
   │
   ├─► Retrieve DB credentials from Secrets Manager
   │
   ├─► Establish connection to RDS
   │   ├─► Protocol: PostgreSQL (Port 5432)
   │   ├─► SSL/TLS: Required
   │   └─► Network: Private subnet only
   │
   └─► Execute queries
```

### Outbound Internet Access

```
ECS Task (Private Subnet)
   │
   ├─► Route to NAT Gateway
   │
   ├─► NAT Gateway (Public Subnet)
   │
   ├─► Internet Gateway
   │
   └─► Internet (for external API calls, package downloads)
```

## Deployment Flow

### Initial Deployment

```
1. Build Phase
   ├─► Build Docker image locally
   ├─► Tag image with version
   └─► Push to ECR

2. Infrastructure Phase (CloudFormation/Terraform)
   ├─► Create VPC and networking
   ├─► Create security groups
   ├─► Create RDS database
   ├─► Store credentials in Secrets Manager
   ├─► Create ALB and target group
   ├─► Create ECS cluster
   ├─► Create task definition
   └─► Create ECS service

3. Deployment Phase
   ├─► ECS pulls image from ECR
   ├─► Start tasks in private subnets
   ├─► Tasks retrieve secrets
   ├─► Tasks connect to database
   ├─► Tasks register with target group
   └─► ALB routes traffic to healthy tasks

4. Verification Phase
   ├─► Health checks pass
   ├─► Auto-scaling configured
   └─► Monitoring enabled
```

### Update Deployment

```
1. Build new image
   └─► Push to ECR with new tag

2. Update infrastructure
   ├─► Update task definition with new image
   └─► Update ECS service

3. Rolling deployment
   ├─► Start new tasks with new image
   ├─► Wait for health checks
   ├─► Drain connections from old tasks
   └─► Terminate old tasks

4. Rollback (if failures detected)
   ├─► Circuit breaker triggers
   └─► Revert to previous task definition
```

## High Availability

### Multi-AZ Deployment

**Components across AZs:**
- Application Load Balancer targets in 2 AZs
- ECS tasks distributed across 2 AZs
- RDS Multi-AZ with automatic failover

**Failure Scenarios:**

**AZ Failure:**
```
AZ-1 becomes unavailable
   ├─► ALB stops routing to AZ-1 targets
   ├─► ECS service launches replacement tasks in AZ-2
   └─► RDS fails over to standby in AZ-2
   └─► Service continues with minimal disruption
```

**Task Failure:**
```
ECS task fails health check
   ├─► ALB marks target as unhealthy
   ├─► ALB stops routing to failed task
   ├─► ECS service launches replacement task
   └─► New task registers with ALB
```

**Database Failure:**
```
Primary RDS instance fails
   ├─► RDS detects failure
   ├─► Automatic failover to standby
   ├─► DNS record updated (1-2 minutes)
   └─► Application reconnects automatically
```

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────┐
│                  CloudWatch                          │
│                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │    Logs      │  │   Metrics    │  │  Alarms   │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         │                 │                 │        │
└─────────┼─────────────────┼─────────────────┼────────┘
          │                 │                 │
    ┌─────▼─────┐    ┌──────▼──────┐   ┌─────▼─────┐
    │ ECS Tasks │    │     ALB     │   │    SNS    │
    │   Logs    │    │   Metrics   │   │  Alerts   │
    └─────┬─────┘    └──────┬──────┘   └───────────┘
          │                 │
    ┌─────▼─────────────────▼──────┐
    │   CloudWatch Dashboard        │
    │   - Request rate              │
    │   - Error rate                │
    │   - Response time             │
    │   - CPU/Memory utilization    │
    └───────────────────────────────┘
```

## Cost Optimization

### Cost Breakdown

```
┌─────────────────────────────────────────────────┐
│         Monthly Cost Estimate (Production)       │
├─────────────────────────────────────────────────┤
│ ECS Fargate (2 tasks, 0.5 vCPU, 1GB)  $ 30.00  │
│ RDS db.t3.micro Multi-AZ                $ 30.00  │
│ Application Load Balancer               $ 16.00  │
│ NAT Gateway (1)                         $ 32.00  │
│ Data Transfer (10 GB)                   $  1.00  │
│ ECR Storage (5 GB)                      $  0.50  │
│ CloudWatch Logs (5 GB)                  $  2.50  │
│ Secrets Manager                         $  0.40  │
├─────────────────────────────────────────────────┤
│ TOTAL                                   $112.40  │
└─────────────────────────────────────────────────┘
```

### Cost Optimization Strategies

1. **Use Fargate Spot** (up to 70% savings on compute)
2. **Reserved Instances for RDS** (up to 60% savings)
3. **VPC Endpoints** (eliminate NAT Gateway costs)
4. **S3 Lifecycle Policies** (archive old logs)
5. **Auto-scaling** (match capacity to demand)
6. **Scheduled Scaling** (reduce capacity during off-hours)

## Security Layers

```
┌─────────────────────────────────────────────────────┐
│                  Security Layers                     │
├─────────────────────────────────────────────────────┤
│ Layer 1: Network (VPC, Subnets, NACLs)              │
│ Layer 2: Security Groups (Stateful firewall)        │
│ Layer 3: IAM (Identity and permissions)             │
│ Layer 4: Encryption (At rest and in transit)        │
│ Layer 5: Application (JWT, input validation)        │
│ Layer 6: Monitoring (CloudWatch, CloudTrail)        │
└─────────────────────────────────────────────────────┘
```

## Disaster Recovery

**Recovery Metrics:**
- RTO (Recovery Time Objective): < 15 minutes
- RPO (Recovery Point Objective): < 5 minutes

**Backup Strategy:**
- RDS automated backups: Daily
- RDS snapshots: Retained for 7 days
- Final snapshot on deletion: Enabled
- Cross-region backup: Recommended for production

**Recovery Procedures:**
1. Database restoration from snapshot
2. Infrastructure recreation from IaC
3. Image deployment from ECR
4. Configuration from Secrets Manager

---

This architecture provides:
✅ High availability
✅ Auto-scaling
✅ Security in depth
✅ Cost optimization
✅ Monitoring and observability
✅ Disaster recovery capabilities
