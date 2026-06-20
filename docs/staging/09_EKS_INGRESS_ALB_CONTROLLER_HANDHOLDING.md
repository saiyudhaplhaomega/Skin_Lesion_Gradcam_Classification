# EKS Ingress And AWS Load Balancer Controller Handholding Guide

Use this after the EKS dev deployment from `docs/staging/08_ECR_AND_EKS_HANDHOLDING.md` works with a Kubernetes `Service`.

This guide connects the old ALB module idea to the EKS path without changing the runtime stack. The old Terraform `alb` module represents the ECS/ALB path. The EKS main path exposes Kubernetes Services with Kubernetes `Ingress`.

Guide 08 created the dev EKS cluster with EKS Auto Mode enabled. That means the first Guide 09 implementation uses the managed EKS Auto Mode ALB controller behavior:

```text
EKS Deployment -> Kubernetes Service -> IngressClass -> Ingress -> EKS Auto Mode -> ALB
```

Do not install Helm charts or recreate an ECS-style Terraform ALB module for the dev gate.

## Goal

Expose the backend through an AWS Application Load Balancer without switching away from EKS.

```text
EKS Deployment -> Kubernetes Service -> Ingress -> managed ALB controller behavior -> ALB
```

Do not recreate or wire the old `infra/terraform/modules/alb` module into the EKS main path.

## Source Check

This guide follows the current AWS EKS documentation:

- EKS Auto Mode can create and configure ALBs from Kubernetes `Ingress` objects.
- EKS Auto Mode uses an `IngressClass` with controller `eks.amazonaws.com/alb`.
- EKS Auto Mode requires subnet tags so it can distinguish public load-balancer subnets from private internal-load-balancer subnets.

References:

- https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html
- https://docs.aws.amazon.com/eks/latest/userguide/auto-elb-example.html
- https://docs.aws.amazon.com/eks/latest/userguide/tag-subnets-auto.html
- https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root so relative paths in `kubectl` and `terraform` commands resolve correctly.

Kubernetes manifests for this dev EKS gate belong under:

```text
infra/k8s/eks-dev
```

**What this directory is:** the EKS dev manifest folder created by guide 08. It is separate from `infra/k8s/dev/`, which stays local-only for Docker Desktop Kubernetes.

Terraform network work belongs under:

```text
infra/terraform
```

**What this means:** create or edit public load-balancer subnet tags, the second public subnet, the internet gateway, and the public route table here. Run `cd infra/terraform` before any `terraform` command.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- EKS dev Kubernetes manifests: `infra/k8s/eks-dev/`
- Local Kubernetes manifests, do not edit for EKS: `infra/k8s/dev/`
- Terraform files: `infra/terraform/`
- Create or edit `ingressclass.yaml` and `ingress.yaml` under `infra/k8s/eks-dev/`.
- Create or edit public ALB networking resources in `infra/terraform/main.tf`.
- Run `kubectl` commands from the main workspace and Terraform commands from `infra/terraform/`.

## Parameters You Must Set First

```text
AWS_REGION=us-east-1
EKS_CLUSTER_NAME=skin-lesion-dev
NAMESPACE=skin-lesion-dev
SERVICE_NAME=skin-lesion-backend
INGRESS_NAME=skin-lesion-backend
HEALTH_PATH=/health
ALB_SCHEME=internet-facing for the dev public ALB learning gate
TLS_CERTIFICATE_ARN=<optional ACM certificate ARN>
```

**What these parameters mean:**

- `EKS_CLUSTER_NAME=skin-lesion-dev` - the name of the EKS cluster created by guide 08. Used in `aws eks update-kubeconfig` to fetch the right kubeconfig.
- `NAMESPACE=skin-lesion-dev` - the Kubernetes namespace where the Deployment, Service, and Ingress live. All `kubectl -n` flags use this value.
- `ALB_SCHEME=internet-facing` - makes the dev ALB publicly reachable for the learning gate. Use `internal` only when the guide explicitly teaches an internal-only staging or production path.
- `TLS_CERTIFICATE_ARN` - optional. If you have an ACM certificate for a custom domain, paste its ARN here and add the TLS annotations to the Ingress. Without it, the ALB serves plain HTTP only.

## Step 1: Confirm Guide 08 Is Actually Working

Do not add Ingress until the EKS dev Service works through port-forward.

Check the cluster first:

```powershell
aws eks update-kubeconfig --name skin-lesion-dev --region us-east-1 --profile skin-lesion-learning-dev
kubectl get nodes
kubectl get namespace skin-lesion-dev
kubectl get service skin-lesion-backend -n skin-lesion-dev
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-dev
```

**What these commands do:** `aws eks update-kubeconfig` points `kubectl` at the Guide 08 EKS dev cluster. `kubectl get nodes` confirms that EKS Auto Mode has provisioned at least one node and it is in `Ready` state. `kubectl get namespace`, `kubectl get service`, and `kubectl rollout status` confirm that the Guide 08 workload exists before you expose it through an ALB.

Expected result:

```text
EKS nodes are ready.
The skin-lesion-dev namespace exists.
The skin-lesion-backend Service exists.
The skin-lesion-backend Deployment is successfully rolled out.
```

**What this means:** the Guide 08 cluster, namespace, Service, and Deployment are healthy. If nodes are `NotReady`, the cluster is still starting up - wait a minute and retry.

Why: Ingress has nothing to control until the cluster and service exist.

## Step 2: Add Public ALB Networking To Terraform

Guide 03 created a beginner VPC with one public subnet. Guide 08 added a second private app subnet for EKS. An internet-facing ALB needs public load-balancer subnets and public routing.

Edit:

```text
infra/terraform/main.tf
```

Add the EKS Auto Mode public subnet tag to `aws_subnet.public_a`:

```hcl
tags = {
  Name                     = "skin-lesion-learning-dev-public-a"
  "kubernetes.io/role/elb" = "1"
}
```

Add a second public subnet:

```hcl
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "skin-lesion-learning-dev-public-b"
    "kubernetes.io/role/elb" = "1"
  }
}
```

Add an internet gateway and public route table:

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "skin-lesion-learning-dev-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "skin-lesion-learning-dev-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
```

**What this Terraform does:**

- `kubernetes.io/role/elb = "1"` marks public subnets for internet-facing load balancers.
- `public_b` gives the ALB a second public Availability Zone.
- `aws_internet_gateway.main` gives the VPC a path to the public internet.
- `aws_route_table.public` sends outbound `0.0.0.0/0` traffic from the public subnets to the internet gateway.
- route table associations attach the public route table to both public subnets.

Why: an internet-facing ALB is a public network resource. The backend pods still live behind a Kubernetes Service; the ALB is the public entry point.

Check:

```powershell
cd infra/terraform
terraform fmt -recursive
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

**What these commands do:** `terraform fmt -recursive` normalizes indentation. `terraform validate` checks the new network resources for syntax errors. `terraform plan -var-file="env/dev.tfvars"` previews the second public subnet, internet gateway, route table, associations, and any unapplied Guide 08 resources.

Expected result:

```text
Terraform validates.
The plan does not include aws_lb, aws_lb_target_group, ECS, or ECS service resources.
```

**What this means:** Terraform prepares the VPC subnets that EKS Auto Mode needs, but Kubernetes Ingress still owns the ALB lifecycle.

## Step 3: Add The EKS Auto Mode IngressClass

Create:

```text
infra/k8s/eks-dev/ingressclass.yaml
```

Paste:

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  labels:
    app.kubernetes.io/name: skin-lesion-alb
    environment: dev
    platform: eks
spec:
  controller: eks.amazonaws.com/alb
```

**What this YAML does:** creates a Kubernetes `IngressClass` named `alb`. `controller: eks.amazonaws.com/alb` tells EKS Auto Mode to handle Ingress resources that set `ingressClassName: alb`.

Check from the repo root:

```powershell
kubectl apply --dry-run=client -f infra/k8s/eks-dev/ingressclass.yaml
```

Expected result:

```text
ingressclass.networking.k8s.io/alb configured (dry run)
```

## Step 4: Add Backend Ingress

Create:

```text
infra/k8s/eks-dev/ingress.yaml
```

Paste:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: skin-lesion-backend
  namespace: skin-lesion-dev
  labels:
    app: skin-lesion-backend
    environment: dev
    platform: eks
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: skin-lesion-backend
                port:
                  number: 8080
```

**What this YAML does:**

- `kind: Ingress` - a Kubernetes object that defines routing rules from an external load balancer to Services inside the cluster.
- `ingressClassName: alb` - tells EKS Auto Mode to use the `alb` IngressClass.
- `alb.ingress.kubernetes.io/scheme: internet-facing` - creates a public ALB. Traffic flows: internet -> ALB -> Kubernetes Service -> pod.
- `alb.ingress.kubernetes.io/target-type: ip` - routes traffic directly to pod IPs (IP mode), not to node IPs. Required for EKS and works better with fast pod turnover.
- `alb.ingress.kubernetes.io/healthcheck-path: /health` - tells the ALB to use `/health` for its health checks. The ALB marks a target healthy only if this endpoint returns 2xx.
- `spec.rules` - maps all paths under `/` to the `skin-lesion-backend` Service on port 8080.

If using TLS, add the ACM certificate annotation:

File path:

```text
infra/k8s/eks-dev/ingress.yaml
```

```yaml
alb.ingress.kubernetes.io/certificate-arn: <ACM_CERTIFICATE_ARN>
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
```

**What these annotations do:** `certificate-arn` attaches an ACM certificate to the ALB HTTPS listener - the ALB terminates TLS and forwards plain HTTP to the pod. `listen-ports` opens both port 80 (HTTP) and 443 (HTTPS) on the ALB.

Check:

```powershell
kubectl apply --dry-run=client -f infra/k8s/eks-dev/ingress.yaml
kubectl apply --dry-run=client -f infra/k8s/eks-dev/
```

**What these commands do:** dry-run validates the Ingress YAML and then validates all EKS dev manifests together without creating cloud resources.

Expected result:

```text
The Ingress dry-run succeeds.
The full infra/k8s/eks-dev dry-run succeeds.
```

**What this means:** the Kubernetes files are valid. Applying them to a live EKS cluster is a separate cloud execution step.

## Step 5: Apply And Verify The ALB Only During Cloud Execution

Run this only after Guide 08 is applied, the image is pushed to ECR, the EKS pod is healthy, and you intentionally want AWS to create a public ALB.

Apply from the repo root:

```powershell
kubectl apply -f infra/k8s/eks-dev/ingressclass.yaml
kubectl apply -f infra/k8s/eks-dev/ingress.yaml
kubectl get ingress skin-lesion-backend -n skin-lesion-dev
kubectl describe ingress skin-lesion-backend -n skin-lesion-dev
```

**What these commands do:** creates the IngressClass and Ingress. EKS Auto Mode observes the Ingress and creates the ALB. `kubectl get ingress` and `describe ingress` show provisioning status and events.

Run:

```powershell
kubectl get ingress skin-lesion-backend -n skin-lesion-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**What this does:** prints only the ALB hostname from the Ingress status. Once the ALB is provisioned, this value looks like `k8s-skinlesion-....us-east-1.elb.amazonaws.com`.

Copy the printed ALB hostname.

Check:

```powershell
curl http://<alb-hostname>/health
```

**What this does:** sends a request through the real ALB (not port-forward) to the pod's health endpoint. If this returns `{"status":"ok"}`, traffic is flowing end-to-end from the internet through the load balancer to the backend container.

Expected result:

```text
The backend /health endpoint returns successfully through the ALB.
```

**What this means:** the full path works - ALB listener -> target group -> pod health check passing -> FastAPI responding.

## ECS Alternative Rule

Recreate an ALB module only if a later guide switches the runtime path from EKS to ECS.

```text
EKS main path: EKS Auto Mode managed ALB behavior + Ingress
ECS alternate path: Terraform ALB module + ECS service target group
```

**What this means:** the project uses EKS as its main runtime. On the current Guide 08 EKS Auto Mode cluster, EKS handles ALB lifecycle from Kubernetes Ingress resources. The old ECS-style Terraform ALB module only applies if the team ever switches to ECS - do not mix the two approaches for the same service.

Do not mix both for the same service in the same environment.

## Stop Point

Do not add WAF, canary, blue-green, or automatic rollback until:

```text
Ingress exists
ALB is provisioned by the controller
/health works through the ALB
manual kubectl rollout undo works
```

**What this gate means:** each condition must be verified before adding the next layer of complexity. WAF requires a working ALB. Canary and blue-green deployments require working rollbacks. `kubectl rollout undo deployment/skin-lesion-backend` reverts to the previous image version - test this manually at least once before automating it.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports the current state of dev cloud resources. `make cloud-pause ENV=dev` scales pods to zero to stop compute charges. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment - the ALB is also destroyed when the Ingress and cluster are removed, because Kubernetes/EKS Auto Mode owns that ALB lifecycle.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms the environment is healthy before continuing to the next guide.

If this guide was local-only, no cloud shutdown is needed.
