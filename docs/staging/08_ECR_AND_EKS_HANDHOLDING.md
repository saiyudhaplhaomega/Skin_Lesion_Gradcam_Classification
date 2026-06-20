# ECR And EKS Handholding Guide

Use this after local Kubernetes works and Terraform basics are understood.

## Goal

Move the same backend container to AWS.

This guide is the first EKS gate. Guides 03 and 05 were deliberately plan-first learning guides; they may have left Terraform configuration in the repo without applying it. Before you deploy to EKS, decide whether you are doing:

```text
plan-only review    -> run fmt, validate, and plan only
cloud execution     -> apply the foundation resources, push the image, create EKS, deploy the pod, then shut EKS down
```

Do not assume ECR or the VPC already exists just because the HCL exists locally. Confirm with AWS commands before skipping steps.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. All `kubectl` and `docker` commands in this guide run from here. Only Terraform commands need a separate `cd infra/terraform` before running.

Terraform commands run from:

```text
infra/terraform
```

**What this means:** `cd infra/terraform` before running `terraform init`, `plan`, `apply`, or `destroy`.

Docker tag and push commands run from any directory after the local image exists.

Replace `YOUR_ACCOUNT_ID` with your real AWS account ID before running AWS commands.

Use the same AWS CLI profile from guides 03-05:

```powershell
$env:AWS_PROFILE = "skin-lesion-learning-dev"
$env:AWS_REGION = "us-east-1"
aws sts get-caller-identity
```

Expected result:

```text
Account prints 526404916929, and Arn is an SSO role for the learning-dev account.
```

**What this confirms:** Terraform and AWS CLI commands are pointed at the disposable learning account, not the management account or a production account.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Local Kubernetes manifests: `infra/k8s/dev/`
- EKS Kubernetes manifests: `infra/k8s/eks-dev/`
- Backend Docker context: `Skin_Lesion_Classification_backend/`
- Create or edit Terraform files under `infra/terraform/` and EKS Kubernetes YAML under the exact `infra/k8s/eks-dev/...` path named by the step.
- Keep `infra/k8s/dev/` local-only. Do not replace its `skin-lesion-backend:local` image with an ECR URI.

## Build Order

1. Confirm the guide 05 foundation is planned or applied intentionally.
2. Add the EKS permission gate to the learning permission set.
3. Create or confirm the ECR repository.
4. Push the backend image.
5. Add the EKS dev cluster configuration.
6. Deploy separate EKS Kubernetes manifests with the ECR image.
7. Check rollout.
8. Shut down EKS when finished.

## Step 0: Confirm The Foundation State

Run from `infra/terraform`:

```powershell
terraform fmt -recursive
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Expected result:

```text
Terraform can read the remote backend and prints a plan for the current dev stack.
```

**What this means:** the Terraform backend, variables, VPC, KMS, S3, Secrets Manager placeholders, and ECR configuration are readable before you add the runtime cluster.

If this fails with an S3 backend `Forbidden` error, refresh the SSO profile from the repo root:

```powershell
aws sso login --profile skin-lesion-learning-dev
$env:AWS_PROFILE = "skin-lesion-learning-dev"
cd infra/terraform
terraform init
terraform validate
```

If you only need local syntax validation and are not ready to touch the remote backend, use the local metadata path:

```powershell
$env:TF_DATA_DIR='.terraform-local'
terraform init -backend=false
terraform validate
Remove-Item Env:\TF_DATA_DIR
```

Expected result:

```text
Success! The configuration is valid.
```

**What this local path does:** checks Terraform syntax and provider schema without reading or writing remote state. It does not prove AWS credentials, remote state access, or cloud apply permissions.

## Step 0.5: Add EKS Permissions To The Learning Permission Set

Guide 05 added KMS, S3, Secrets Manager, and ECR permissions. Guide 08 needs EKS and IAM role permissions too. Without this gate, `terraform plan` or `terraform apply` can fail with `AccessDenied`.

In the Management account, open IAM Identity Center and edit the same permission set used in guides 03-05:

```text
SkinLesionVpcLearning
```

Add a guide-08 statement that permits this dev EKS lesson. Keep the earlier STS, EC2, S3, DynamoDB, KMS, Secrets Manager, and ECR statements from previous guides.

```json
{
  "Sid": "AllowEksLearning",
  "Effect": "Allow",
  "Action": [
    "eks:CreateCluster",
    "eks:DeleteCluster",
    "eks:DescribeCluster",
    "eks:ListClusters",
    "eks:UpdateClusterConfig",
    "eks:TagResource",
    "eks:UntagResource",
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:GetRole",
    "iam:PassRole",
    "iam:TagRole",
    "iam:UntagRole",
    "iam:AttachRolePolicy",
    "iam:DetachRolePolicy",
    "iam:ListAttachedRolePolicies"
  ],
  "Resource": "*"
}
```

**What this permits:** Terraform can create the EKS cluster role, the EKS Auto Mode node role, attach the required AWS-managed policies, pass those roles to EKS, and create or delete the dev cluster.

After saving and provisioning the permission set, refresh your local SSO session:

```powershell
aws sso logout
aws sso login --profile skin-lesion-learning-dev
aws sts get-caller-identity --profile skin-lesion-learning-dev
```

Expected result:

```text
The command prints the learning-dev account and an AWSReservedSSO role ARN.
```

Why: IAM Identity Center sessions do not automatically pick up permission changes that were made after the session started.

## Cross-Reference: ECR Was Already Created In Guide 05

If you completed `docs/staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md` and ran `terraform apply`, the ECR repository named `skin-lesion-backend-dev` already exists in account `526404916929`, region `us-east-1`. Guide 05 Step 6 created it via `aws_ecr_repository.backend`.

**Before starting Step 1 below, run this to check whether the ECR repo already exists:**

```powershell
aws ecr describe-repositories --repository-names skin-lesion-backend-dev --region us-east-1 --profile skin-lesion-learning-dev
```

If the command prints a JSON block with `"repositoryName": "skin-lesion-backend-dev"`, the repo already exists. Skip Step 1 and go directly to Step 2 (Push Image).

If the command returns `RepositoryNotFoundException`, follow Step 1 below to create it. (This happens when you completed guide 05 as plan-only without applying, or when you deliberately skipped guide 05 and started at guide 08.)

This guide assumes the ECR repository name is `skin-lesion-backend-dev` and the region is `us-east-1` — both match what guide 05 created. If you are following guide 08 standalone (without guide 05), you can still use these values, but you should later add them to guide 05's `variables.tf` and `env/dev.tfvars` to keep both guides consistent.

## Step 1: Create ECR With Terraform At This Gate

Do not add EKS first. Add ECR first because it is simpler.

This step is only needed if the cross-reference check above returned `RepositoryNotFoundException`. If guide 05 already created the repo, skip this step entirely.

Terraform resource shape:

```hcl
resource "aws_ecr_repository" "backend" {
  name                 = "skin-lesion-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
```

**What this HCL does:** creates a private container image repository in AWS Elastic Container Registry. With `environment = "dev"`, the repository name becomes `skin-lesion-backend-dev`. Docker image URIs take the form `<account>.dkr.ecr.<region>.amazonaws.com/skin-lesion-backend-dev:<tag>`. `image_tag_mutability = "MUTABLE"` allows pushing a new image with the same tag (like `local` or `latest`). `scan_on_push = true` triggers an automated CVE vulnerability scan every time an image is pushed - results appear in the ECR console.

Checks:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** `terraform fmt` formats the HCL file. `terraform validate` checks syntax and resource references after Terraform is initialized. `terraform plan` shows what will be created. If you are only doing Step 1, the plan should show the ECR repository. If you are validating this guide after completing Step 3, the plan can also show the EKS cluster, EKS IAM roles, and the second private app subnet.

## Step 2: Push Image

After ECR exists, authenticate Docker:

```powershell
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

**What this does:** `aws ecr get-login-password` fetches a short-lived authentication token from AWS. The pipe (`|`) passes that token to `docker login`, which configures Docker to use it for the ECR registry domain. After this, `docker push` and `docker pull` commands for that registry domain are authenticated.

Tag:

```powershell
docker tag skin-lesion-backend:local YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/skin-lesion-backend-dev:local
```

**What this does:** adds a second tag to the locally built image. The new tag includes the full ECR registry URL and repository name. Docker push uses the tag to know which registry and repository to push to - without this, push would not know the destination.

Push:

```powershell
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/skin-lesion-backend-dev:local
```

**What this does:** uploads the image layers to ECR. After this completes, the image is stored in AWS and EKS can pull it from there.

## Step 3: Create EKS Cluster With Terraform

Add the EKS cluster to `infra/terraform/modules/eks/main.tf`:

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID that contains the cluster subnets"
  type        = string
}

variable "subnet_ids" {
  description = "Private application subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "environment" {
  description = "Environment label, such as dev, staging, or prod"
  type        = string
}

variable "project" {
  description = "Project tag value"
  type        = string
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role" "eks_cluster" {
  name = "skin-lesion-eks-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_compute_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_block_storage_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_load_balancing_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_networking_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

resource "aws_iam_role" "eks_node" {
  name = "skin-lesion-eks-node-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_minimal" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_pull_only" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.31"

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.eks_node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_compute_policy,
    aws_iam_role_policy_attachment.eks_block_storage_policy,
    aws_iam_role_policy_attachment.eks_load_balancing_policy,
    aws_iam_role_policy_attachment.eks_networking_policy,
    aws_iam_role_policy_attachment.eks_worker_node_minimal,
    aws_iam_role_policy_attachment.eks_ecr_pull_only,
  ]

  tags = local.common_tags
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "API endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "kubeconfig_certificate_authority_data" {
  description = "Certificate authority data for kubeconfig generation"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}
```

**What this HCL module does:**

- `variable` blocks - the module inputs: cluster name, VPC ID, private app subnet IDs, environment, and project tag.
- `aws_iam_role "eks_cluster"` - creates an IAM role that the EKS control plane assumes to manage cluster resources. The trust policy allows the EKS service to assume and tag the session.
- `aws_iam_role_policy_attachment` blocks for the cluster role - attach the AWS-managed EKS Auto Mode policies for cluster, compute, block storage, load balancing, and networking responsibilities.
- `aws_eks_cluster "main"` - creates the EKS cluster itself. `version = "1.31"` pins the Kubernetes version. `vpc_config` places the cluster into the VPC subnets from the networking guide. `endpoint_public_access = true` allows `kubectl` access from your laptop (set to `false` for production clusters accessible only from within the VPC).
- `compute_config` with `enabled = true` turns on EKS Auto Mode - AWS automatically provisions, scales, and upgrades EC2 nodes. `node_pools = ["general-purpose"]` uses the standard pool. You do not manage node groups or launch templates manually.
- `kubernetes_network_config.elastic_load_balancing.enabled = true` - lets EKS Auto Mode provision AWS Load Balancers for Kubernetes Services of type `LoadBalancer`.
- `storage_config.block_storage.enabled = true` - lets EKS Auto Mode provision EBS volumes for Kubernetes PersistentVolumeClaims.
- `depends_on` - ensures the IAM policy attachments finish before the cluster is created. EKS needs the policies attached to the roles before it can use the roles.
- `aws_iam_role "eks_node"` - a separate IAM role for the EC2 nodes that Auto Mode provisions. Nodes assume this role (from the EC2 service, not the EKS service).
- `aws_iam_role_policy_attachment "eks_worker_node_minimal"` - attaches `AmazonEKSWorkerNodeMinimalPolicy` so Auto Mode nodes can communicate with the EKS control plane.
- `aws_iam_role_policy_attachment "eks_ecr_pull_only"` - attaches `AmazonEC2ContainerRegistryPullOnly` so nodes can pull images from ECR without additional credentials.
- `output` blocks - expose the cluster name, API endpoint, and certificate authority data. These values are used by `aws eks update-kubeconfig` to generate a local kubeconfig file.

Add to root `main.tf`:

```hcl
module "eks" {
  source       = "./modules/eks"
  cluster_name = "${var.project_name}-${var.environment}"
  vpc_id       = aws_vpc.main.id
  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id,
  ]
  environment  = var.environment
  project      = var.project_name
}
```

**What this block does:** calls the `eks` module from root `main.tf`, passing in the existing flat VPC resources used by this repo. Earlier versions of this guide showed `module.vpc.vpc_id` and `module.vpc.private_app_subnet_ids`; this workspace does not currently have a VPC module, so guide 08 uses `aws_vpc.main.id`, `aws_subnet.private_app_a.id`, and `aws_subnet.private_app_b.id`.

Also make sure `infra/terraform/main.tf` has two private app subnets in different Availability Zones. EKS requires subnets across multiple Availability Zones; a single `us-east-1a` subnet can validate locally but fail when AWS creates the cluster.

```hcl
resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name                              = "skin-lesion-learning-dev-private-app-b"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
```

**What this subnet does:** gives EKS a second app subnet in a second Availability Zone. The Kubernetes tag marks the subnet as eligible for internal load balancers later. This guide still uses a `ClusterIP` Service and `kubectl port-forward`; public ingress waits for guide 09.

Update `infra/terraform/outputs.tf`:

```hcl
output "eks_cluster_name" {
  description = "Name of the EKS cluster created in guide 08"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API endpoint of the EKS cluster created in guide 08"
  value       = module.eks.cluster_endpoint
}
```

**What these outputs do:** print the cluster name and API endpoint after apply. The cluster name is the value used by `aws eks update-kubeconfig`.

Validate locally from `infra/terraform`:

```powershell
terraform fmt -recursive
terraform validate
```

If `terraform validate` says the module is not installed, run:

```powershell
terraform init
terraform validate
```

If `terraform init` fails with an S3 backend access error such as `Forbidden`, your AWS identity cannot read the remote Terraform state yet. Do not edit secrets into Terraform files. Instead, either log in with the expected AWS profile or run a local schema-only init in a clean data directory:

```powershell
$env:TF_DATA_DIR='.terraform-local'
terraform init -backend=false
terraform validate
Remove-Item Env:\TF_DATA_DIR
```

Expected result:

```text
Success! The configuration is valid.
```

**What this workaround does:** uses local Terraform metadata for validation and avoids touching the S3 backend. The generated `infra/terraform/.terraform-local/` directory is ignored by Git.

**Cost warning - EKS Auto Mode charges per vCPU hour. Destroy when not in use:**

```powershell
# Create
cd infra/terraform
terraform apply -var-file="env/dev.tfvars"

# Verify cluster is up
aws eks update-kubeconfig --name skin-lesion-dev --region us-east-1 --profile skin-lesion-learning-dev
kubectl get nodes

# DESTROY when done for the day (saves ~$0.10/hour per node)
terraform destroy -target=module.eks -var-file="env/dev.tfvars"
```

**What this command block does:**

- `terraform apply -var-file="env/dev.tfvars"` - creates any unapplied dev foundation resources plus the EKS cluster. Read the plan before typing `yes`. EKS cluster creation takes 10-15 minutes.
- `aws eks update-kubeconfig` - downloads the cluster's kubeconfig and merges it into `~/.kube/config` so `kubectl` commands target this cluster.
- `kubectl get nodes` - lists EC2 nodes that EKS Auto Mode provisioned. Should show at least one node in `Ready` state.
- `terraform destroy -target=module.eks -var-file="env/dev.tfvars"` - destroys only the EKS cluster and its IAM roles, leaving other infrastructure (VPC, S3, ECR) intact. Read the destroy plan before typing `yes`. Run this at the end of each session to stop EKS compute charges.

## Why EKS Auto Mode

EKS Auto Mode manages node groups, scaling, and upgrades. You still learn Kubernetes objects, rollout, logs, health checks, IAM, networking, and service exposure - but without manually provisioning EC2 launch templates.

## Step 4: Deploy Backend To EKS

After cluster is up, use the EKS manifest path:

```text
infra/k8s/eks-dev/deployment.yaml
```

Create or update the EKS manifest image field with the ECR image:

```yaml
image: 526404916929.dkr.ecr.us-east-1.amazonaws.com/skin-lesion-backend-dev:local
imagePullPolicy: Always
```

**What this field change does:** uses the full ECR image URI for EKS and tells Kubernetes to pull from ECR. Do not make this change in `infra/k8s/dev/deployment.yaml`; that file stays local-only with `skin-lesion-backend:local` and `imagePullPolicy: Never`.

Apply:

```powershell
kubectl apply -f infra/k8s/eks-dev/
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-dev
```

**What these commands do:** `kubectl apply -f infra/k8s/eks-dev/` applies the EKS-specific YAML files to the `skin-lesion-dev` namespace in EKS. `kubectl rollout status` blocks until all replicas are up and the readiness probe passes, then prints `successfully rolled out`.

## Stop Point

Do not add production deployment automation until manual EKS deploy works.

Expected result:

```text
ECR image pushed, EKS cluster created, backend deployment running on EKS, /health reachable via kubectl port-forward.
```

**What this result means:** all four stages completed - the Docker image is in ECR, the cluster is running, the deployment is healthy, and you can reach the app through port-forward. If any stage fails, check `kubectl describe pod` or `kubectl logs` for errors.

## Check

```powershell
docker images skin-lesion-backend
kubectl get pods -n skin-lesion-dev
kubectl port-forward svc/skin-lesion-backend 8000:8080 -n skin-lesion-dev
# In another terminal:
curl http://localhost:8000/health
```

**What these commands do:**

- `docker images skin-lesion-backend` - confirms the local backend image is present in your local Docker image list. If you also want to check the ECR tag, run `docker images 526404916929.dkr.ecr.us-east-1.amazonaws.com/skin-lesion-backend-dev`.
- `kubectl get pods -n skin-lesion-dev` - lists pods running in the namespace on EKS. The pod should show `Running` with `1/1` containers ready.
- `kubectl port-forward svc/skin-lesion-backend 8000:8080` - opens a tunnel from `localhost:8000` to the EKS Service's port 8080, letting you reach the pod without a public load balancer.
- `curl http://localhost:8000/health` - tests the health endpoint through the tunnel. Returns `{"status":"ok"}` if the pod is healthy.

Expected: ECR image tagged, EKS pod running, /health returns {"status":"ok"}.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports the current state of dev cloud resources. `make cloud-pause ENV=dev` scales pods to zero to reduce compute costs. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment completely - important for EKS because it charges per vCPU hour even when idle.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms everything is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
