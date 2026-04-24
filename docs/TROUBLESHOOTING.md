# Troubleshooting Guide

**Common issues and their solutions for the Skin Lesion Analysis Platform**

---

## Quick Reference

| Problem Area | Common Issues | Start Here |
|--------------|----------------|------------|
| Backend | Model won't load, JWT fails, Redis timeout | Section 1 |
| Frontend | CORS errors, build fails, auth redirects | Section 2 |
| Mobile | Auth token, image picker, offline sync | Section 3 |
| Infrastructure | ECS tasks failing, DB connection | Section 4 |
| ML Pipeline | Training fails, model performance | Section 5 |

---

## 1. Backend Issues

### 1.1 Model Won't Load

**Symptoms:**
- `/api/v1/predict` returns 503 "Model not loaded"
- Startup logs show "Model not found at..."

**Diagnosis:**
```bash
# Check if model exists in S3
aws s3 ls s3://skin-lesion-models-{account}/production/

# Check environment variable
echo $MODEL_PATH

# Check ECS task logs
aws logs tail /ecs/skin-lesion-prod --filter-pattern "Model"
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| MODEL_PATH env var missing | Set in ECS task definition or Secrets Manager |
| S3 object doesn't exist | Check bucket name, run `aws s3 sync` to upload |
| Wrong S3 region | Verify `AWS_REGION` matches bucket region |
| IAM role missing S3 permissions | Add `s3:GetObject` to ECS task role |
| File corrupted | Re-upload from local backup: `aws s3 cp local.pth s3://bucket/production/` |

**Resolution:**
```bash
# 1. Verify model exists
aws s3 ls s3://skin-lesion-models-PROD/model.pth

# 2. If missing, upload
aws s3 cp ./ml/outputs/models/resnet50_best.pth s3://skin-lesion-models-PROD/production/resnet50_v1.x.pth

# 3. Restart ECS tasks (triggers new model load)
aws ecs update-service --cluster skin-lesion-prod --service skin-lesion-backend --force-new-deployment
```

---

### 1.2 JWT Validation Fails

**Symptoms:**
- 401 Unauthorized on all protected endpoints
- "Token has expired" or "Invalid token signature"
- Users randomly logged out

**Diagnosis:**
```bash
# Check Cognito JWKS endpoint
curl https://cognito-idp.us-east-1.amazonaws.com/{pool_id}/.well-known/jwks.json

# Verify token expiration
echo $JWT_EXPIRATION

# Check system clock on ECS tasks
aws ecs execute-command --cluster skin-lesion-prod --task {task_id} --container backend -- ls /etc/timezone
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Clock skew > 5 minutes | Ensure NTP on ECS tasks, check instance timezone |
| Token expired | Implement refresh token flow in frontend |
| Wrong Cognito pool ID | Verify COGNITO_PATIENT_POOL_ID env var |
| JWKS cache stale | Clear cache, force refresh on startup |
| Token signature mismatch | Verify JWT header kid matches Cognito key |

**Resolution:**
```python
# Force JWKS refresh in code
async def get_jwks(self, force_refresh: bool = True):
    if force_refresh:
        self._jwks = None  # Clear cache
    return await self._fetch_jwks()
```

---

### 1.3 Redis Connection Refused

**Symptoms:**
- Predictions not stored, "Failed to store prediction"
- `/api/v1/explain` returns 404 "Prediction not found"
- Intermittent timeout errors

**Diagnosis:**
```bash
# Check Redis connectivity from ECS task
aws ecs execute-command --cluster skin-lesion-prod --task {task_id} --container backend -- nc -zv skin-lesion-redis.xxxxxxxxx.0001.us-east-1.cache.amazonaws.com 6379

# Check Redis memory
redis-cli -h skin-lesion-redis.xxxxxxxxx.0001.us-east-1.cache.amazonaws.com info memory

# Check CloudWatch logs
aws logs filter-log-events --log-group-name /ecs/skin-lesion-prod --filter-pattern "Redis"
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Security group blocks port 6379 | Add inbound rule from ECS security group |
| Redis cluster unavailable | Check ElastiCache console, verify cluster status |
| Memory exhausted (maxmemory) | Configure Redis eviction policy: `allkeys-lru` |
| Wrong endpoint | Check REDIS_URL env var (use internal endpoint, not public) |

**Resolution:**
```python
# In config.py - use internal Redis endpoint
REDIS_URL = "redis://skin-lesion-redis.xxxxxxxxx.0001.us-east-1.cache.amazonaws.com:6379/0"

# Update ECS task definition with correct endpoint
# Or set via Secrets Manager: redis-host, redis-port
```

---

### 1.4 Database Connection Issues

**Symptoms:**
- 500 errors on admin endpoints
- " connection timeout" in logs
- Slow query responses

**Diagnosis:**
```bash
# Check RDS connections
aws rds describe-db-instances --db-instance-identifier skin-lesion-prod --query 'DBInstances[0].Connections'

# Check CloudWatch metrics
# Look for DatabaseConnections > 80% of max_connections

# Test connection from bastion (if available)
psql -h skin-lesion-prod.xxxxxxxxx.us-east-1.rds.amazonaws.com -U skinlesionadmin -d skinlesion
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Connection pool exhausted | Increase DATABASE_POOL_SIZE (max 20 for t3.medium) |
| RDS maintenance | Check AWS Health Dashboard |
| Wrong connection string | Format: `postgresql+asyncpg://user:pass@host:5432/db` |
| SSL connection failure | Add `?ssl=true` to connection string |

**Resolution:**
```python
# In config.py
DATABASE_URL = "postgresql+asyncpg://skinlesionadmin:{password}@skin-lesion-prod.xxxxxxxxx.us-east-1.rds.amazonaws.com:5432/skinlesion?ssl=true"
DATABASE_POOL_SIZE = 20
DATABASE_MAX_OVERFLOW = 10
```

---

### 1.5 ECS Tasks Not Starting

**Symptoms:**
- `DEPLOYMENT_FAILED` or `TASK_FAILED_TO_START`
- Tasks stuck in `PROVISIONING` state
- Health check failing repeatedly

**Diagnosis:**
```bash
# List tasks and their status
aws ecs list-tasks --cluster skin-lesion-prod --service-name skin-lesion-backend

# Get task failure reason
aws ecs describe-tasks --cluster skin-lesion-prod --tasks {task_arn} --query 'tasks[0].stopCode'

# Check service events
aws ecs describe-services --cluster skin-lesion-prod --services skin-lesion-backend --query 'services[0].events[:5]'
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Image not found in ECR | Check `aws ecr describe-repositories`, verify image tag exists |
| Insufficient memory | Increase memory in task definition (2048 MB minimum) |
| Security group changed | Ensure ECS can reach ALB, RDS, Redis, S3 |
| Missing environment variables | Check Secrets Manager, verify all required vars set |
| Health check failing | Increase `startPeriod` to 60s, check app startup time |

**Resolution:**
```bash
# Force new deployment
aws ecs update-service --cluster skin-lesion-prod --service skin-lesion-backend --force-new-deployment

# If stuck, delete failing tasks
aws ecs stop-task --cluster skin-lesion-prod --task {task_id}

# Verify task definition is valid
aws ecs validate-task-definition --task-definition skin-lesion-backend:1
```

---

## 2. Frontend Issues

### 2.1 CORS Errors

**Symptoms:**
- `Access-Control-Allow-Origin` error in browser console
- OPTIONS preflight failing
- API requests fail only from browser (Postman works)

**Diagnosis:**
Check browser console for specific header information

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| ALB not forwarding CORS headers | Add headers in ALB rules or FastAPI middleware |
| Origin not in ALLOWED_ORIGINS | Update `ALLOWED_ORIGINS` in config.py, redeploy |
| Wrong protocol (HTTP vs HTTPS) | Ensure frontend uses HTTPS in production |
| Preflight (OPTIONS) not handled | Ensure CORS middleware handles OPTIONS before auth |

**Resolution:**
```python
# In app/main.py - ensure CORS middleware added BEFORE router
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

Verify ALB listener rules include:
```
Access-Control-Allow-Origin: https://your-frontend.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
```

---

### 2.2 Build Failures

**Symptoms:**
- `npm run build` fails in GitHub Actions
- TypeScript errors in CI but not locally
- "Module not found" errors

**Diagnosis:**
```bash
# Check local Node version
node --version  # Should be 20

# Check for lock file issues
rm -rf node_modules package-lock.json && npm install

# Run type check locally
npm run type-check
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Node version mismatch | Use Node 20 in GitHub Actions (setup-node@v4) |
| Missing dependencies | Run `npm install` before build |
| TypeScript errors | Fix type errors, use `// @ts-ignore` only as last resort |
| Environment variable missing | Add `NEXT_PUBLIC_` prefix for client-side vars |

**Resolution:**
```bash
# Ensure .env.production has all required vars
NEXT_PUBLIC_API_URL=https://api.skinlesion.com
NEXT_PUBLIC_AWS_REGION=us-east-1

# Test build locally
npm run build
```

---

### 2.3 Authentication Redirect Issues

**Symptoms:**
- Users redirected to login repeatedly
- Token stored but auth still fails
- Infinite redirect loop

**Diagnosis:**
Check browser localStorage for `auth_tokens` and application network tab

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Token expired but not refreshed | Implement refresh token logic in AuthContext |
| Cookie not set correctly | Check `credentials: "include"` in fetch calls |
| Server returning 401 but client not redirecting | Add auth check in API client interceptor |
| Secure flag on cookie (dev vs prod) | Match `secure: true` with HTTPS only |

**Resolution:**
```typescript
// In lib/api.ts - add response interceptor
export async function fetchWithAuth(url: string, options: RequestInit = {}) {
  const token = await getStoredToken();
  const response = await fetch(url, {
    ...options,
    headers: {
      ...options.headers,
      Authorization: `Bearer ${token}`,
    },
  });

  if (response.status === 401) {
    // Try refresh or redirect to login
    await logout();
    router.push('/login');
  }

  return response;
}
```

---

## 3. Mobile Issues

### 3.1 Auth Token Management

**Symptoms:**
- Users logged out immediately after login
- "Token expired" errors on every request
- Token stored but API calls fail

**Diagnosis:**
```typescript
// Check SecureStore
import * as SecureStore from 'expo-secure-store';

// Test token retrieval
const token = await SecureStore.getItemAsync('auth_tokens');
console.log('Token:', token);
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| SecureStore not persistent | Use `setItemAsync` with JSON string |
| Token not refreshing | Implement background token refresh |
| Device clock incorrect | Auth tokens are time-sensitive; sync device clock |
| Expo SDK version mismatch | Ensure `expo-secure-store` version matches SDK |

**Resolution:**
```typescript
// Store tokens correctly
await SecureStore.setItemAsync(
  'auth_tokens',
  JSON.stringify({
    accessToken: result.accessToken,
    refreshToken: result.refreshToken,
    expiresAt: Date.now() + result.expiresIn * 1000
  })
);

// Retrieve with expiration check
const data = await SecureStore.getItemAsync('auth_tokens');
if (data) {
  const tokens = JSON.parse(data);
  if (tokens.expiresAt < Date.now()) {
    // Refresh token
    const newTokens = await refreshToken(tokens.refreshToken);
    await SecureStore.setItemAsync('auth_tokens', JSON.stringify(newTokens));
  }
}
```

---

### 3.2 Image Picker Not Working

**Symptoms:**
- Camera doesn't open
- Gallery shows but selection fails
- "Permission denied" alert

**Diagnosis:**
```bash
# Check app.json permissions
# iOS: NSCameraUsageDescription, NSPhotoLibraryUsageDescription
# Android: CAMERA, READ_EXTERNAL_STORAGE
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Permissions not in Info.plist | Add to `app.json` > `ios` > `infoPlist` |
| Permission not requested in code | Call `ImagePicker.requestPermissionsAsync()` first |
| Android permission not granted | Check AndroidManifest.xml permissions |
| Expo Go vs built app | Permissions work differently in dev vs production |

**Resolution:**
```typescript
// Request permissions before opening picker
const [permission, requestPermission] = ImagePicker.useMediaLibraryPermissions();

if (!permission.granted) {
  const result = await requestPermission();
  if (!result.granted) {
    Alert.alert('Permission needed', 'Please enable photo access in Settings');
    return;
  }
}

// Open picker
const result = await ImagePicker.launchImageLibraryAsync({
  mediaTypes: ImagePicker.MediaTypeOptions.Images,
  allowsEditing: false,
  quality: 0.8,
});
```

---

### 3.3 Offline Sync Issues

**Symptoms:**
- History not loading when offline
- Cached predictions not displaying
- Sync errors when coming back online

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| AsyncStorage not implemented | Add offline storage for prediction history |
| Stale data displayed | Implement cache invalidation strategy |
| Background sync not working | Use `@react-native-async-storage/async-storage` + WorkManager |

**Resolution:**
```typescript
// Cache predictions for offline
import AsyncStorage from '@react-native-async-storage/async-storage';

async function cachePredictions(predictions: Prediction[]) {
  await AsyncStorage.setItem(
    'cached_predictions',
    JSON.stringify({
      data: predictions,
      timestamp: Date.now()
    })
  );
}

async function getOfflinePredictions() {
  const cached = await AsyncStorage.getItem('cached_predictions');
  if (cached) {
    const { data, timestamp } = JSON.parse(cached);
    // Show cached if last fetch > 5 min ago
    if (Date.now() - timestamp < 5 * 60 * 1000) {
      return data;
    }
  }
  return null;
}
```

---

## 4. Infrastructure Issues

### 4.1 ALB Health Check Failures

**Symptoms:**
- ECS tasks marked unhealthy
- 503 Service Temporarily Available
- Tasks cycling (replace unhealthy)

**Diagnosis:**
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# Test health endpoint directly
curl -f http://internal-xxx.elb.amazonaws.com:8080/health

# Check ECS task health
aws ecs describe-tasks --cluster skin-lesion-prod --tasks {task_id} --query 'tasks[0].healthStatus'
```

**Fixes:**

| Issue | Fix |
|-------|-----|
| Health check path wrong | Ensure `/health` returns 200 without auth |
| Health check timeout | Increase timeout to 10s, interval to 30s |
| App not starting fast enough | Set `startPeriod` to 60s in task definition |
| Security group blocking | ALB must be able to reach ECS on 8080 |

**Resolution:**
```json
// In task definition
{
  "healthCheck": {
    "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 60
  }
}
```

---

### 4.2 DNS/Route53 Issues

**Symptoms:**
- Domain not resolving
- SSL certificate errors
- Redirects to wrong URL

**Diagnosis:**
```bash
# Check DNS resolution
nslookup api.skinlesion.com

# Check certificate
openssl s_client -connect api.skinlesion.com:443 -servername api.skinlesion.com

# Test from different location
curl -I https://api.skinlesion.com/health
```

**Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Route53 record not propagated | Wait 48h for global propagation |
| A record pointing to wrong IP | Update with ALB DNS name |
| Certificate mismatch | Verify certificate covers domain |
| SSL policy too strict | Use `ELBSecurityPolicy-TLS13-1-2-2021-06` |

---

## 5. ML Pipeline Issues

### 5.1 Training Job Failures

**Symptoms:**
- MLflow run failed
- S3 download errors
- GPU memory exhausted

**Diagnosis:**
```bash
# Check MLflow UI for failed runs
# Look at artifacts, logs, error messages

# Check training pool size
aws s3 ls s3://skin-lesion-training-PROD/approved/ --summarize

# Verify S3 permissions
aws s3 sync s3://skin-lesion-training-PROD/approved/ ./test/ --dryrun
```

**Fixes:**

| Issue | Fix |
|-------|-----|
| Insufficient training data | Need 5000+ approved cases before training |
| GPU OOM during training | Reduce batch_size, use gradient accumulation |
| S3 download timeout | Increase timeout in boto3 config, use sync not cp |
| Model overfitting | Increase dropout, add regularization, early stopping |

---

### 5.2 Model Performance Degradation

**Symptoms:**
- Lower accuracy on new cases
- Higher false positive rate
- Predictions less confident

**Diagnosis:**
```python
# Compare current vs new model AUC
import mlflow

# Load production model metrics
prod_model = mlflow.registered_model.get_latest_version("skin-lesion", stage="Production")
prod_metrics = prod_model.metrics  # AUC, accuracy, etc.

# Check new model metrics
new_metrics = latest_run.data.metrics

if new_metrics['eval_auc'] < prod_metrics['eval_auc']:
    print("WARNING: New model worse than production")
```

**Fixes:**

| Cause | Solution |
|-------|----------|
| Training data quality | Review approved cases for incorrect labels |
| Distribution shift | Retrain on more diverse data |
| Overfitting | Reduce epochs, increase dropout, add augmentation |
| Data leakage | Verify train/test split has no patient overlap |

---

## 6. Common Error Messages

| Error Message | Meaning | Fix |
|---------------|---------|-----|
| `ECONNREFUSED` | Service not reachable | Check security groups, verify endpoint |
| `ENOTFOUND` | DNS resolution failed | Check Route53, verify domain |
| `401 Unauthorized` | Auth failed | Check token, refresh if expired |
| `403 Forbidden` | Role not permitted | Verify user role in Cognito |
| `500 Internal Server Error` | App error | Check logs, fix code |
| `503 Service Unavailable` | Model not loaded or overloaded | Check model, scale ECS |

---

## Emergency Contacts

| Issue | Contact |
|-------|---------|
| AWS account compromise | AWS Support + Security |
| Data breach | CTO immediately, then legal |
| Service down > 15 min | Start incident response |
| S3 data deletion | Stop task immediately, check versioning |

---

## Debug Commands Cheat Sheet

```bash
# ECS
aws ecs list-tasks --cluster skin-lesion-prod
aws ecs describe-tasks --cluster skin-lesion-prod --tasks {task_id}
aws logs tail /ecs/skin-lesion-prod --filter-pattern "ERROR"

# RDS
aws rds describe-db-instances --db-instance-identifier skin-lesion-prod
aws rds describe-db-log-files --db-instance-identifier skin-lesion-prod

# S3
aws s3 ls s3://skin-lesion-training-PROD/approved/ --summarize
aws s3 sync s3://bucket ./local --dryrun

# CloudWatch
aws logs filter-log-events --log-group-name /ecs/skin-lesion-prod --filter-pattern "ERROR"
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization

# Cognito
aws cognito-idp describe-user-pool --user-pool-id {pool_id}
aws cognito-idp list-users --user-pool-id {pool_id}
```