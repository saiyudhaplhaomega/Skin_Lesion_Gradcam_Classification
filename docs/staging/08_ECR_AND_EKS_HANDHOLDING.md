# ECR And EKS Handholding Guide

Use this after local Kubernetes works and Terraform basics are understood.

## Goal

Move the same backend container to AWS.

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

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Kubernetes manifests: `infra/k8s/`
- Backend Docker context: `Skin_Lesion_Classification_backend/`
- Create or edit Terraform files under `infra/terraform/` and Kubernetes YAML under the exact `infra/k8s/...` path named by the step.

## Build Order

1. ECR repository.
2. Push backend image.
3. EKS dev cluster.
4. Deploy the same Kubernetes manifests with the ECR image.
5. Check rollout.

## Step 1: Create ECR With Terraform At This Gate

Do not add EKS first. Add ECR first because it is simpler.

Terraform resource shape:

```hcl
resource "aws_ecr_repository" "backend" {
  name                 = "skin-lesion-backend-dev"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
```

**What this HCL does:** creates a private container image repository in AWS Elastic Container Registry. `name = "skin-lesion-backend-dev"` is the repository name - Docker image URIs take the form `<account>.dkr.ecr.<region>.amazonaws.com/skin-lesion-backend-dev:<tag>`. `image_tag_mutability = "MUTABLE"` allows pushing a new image with the same tag (like `local` or `latest`). `scan_on_push = true` triggers an automated CVE vulnerability scan every time an image is pushed - results appear in the ECR console.

Checks:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** `terraform fmt` formats the HCL file. `terraform validate` checks syntax and resource references without connecting to AWS. `terraform plan` shows what will be created - at this step, the plan should include the ECR repository and nothing else new.

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
variable "cluster_name"     {}
variable "vpc_id"            {}
variable "subnet_ids"        { type = list(string) }
variable "environment"       {}

# IAM role for the EKS cluster control plane
resource "aws_iam_role" "eks_cluster" {
  name = "skin-lesion-eks-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS cluster with Auto Mode enabled (manages nodes automatically)
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true   # Set false for production
  }

  # Auto Mode - EKS manages node groups, scaling, and upgrades
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

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = { Environment = var.environment }
}

# IAM role for EKS Auto Mode nodes
resource "aws_iam_role" "eks_node" {
  name = "skin-lesion-eks-node-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

output "cluster_name"     { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "kubeconfig_cert"  { value = aws_eks_cluster.main.certificate_authority[0].data }
```

**What this HCL module does:**

- `variable` blocks - the four inputs this module accepts: `cluster_name`, `vpc_id`, `subnet_ids` (list), and `environment`. The root `main.tf` passes these in.
- `aws_iam_role "eks_cluster"` - creates an IAM role that the EKS control plane assumes to manage cluster resources. The `assume_role_policy` allows only the `eks.amazonaws.com` service to use this role.
- `aws_iam_role_policy_attachment "eks_cluster_policy"` - attaches the AWS-managed `AmazonEKSClusterPolicy` to the cluster role. This policy gives EKS the permissions it needs to manage EC2 networking, load balancers, and node lifecycle.
- `aws_eks_cluster "main"` - creates the EKS cluster itself. `version = "1.31"` pins the Kubernetes version. `vpc_config` places the cluster into the VPC subnets from the networking guide. `endpoint_public_access = true` allows `kubectl` access from your laptop (set to `false` for production clusters accessible only from within the VPC).
- `compute_config` with `enabled = true` turns on EKS Auto Mode - AWS automatically provisions, scales, and upgrades EC2 nodes. `node_pools = ["general-purpose"]` uses the standard pool. You do not manage node groups or launch templates manually.
- `kubernetes_network_config.elastic_load_balancing.enabled = true` - lets EKS Auto Mode provision AWS Load Balancers for Kubernetes Services of type `LoadBalancer`.
- `storage_config.block_storage.enabled = true` - lets EKS Auto Mode provision EBS volumes for Kubernetes PersistentVolumeClaims.
- `depends_on` - ensures the IAM policy attachment finishes before the cluster is created. EKS needs the policy attached to the role before it can use the role.
- `aws_iam_role "eks_node"` - a separate IAM role for the EC2 nodes that Auto Mode provisions. Nodes assume this role (from the EC2 service, not the EKS service).
- `aws_iam_role_policy_attachment "eks_worker_node"` - attaches `AmazonEKSWorkerNodePolicy` so nodes can communicate with the EKS control plane.
- `aws_iam_role_policy_attachment "eks_ecr_readonly"` - attaches `AmazonEC2ContainerRegistryReadOnly` so nodes can pull images from ECR without additional credentials.
- `output` blocks - expose the cluster name, API endpoint, and certificate authority data. These values are used by `aws eks update-kubeconfig` to generate a local kubeconfig file.

Add to root `main.tf`:

```hcl
module "eks" {
  source       = "./modules/eks"
  cluster_name = "skin-lesion-${var.environment}"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_app_subnet_ids
  environment  = var.environment
}
```

**What this block does:** calls the `eks` module from root `main.tf`, passing in values from other modules. `module.vpc.vpc_id` and `module.vpc.private_app_subnet_ids` reference outputs from the VPC module - the EKS cluster is placed inside the same VPC as the app subnets.

**Cost warning - EKS Auto Mode charges per vCPU hour. Destroy when not in use:**

```powershell
# Create
cd infra/terraform
terraform apply -var="environment=dev" -auto-approve

# Verify cluster is up
aws eks update-kubeconfig --name skin-lesion-dev --region us-east-1
kubectl get nodes

# DESTROY when done for the day (saves ~$0.10/hour per node)
terraform destroy -var="environment=dev" -target=module.eks -auto-approve
```

**What this command block does:**

- `terraform apply -var="environment=dev" -auto-approve` - creates all resources including the EKS cluster. `-auto-approve` skips the confirmation prompt. EKS cluster creation takes 10-15 minutes.
- `aws eks update-kubeconfig` - downloads the cluster's kubeconfig and merges it into `~/.kube/config` so `kubectl` commands target this cluster.
- `kubectl get nodes` - lists EC2 nodes that EKS Auto Mode provisioned. Should show at least one node in `Ready` state.
- `terraform destroy -target=module.eks` - destroys only the EKS cluster and its IAM roles, leaving other infrastructure (VPC, S3, ECR) intact. Run this at the end of each session to stop per-vCPU charges.

## Why EKS Auto Mode

EKS Auto Mode manages node groups, scaling, and upgrades. You still learn Kubernetes objects, rollout, logs, health checks, IAM, networking, and service exposure - but without manually provisioning EC2 launch templates.

## Step 4: Deploy Backend To EKS

After cluster is up, update the image field in your Kubernetes manifest (`infra/k8s/dev/deployment.yaml`) from the local image to the ECR image:

```yaml
image: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/skin-lesion-backend-dev:local
```

**What this field change does:** replaces the local image reference (`skin-lesion-backend:local`) with the full ECR image URI. When EKS applies the deployment, the nodes pull this image from ECR using the node IAM role's ECR read-only permission. Replace `YOUR_ACCOUNT_ID` with your real 12-digit AWS account number.

Apply:

```powershell
kubectl apply -f infra/k8s/dev/ -n skin-lesion-dev
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-dev
```

**What these commands do:** `kubectl apply -f infra/k8s/dev/` applies all YAML files in the directory to the `skin-lesion-dev` namespace in EKS. `kubectl rollout status` blocks until all replicas are up and the readiness probe passes, then prints `successfully rolled out`.

## Stop Point

Do not add production deployment automation until manual EKS deploy works.

Expected result:

```text
ECR image pushed, EKS cluster created, backend deployment running on EKS, /health reachable via kubectl port-forward.
```

**What this result means:** all four stages completed - the Docker image is in ECR, the cluster is running, the deployment is healthy, and you can reach the app through port-forward. If any stage fails, check `kubectl describe pod` or `kubectl logs` for errors.

## Check

```powershell
docker images | grep skin-lesion-backend
kubectl get pods -n skin-lesion-dev
kubectl port-forward svc/skin-lesion-backend 8000:8080 -n skin-lesion-dev
# In another terminal:
curl http://localhost:8000/health
```

**What these commands do:**

- `docker images | grep skin-lesion-backend` - confirms both the local image and the ECR-tagged image are present in your local Docker image list.
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
