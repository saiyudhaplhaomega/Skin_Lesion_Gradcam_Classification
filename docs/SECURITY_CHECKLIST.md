# Security Checklist

**Pre-production audit checklist for the Skin Lesion Analysis Platform**

---

## Overview

This checklist ensures all security controls are properly configured before going live. Complete each section and verify findings before production deployment.

---

## 1. Authentication & Authorization

### AWS Cognito

- [ ] Patient user pool created with email verification enabled
- [ ] Doctor user pool created with admin approval flow
- [ ] MFA enforced for all doctor accounts
- [ ] Password policy: minimum 8 characters, uppercase, lowercase, number, symbol
- [ ] Account recovery set to "Admin only" for doctor pool (prevents social engineering)
- [ ] Custom attributes configured: `role` (patient/doctor/admin), `approved` (boolean)
- [ ] Cognito user pool URLs not exposed in client-side code
- [ ] JWT tokens validated server-side (not just trusted client-side)

### Backend Authorization

- [ ] All protected endpoints validate JWT on every request
- [ ] Role-based access control enforced at endpoint level
- [ ] Doctors cannot access other doctors' cases
- [ ] Patients can only access their own predictions
- [ ] Admin endpoints require admin role (no bypass)
- [ ] JWT expiration enforced (access token: 1 hour, refresh token: 30 days)
- [ ] Token blacklist implemented for logout

### API Security

- [ ] Rate limiting configured per user tier
- [ ] Input validation on all endpoints (Pydantic schemas enforced)
- [ ] SQL injection prevention (parameterized queries via SQLAlchemy)
- [ ] No raw SQL queries in codebase
- [ ] XSS prevention (proper Content-Type headers, input sanitization)

---

## 2. Infrastructure Security

### VPC Configuration

- [ ] VPC created with proper CIDR block (10.0.0.0/16 recommended)
- [ ] 3-tier subnet design: Public (ALB), App (ECS), Data (RDS/Redis)
- [ ] NAT Gateway in public subnet for outbound traffic from private subnets
- [ ] S3 VPC endpoint created for ECS to S3 communication (no internet)
- [ ] No direct internet access to ECS tasks
- [ ] Security groups restrict traffic:
  - ALB: 80/443 from anywhere
  - ECS: 8080 from ALB security group only
  - RDS: 5432 from ECS security group only
  - Redis: 6379 from ECS security group only

### Encryption

- [ ] RDS encryption enabled (KMS)
- [ ] S3 buckets server-side encryption (AES-256)
- [ ] S3 buckets block public access
- [ ] Redis at-rest encryption enabled
- [ ] TLS 1.2+ enforced on all ALB listeners
- [ ] Certificate manager SSL certificate valid and auto-renewed

### Network Security

- [ ] CloudTrail multi-region logging enabled
- [ ] VPC Flow Logs configured (30-day CloudWatch retention minimum)
- [ ] GuardDuty enabled with S3 and malware protection
- [ ] WAF attached to ALB with rules:
  - Rate limit: 1000 requests/min per IP (block)
  - SQL injection: query string (block)
  - XSS: query string (block)
  - Known malicious IPs: TOR exit nodes (block)
- [ ] No security groups allow 0.0.0.0/0 to database ports

---

## 3. Data Protection

### GDPR Compliance

- [ ] Consent flow is explicit opt-in (not pre-checked)
- [ ] Patient can withdraw consent at any time
- [ ] Data export endpoint functional (`/api/v1/users/me/export`)
- [ ] Data deletion endpoint functional (`/api/v1/users/me/delete`)
- [ ] Image retention: Redis TTL 1 hour, then automatic deletion
- [ ] Data retention policy documented:
  - Account info: Until user deletion
  - Predictions metadata: 2 years
  - Consented images in training pool: Until retrain cycle
- [ ] Privacy policy page published
- [ ] Cookie consent banner implemented (if using cookies)

### Data Handling

- [ ] No patient images stored in database (only S3 paths)
- [ ] Patient demographics anonymized in training pool
- [ ] Training data labeled with approved status and approval date
- [ ] GDPR data export includes: account, predictions, expert opinions
- [ ] Export files encrypted and auto-deleted after 7 days

### Storage

- [ ] S3 versioning enabled on training bucket
- [ ] S3 lifecycle rules: incomplete uploads abort after 7 days
- [ ] No S3 buckets publicly accessible
- [ ] IAM roles follow least privilege principle:
  - ECS task execution role: pull images, write logs only
  - ECS task role: S3 (no delete), RDS (connect only), Cognito (describe/list)
  - DENY policy blocks: DeleteObject, DeleteBucket, PutBucketPolicy

---

## 4. Application Security

### Code Security

- [ ] No hardcoded secrets in code (use AWS Secrets Manager)
- [ ] Environment variables validated at startup
- [ ] Dependencies audited: no critical CVEs
- [ ] Security scanning in CI (Bandit/Semgrep)
- [ ] No `eval()` or dynamic code execution
- [ ] File upload validation: type, size (10MB max), content scanning
- [ ] Image processing done server-side (no client-side execution)

### API Security

- [ ] CORS configured for allowed origins only
- [ ] CSRF protection for state-changing operations
- [ ] Request ID generated for every request (for audit trail)
- [ ] Error responses don't leak stack traces
- [ ] API versioning in place (`/api/v1/`)
- [ ] Deprecation policy for old API versions documented

### Secrets Management

- [ ] AWS Secrets Manager for database credentials
- [ ] AWS Secrets Manager for Redis credentials
- [ ] AWS Secrets Manager for AWS access keys (instead of environment vars)
- [ ] Secrets rotation scheduled (90-day rotation recommended)
- [ ] No secrets in GitHub Actions logs (masked or absent)

---

## 5. Monitoring & Incident Response

### Monitoring

- [ ] CloudWatch alarms configured for:
  - ECS CPU > 80% for 5 minutes
  - RDS connections > 80% max
  - ALB 5xx error rate > 1%
  - GuardDuty HIGH/CRITICAL findings
- [ ] CloudWatch Dashboard created for operations team
- [ ] Log aggregation: ECS logs → CloudWatch → centralized
- [ ] Sentry configured for error tracking
- [ ] X-Ray tracing enabled for API latency analysis

### Incident Response

- [ ] Runbook for GuardDuty findings (who is notified, how to respond)
- [ ] Escalation path documented (on-call → senior → management)
- [ ] Incident response team contact list maintained
- [ ] Post-mortem template created for incidents
- [ ] Communication template for user-facing outages

---

## 6. Compliance Verification

### Pre-Launch Audit

- [ ] Penetration testing completed (or scheduled)
- [ ] Vulnerability scan completed (no critical findings)
- [ ] GDPR readiness review completed
- [ ] Data Processing Agreement (DPA) signed with AWS
- [ ] Privacy policy reviewed by legal
- [ ] Terms of service reviewed by legal
- [ ] Cookie policy (if applicable) reviewed
- [ ] App Store compliance verified (Apple review guidelines)
- [ ] Play Store compliance verified (Google developer policies)

### Documentation

- [ ] Data flow diagram documented and current
- [ ] Architecture diagrams updated with latest changes
- [ ] Security architecture documented
- [ ] Incident response plan documented
- [ ] DR runbook documented and tested

---

## 7. Container & Deployment Security

### Docker

- [ ] Containers run as non-root user
- [ ] No debug tools in production image
- [ ] Images built from official base images
- [ ] Docker bench security checks pass
- [ ] No secrets baked into image (use runtime injection)

### Deployment

- [ ] ECS rolling deployment configured (health check before traffic)
- [ ] No direct SSH access to ECS tasks
- [ ] Bastion host for emergency access (if needed) with audit logging
- [ ] Deployment requires GitHub Actions approval (no direct push)
- [ ] Rollback procedure documented and tested

---

## 8. Third-Party Dependencies

### Dependency Management

- [ ] Dependabot enabled and alerts reviewed
- [ ] No dependencies from untrusted sources
- [ ] License compliance verified (no GPL licenses in production)
- [ ] Dependencies pinned to specific versions (no "latest")
- [ ] Regular dependency updates scheduled (monthly)

### External Services

- [ ] AWS S3 endpoint for S3 access (no internet)
- [ ] External APIs use TLS (no HTTP)
- [ ] API keys stored in Secrets Manager (not code)
- [ ] Rate limiting awareness for external services

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Security Reviewer | | | |
| DevOps Lead | | | |
| CTO/Technical Lead | | | |

---

## Findings Tracker

| Finding | Severity | Status | Remediation | Date Closed |
|---------|----------|--------|-------------|-------------|
| | | | | |
| | | | | |
| | | | | |

---

## Next Steps

Once all items are checked and approved:

1. Move pending findings to remediation plan
2. Schedule follow-up audit in 30 days
3. Enable production deployment gates in GitHub Actions
4. Schedule quarterly security reviews