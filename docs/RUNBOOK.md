# EIRS Operations & Incident Response Runbook
## Runbooks, Monitoring Thresholds, and Automated Recovery Procedures

---

### 1. Key Operational Metrics & Alarm Thresholds

| Metric Name | AWS Namespace | Warning Threshold | Critical Threshold | Automated Action |
| :--- | :--- | :--- | :--- | :--- |
| **API 5XX Error Rate** | `AWS/ApiGateway` | > 1.0% over 5 mins | > 3.0% over 2 mins | Trigger SNS PagerDuty, halt active deployments |
| **API Latency (p95)** | `AWS/ApiGateway` | > 300 ms | > 800 ms | Scale Lambda concurrency, alert on-call engineer |
| **Lambda Throttles** | `AWS/Lambda` | > 5 throttles / min | > 20 throttles / min | Auto-increase reserved concurrency limits |
| **DynamoDB Read/Write Throttles** | `AWS/DynamoDB` | > 0 throttles | > 10 throttles | Escalate DynamoDB autoscaling capacity |
| **Synthetics Canary Failure** | `CloudWatchSynthetics` | 1 probe failed | 2 consecutive failures | **Initiate Automatic Rollback Script** |

---

### 2. Multi-Environment Promotion & Rollback Workflow

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Development (Dev)
    participant QA as QA Environment
    participant Staging as Staging (UAT)
    participant Gate as Approval Gate
    participant Prod as Production (Canary 10%)
    participant Canary as CloudWatch Canary Monitor
    participant Rollback as Automated Rollback Engine

    Dev->>QA: Automated promotion upon passing Unit Tests & SAST
    QA->>QA: Execute automated API, Contract & Integration Tests
    QA->>Staging: Promote build artifact upon 100% QA pass
    Staging->>Staging: Run DAST, Performance benchmark & Security scans
    Staging->>Gate: Request Production Deployment Approval
    Gate->>Prod: Approved by Release Manager -> Deploy 10% Canary
    Prod->>Canary: Monitor Latency, 5xx errors & synthetic transactions
    alt Health Check Passes
        Canary-->>Prod: SLA Healthy -> Shift traffic to 100%
    else Health Check Fails (5xx > 1% or Canary Failure)
        Canary->>Rollback: Trigger Alarm: Health Check Breach
        Rollback->>Prod: Roll back alias/CloudFront target to Previous Stable Release
        Rollback-->>Gate: Broadcast Incident Alert via Slack / SNS
    end
```

---

### 3. Emergency Incident Runbooks

#### Runbook A: Immediate Production Rollback
If a defect escapes to production or error rates spike, execute the instant rollback script:
```powershell
# From deployment control plane:
pwsh ./scripts/aws-cli/08-rollback.ps1 -Environment "prod" -TargetVersion "PREVIOUS_STABLE"
```
**What this does:**
1. Instantly shifts API Gateway stage variable / Lambda alias routing weight 100% back to previous stable version.
2. Invalidates CloudFront edge caches.
3. Posts operational resolution logs to CloudWatch and alerts the response team.

#### Runbook B: WAF Rate-Limiting Adjustment (Handling Traffic Surge)
In the event of a legitimate national registration spike or holiday surge:
```powershell
aws wafv2 update-rule-group --scope REGIONAL --name EIRS-RateLimit-Rule ...
```
Detailed commands are encapsulated in `./scripts/aws-cli/06-deploy-edge.ps1`.
