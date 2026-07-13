# Runtime Alternatives: EKS And ECS

Use this before deciding whether old ECS Terraform ideas should be rebuilt.

## Main Decision

The main runtime path for this project is:

```text
Docker -> local Kubernetes -> EKS
```

**What this learning path means:**

- `Docker` - build and run the backend container locally first. Understand the image, layers, and environment variables before adding orchestration.
- `local Kubernetes` - run the container inside a local Kubernetes cluster (e.g., kind or minikube) to learn pods, services, probes, and rollouts without AWS costs.
- `EKS` - once local Kubernetes is understood, move the same manifests to AWS Elastic Kubernetes Service. The concepts transfer directly.

ECS is an alternative/reference path, not the default build path.

## What The Old ECS Modules Represented

The old ECS-related Terraform modules covered:

```text
ecs
ecs-service
ecs-task-role
alb
```

**What these modules covered:**

- `ecs` - the Fargate cluster that hosted containers without managing EC2 instances.
- `ecs-service` - the ECS service definition connecting the task definition to the cluster and load balancer.
- `ecs-task-role` - IAM role attached to the running task, giving it permissions to call S3, Cognito, and other AWS services.
- `alb` - the Application Load Balancer that routed external traffic to the ECS service.

They taught these ideas:

```text
Fargate cluster
private app subnet tasks
ALB-to-service traffic
task execution role
application task role
least-privilege S3 access
limited Cognito access
CloudWatch container insights
```

**What these concepts mean:**

- `Fargate cluster` - ECS Fargate runs containers without you provisioning or managing EC2 instances.
- `private app subnet tasks` - tasks ran in private subnets, not directly reachable from the internet.
- `ALB-to-service traffic` - the ALB in the public subnet forwarded incoming requests to the private ECS tasks.
- `task execution role` - the IAM role that lets ECS pull the container image from ECR and read Secrets Manager values.
- `application task role` - the IAM role the running container uses at runtime to call S3, Cognito, etc.
- `least-privilege S3 access` - the task role was scoped to specific S3 bucket actions only, not full S3 access.
- `limited Cognito access` - the task role could call specific Cognito actions needed for token validation, nothing else.
- `CloudWatch container insights` - ECS sent container-level CPU, memory, and network metrics to CloudWatch automatically.

## How To Translate To EKS

If staying with EKS, learn the same concepts through Kubernetes:

```text
ECS cluster -> EKS cluster
ECS service -> Kubernetes Deployment and Service
ECS task role -> IRSA or EKS Pod Identity
ALB module -> AWS Load Balancer Controller and Ingress
task desired count -> Deployment replicas
container insights -> EKS/CloudWatch/Prometheus metrics
```

**What these translations mean:**

- `ECS cluster -> EKS cluster` - both are the control plane that schedules containers. EKS uses the Kubernetes API; ECS uses its own API.
- `ECS service -> Kubernetes Deployment and Service` - in Kubernetes, a Deployment manages the pod replicas and a Service exposes them to traffic. ECS service handled both in one concept.
- `ECS task role -> IRSA or EKS Pod Identity` - IRSA (IAM Roles for Service Accounts) or EKS Pod Identity attaches an IAM role to a Kubernetes service account so pods can call AWS services with the right permissions.
- `ALB module -> AWS Load Balancer Controller and Ingress` - the AWS Load Balancer Controller watches Kubernetes Ingress resources and provisions ALBs automatically in AWS.
- `task desired count -> Deployment replicas` - both control how many container instances run. In Kubernetes, `spec.replicas` sets the baseline count; HPA can scale it automatically.
- `container insights -> EKS/CloudWatch/Prometheus metrics` - EKS supports both CloudWatch Container Insights and Prometheus-based monitoring through the metrics server or an operator.

## When To Use ECS Instead

Use ECS only when the project has all of these requirements:

```text
simpler AWS-native container runtime
less Kubernetes learning
Fargate-first service deployment
ALB target group deployment patterns
```

**What these ECS requirements mean:**

- `simpler AWS-native container runtime` - ECS has fewer moving parts than EKS. No etcd, no node groups, no kubeconfig. If you want to stay in the AWS console without learning kubectl, ECS is the simpler choice.
- `less Kubernetes learning` - ECS is appropriate when Kubernetes learning is not part of the project goal. For this curriculum, Kubernetes learning IS the goal, so EKS is used.
- `Fargate-first service deployment` - ECS Fargate removes the need to manage EC2 worker nodes. EKS also supports Fargate profiles, but ECS Fargate is more native to that workflow.
- `ALB target group deployment patterns` - ECS integrates directly with ALB target groups. The EKS path uses the AWS Load Balancer Controller and Ingress instead, which is more flexible but requires more setup.

Do not build both EKS and ECS for the same MVP.

## Stop Point

Keep ECS as reference unless a later guide replaces the main EKS path with an ECS path.

## Auto-Heal Boundary

The former Lambda files were ECS/ALB-specific:

```text
infra/terraform/lambda/auto_heal.py
infra/terraform/lambda/auto_rollback.py
```

**What these files were:** Lambda functions that watched ECS service health and ALB target-group health checks, then triggered ECS service redeployment or target deregistration when unhealthy. They were ECS/ALB-specific and cannot be reused for EKS without rewriting them to call Kubernetes APIs instead.

They were deleted after this guide preserved their behavior. They do not work for EKS because they call ECS and ALB target-group APIs.

Use:

```text
EKS main path: docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md
ECS alternate path: docs/production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md
```

**What these guide paths mean:**

- `10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md` is the active path for this project. It covers Kubernetes-native auto-healing with liveness probes, rollout undo, and HPA.
- `09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md` documents what the old Lambda files did, preserved as a reference for the ECS path. Use it only if you switch to an ECS runtime.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` checks the current dev environment state.
- `make cloud-pause ENV=dev` pauses pausable resources.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the flag prevents accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms it is healthy before you begin.

If this guide was local-only, no cloud shutdown is needed.
