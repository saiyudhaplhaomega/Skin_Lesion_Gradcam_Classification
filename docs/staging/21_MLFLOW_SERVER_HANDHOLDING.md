# MLflow Server Handholding Guide

Use this after the training pipeline script works locally (`docs/product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md`).

This closes Critical Gap #6: "MLflow server NOT provisioned - no production model registry."

## Current Project Implementation

Guide 21 now has local MLflow compose support, an existing research promotion script hardened into a CLI, and optional Terraform scaffolding.

Files created or edited:

```text
infra/compose/docker-compose.mlflow.yml
infra/terraform/mlflow.tf
infra/terraform/variables.tf
infra/terraform/outputs.tf
infra/terraform/env/staging.tfvars
Skin_Lesion_XAI_research/scripts/promote_model.py
Skin_Lesion_Classification_backend/app/services/model_service.py
```

Current implemented behavior:

```text
local MLflow can run from Docker Compose with a local SQLite backend and local artifact volume
research promote_model.py accepts CLI arguments
backend already has load_from_registry(model_name, alias="champion")
Terraform has enable_mlflow_server=false by default
```

Not enabled yet:

```text
live MLflow EC2
live S3 artifact bucket
model promotion against a real remote MLflow server
```

Why: the live server costs money and needs an AMI decision, network access, and AWS SSO. I will ask before enabling or applying it.

## Goal

Stand up a self-hosted MLflow tracking server with an S3 artifact backend in staging, so training runs are logged, model versions are registered, and the backend can load the Production-stage model by name.

## Why Self-Hosted MLflow, Not SageMaker

SageMaker Model Registry adds cost and complexity before this project has validated the training pipeline. MLflow gives you:
- Full model versioning (Staging / Production / Archived stages)
- Experiment tracking (every training run logged with hyperparameters + metrics)
- PyTorch model loading by registry URI (`models:/skin-lesion-resnet50/Production`)
- Zero additional AWS services to learn upfront

Switch to SageMaker later if compliance requirements demand it.

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Subsequent steps will `cd` into the research repo, Terraform directory, or backend repo as needed. Starting here makes all the relative paths in each step work correctly.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Research repo: `Skin_Lesion_XAI_research/`
- Compose files: `infra/compose/`
- Terraform root: `infra/terraform/`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create MLflow tracking scripts under `Skin_Lesion_XAI_research/`, Compose files under `infra/compose/`, Terraform files under `infra/terraform/`, and backend model-loading code under `Skin_Lesion_Classification_backend/`.

## Step 1: Run MLflow Locally (Before Staging)

Test the full tracking + registry workflow locally before provisioning EC2:

```powershell
cd Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\Activate.ps1
pip install mlflow

# Start local MLflow server (stores to ./mlruns by default)
mlflow server --host 0.0.0.0 --port 5000
```

**What these commands do:** `cd Skin_Lesion_XAI_research` enters the research repo where training scripts live. `.\skin-lesion-env\Scripts\Activate.ps1` activates the virtual environment. `pip install mlflow` installs the MLflow package, which includes both the Python client and the `mlflow` CLI. `mlflow server --host 0.0.0.0 --port 5000` starts a local tracking server - `--host 0.0.0.0` makes it reachable from any address on the machine (needed for Docker or WSL), and `--port 5000` sets the port. Without a backend store argument, MLflow writes run data to a local `./mlruns` directory.

Open `http://localhost:5000` in a browser. You should see the MLflow UI.

Run a test training call:

```powershell
python scripts/train_model.py `
  --dataset-manifest manifests/dataset-v001.csv `
  --model-name skin-lesion-resnet50 `
  --model-version model-v001 `
  --output-dir outputs/model-v001 `
  --mlflow-tracking-uri http://localhost:5000
```

**What this command does:** runs the training script with the local MLflow server as the tracking destination. `--dataset-manifest` points to the CSV that lists the training images. `--model-name` sets the registered model name that will appear in the MLflow registry. `--mlflow-tracking-uri http://localhost:5000` tells the training script where to send metrics, parameters, and artifacts - the same server you just started.

Check the MLflow UI: the experiment should appear with one run.

## Step 2: Add Docker Compose MLflow Service (Local + Staging-Style)

Create `infra/compose/docker-compose.mlflow.yml`:

```yaml
services:
  mlflow:
    image: ghcr.io/mlflow/mlflow:v2.19.0
    container_name: skin-lesion-mlflow-local
    command: >
      mlflow server
      --host 0.0.0.0
      --port 5000
      --backend-store-uri postgresql+psycopg://postgres:postgres@postgres:5432/mlflow
      --default-artifact-root s3://skin-lesion-mlflow-staging/artifacts/
    environment:
      AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
      AWS_DEFAULT_REGION: eu-central-1
    ports:
      - "5000:5000"
    depends_on:
      postgres:
        condition: service_healthy

  # Run this once to create the mlflow database
  mlflow-db-init:
    image: ghcr.io/mlflow/mlflow:v2.19.0
    command: mlflow db upgrade postgresql+psycopg://postgres:postgres@postgres:5432/mlflow
    depends_on:
      postgres:
        condition: service_healthy
    restart: "no"
```

Current state: this file exists with a local SQLite backend and local Docker volume artifact root. It does not require AWS credentials.

**What this Compose service does:** the `mlflow` service runs the official MLflow Docker image. `--backend-store-uri postgresql+psycopg://...` tells MLflow to store run metadata (parameters, metrics, tags) in the Postgres database instead of the local filesystem - this makes the data persist across container restarts. `--default-artifact-root s3://...` tells MLflow to store model artifacts (weights, plots, pickles) in S3 instead of locally. The `AWS_*` environment variables give the container credentials to write to S3. `depends_on: condition: service_healthy` waits for Postgres to pass its health check before starting MLflow. `mlflow-db-init` runs `mlflow db upgrade` once to create the MLflow schema tables in the `mlflow` database - `restart: "no"` ensures it does not loop after finishing.

For local testing without S3, use a local artifact backend instead:

```yaml
    command: >
      mlflow server
      --host 0.0.0.0
      --port 5000
      --backend-store-uri sqlite:///mlflow.db
      --default-artifact-root /mlflow-artifacts
    volumes:
      - mlflow_artifacts:/mlflow-artifacts
```

**What this alternative config does:** replaces Postgres with a SQLite file (`mlflow.db`) and S3 with a local Docker volume (`/mlflow-artifacts`). This is simpler for local dev when you do not want to set up Postgres or S3 credentials. Use the S3 + Postgres config for any staging or persistent environment where you want runs to survive container restarts and artifacts to be accessible from EC2.

Bring up:

```powershell
docker compose -f infra/compose/docker-compose.local.yml `
               -f infra/compose/docker-compose.mlflow.yml up -d
curl http://localhost:5000/health
```

**What these commands do:** the two `-f` flags merge the base local Compose file (which defines the Postgres service) with the MLflow Compose file. `up -d` starts both in the background. `curl http://localhost:5000/health` hits the MLflow health endpoint - returns `{"status": "OK"}` when the server is ready. If it returns a connection error, wait 10-15 seconds for the database init to finish and try again.

Expected: `{"status": "OK"}`.

Do not run this automatically if Docker Desktop is not already running. Starting Docker or long-running containers is an interactive environment step.

## Step 3: Terraform - MLflow EC2 + S3 (Staging)

Current Terraform path:

```text
infra/terraform/mlflow.tf
```

The optional resources are controlled by:

```text
enable_mlflow_server = false
```

Reference module shape if you later split the file into a module:

Create `infra/terraform/modules/mlflow/main.tf`:

```hcl
variable "vpc_id"           {}
variable "subnet_id"        {}   # private app subnet
variable "allowed_sg_ids"   { type = list(string) }
variable "environment"      {}
variable "key_pair_name"    {}
variable "db_password_arn"  {}   # Secrets Manager ARN for Postgres password
variable "db_endpoint"      {}   # Postgres writer endpoint for the mlflow database

# S3 bucket for MLflow artifacts
resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "skin-lesion-mlflow-${var.environment}-artifacts"
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# IAM role for MLflow EC2 instance
resource "aws_iam_role" "mlflow_ec2" {
  name = "skin-lesion-mlflow-ec2-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "mlflow_s3" {
  name = "mlflow-s3-access"
  role = aws_iam_role.mlflow_ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.mlflow_artifacts.arn,
        "${aws_s3_bucket.mlflow_artifacts.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "mlflow_ec2" {
  name = "skin-lesion-mlflow-ec2-${var.environment}"
  role = aws_iam_role.mlflow_ec2.name
}

resource "aws_security_group" "mlflow" {
  name   = "skin-lesion-mlflow-sg-${var.environment}"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = var.allowed_sg_ids   # only from ECS + research EC2
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "mlflow" {
  ami                    = "ami-0caef02b518350c8b"   # Amazon Linux 2023 eu-central-1
  instance_type          = "t3.small"               # upgrade for parallel training runs
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.mlflow.id]
  iam_instance_profile   = aws_iam_instance_profile.mlflow_ec2.name
  key_name               = var.key_pair_name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3-pip
    pip3 install mlflow==2.19.0 psycopg[binary] boto3
    mlflow server \
      --host 0.0.0.0 \
      --port 5000 \
      --backend-store-uri postgresql+psycopg://mlflow:$(aws secretsmanager get-secret-value --secret-id ${var.db_password_arn} --query SecretString --output text)@${var.db_endpoint}/mlflow \
      --default-artifact-root s3://${aws_s3_bucket.mlflow_artifacts.id}/artifacts/ \
      --gunicorn-opts "--timeout 120" &
  EOF

  tags = {
    Name        = "skin-lesion-mlflow-${var.environment}"
    Environment = var.environment
  }
}

output "mlflow_tracking_uri" {
  value = "http://${aws_instance.mlflow.private_ip}:5000"
}

output "artifact_bucket" {
  value = aws_s3_bucket.mlflow_artifacts.id
}
```

**What this HCL does:** `aws_s3_bucket.mlflow_artifacts` stores all model artifacts (weights, metrics plots, model cards). `aws_s3_bucket_versioning` enables versioning so previous model artifact uploads are not overwritten - each MLflow run gets a unique path under `artifacts/`. `aws_s3_bucket_server_side_encryption_configuration` encrypts all objects at rest with KMS. The `aws_iam_role.mlflow_ec2` allows the EC2 instance to assume an IAM role without static credentials. `aws_iam_role_policy.mlflow_s3` grants only S3 access to the artifact bucket - nothing else. `aws_iam_instance_profile` attaches the role to the EC2 instance so the instance can write to S3. The security group allows port 5000 only from ECS and the research EC2 instance - the MLflow UI is not exposed to the internet. `aws_instance.mlflow` launches `t3.small` in the private app subnet; `user_data` is a bash script that runs at first boot, installs MLflow, and starts the server with `&` so it runs in the background. The database password is fetched from Secrets Manager at boot time using the AWS CLI. `mlflow_tracking_uri` and `artifact_bucket` are outputs so other modules can reference where MLflow is running.

Apply:

```powershell
cd infra/terraform
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
terraform output mlflow_tracking_uri
```

For the current repo, use:

```powershell
terraform plan -var-file="env/staging.tfvars"
```

This requires AWS credentials because the Terraform backend is remote S3. Ask before running it.

**What these commands do:** `terraform plan` previews the MLflow resources - check that it shows exactly the EC2 instance, security group, S3 bucket, IAM role, and instance profile, with no surprise replacements of unrelated resources. `terraform apply` creates them - the EC2 instance will take 2-3 minutes to boot and run the user_data script before MLflow is reachable. `terraform output mlflow_tracking_uri` prints the private IP URL in the form `http://10.0.x.x:5000` - copy this value into the backend environment variable and the training script `--mlflow-uri` argument.

Before applying, read the plan and confirm it shows one MLflow EC2 instance, one MLflow security group, one S3 artifact bucket, and the IAM role/profile for that instance. Do not apply if Terraform plans to replace unrelated networking, database, or backend service resources.

## Step 4: Add Model Promotion Script

Current file:

```text
Skin_Lesion_XAI_research/scripts/promote_model.py
```

Run it as:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\python.exe scripts\promote_model.py --model-name skin-lesion-resnet50 --min-test-auc 0.85 --mlflow-uri http://localhost:5000
```

Expected result:

```text
The script selects the best run by test_auc.
It exits non-zero if test_auc is below the threshold.
It registers the model and assigns the champion alias only when the threshold passes.
```

Reference implementation:

```python
"""
Promote a model to Production after validation gate passes.

Requirements before running:
  1. test_auc must be >= MIN_TEST_AUC
  2. A research_reviewer must have manually confirmed model-card.json approved_for_production=true
  3. Run from Skin_Lesion_XAI_research/ with MLflow tracking URI set

Usage:
  python scripts/promote_model.py \
    --model-name skin-lesion-resnet50 \
    --run-id <mlflow_run_id> \
    --min-test-auc 0.85 \
    --mlflow-uri http://localhost:5000
"""
from __future__ import annotations

import argparse
import json
import sys

import mlflow
from mlflow.tracking import MlflowClient


def promote(model_name: str, run_id: str, min_test_auc: float, mlflow_uri: str) -> None:
    mlflow.set_tracking_uri(mlflow_uri)
    client = MlflowClient()

    run = client.get_run(run_id)
    test_auc = run.data.metrics.get("test_auc", 0.0)
    print(f"Run {run_id}: test_auc = {test_auc:.4f}")

    if test_auc < min_test_auc:
        print(f"BLOCKED: test_auc {test_auc:.4f} < minimum {min_test_auc}. Do not promote.")
        sys.exit(1)

    # Register the model version from this run
    result = mlflow.register_model(f"runs:/{run_id}/model", model_name)
    version = result.version
    print(f"Registered {model_name} as version {version}")

    # Archive all existing Production versions
    for mv in client.search_model_versions(f"name='{model_name}'"):
        if mv.current_stage == "Production" and mv.version != version:
            client.transition_model_version_stage(
                name=model_name, version=mv.version, stage="Archived"
            )
            print(f"Archived previous Production version {mv.version}")

    # Promote this version
    client.transition_model_version_stage(
        name=model_name, version=version, stage="Production"
    )
    print(f"Promoted {model_name} v{version} to Production")
    print(f"Load in backend with: mlflow.pytorch.load_model('models:/{model_name}/Production')")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-name", default="skin-lesion-resnet50")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--min-test-auc", type=float, default=0.85)
    parser.add_argument("--mlflow-uri", default="http://localhost:5000")
    args = parser.parse_args()
    promote(args.model_name, args.run_id, args.min_test_auc, args.mlflow_uri)


if __name__ == "__main__":
    main()
```

**What this script does:** `client.get_run(run_id)` fetches the run's logged metrics from MLflow. `test_auc = run.data.metrics.get("test_auc", 0.0)` reads the AUC value the training script logged - if the metric was never logged, it defaults to 0.0, which will always fail the gate. `sys.exit(1)` stops the script with a non-zero exit code if the AUC is too low, making it safe to call from CI without accidentally promoting a bad model. `mlflow.register_model(f"runs:/{run_id}/model", model_name)` creates a new version in the Model Registry pointing to the artifacts from that run. The loop over `search_model_versions` archives any existing Production version - you cannot have two Production versions at once. `transition_model_version_stage` then sets the new version to Production. The `argparse` section at the bottom makes this a reusable script that accepts different model names, run IDs, and thresholds without editing the file.

Run after a successful training run:

```powershell
python scripts/promote_model.py `
  --run-id <paste run id from MLflow UI> `
  --mlflow-uri http://localhost:5000
```

**What this command does:** calls the promote script with the run ID from the MLflow UI. The run ID is the alphanumeric string shown on each experiment run's detail page. `--min-test-auc` defaults to 0.85 if not provided. The script will print the AUC value, register the model version, archive any previous Production version, and print the URI you can use to load it in the backend.

## Step 5: Wire Backend To Load From Registry

Update `Skin_Lesion_Classification_backend/app/services/model_service.py`:

```python
import os
import mlflow.pytorch

def _load_model(device):
    tracking_uri = os.environ.get("MLFLOW_TRACKING_URI", "")
    model_name = os.environ.get("MODEL_NAME", "skin-lesion-resnet50")
    stage = os.environ.get("MODEL_STAGE", "Production")

    if tracking_uri:
        mlflow.set_tracking_uri(tracking_uri)
        model = mlflow.pytorch.load_model(f"models:/{model_name}/{stage}")
        model.eval()
        return model.to(device)
    else:
        # Fallback: local .pth file (used in local dev)
        return _load_from_local_path(device)
```

**What this function does:** `os.environ.get("MLFLOW_TRACKING_URI", "")` returns an empty string if the variable is not set. The `if tracking_uri` check then falls through to the local file fallback - this means the same code runs in both local dev (no MLflow, load from `.pth` file) and staging (MLflow set, load from registry). `mlflow.pytorch.load_model(f"models:/{model_name}/{stage}")` downloads the model weights and metadata from the MLflow artifact store (S3 in staging) and reconstructs the PyTorch model in memory. `model.eval()` switches the model from training mode to inference mode - this disables dropout and batch normalization training behavior. `model.to(device)` moves the weights to GPU if one is available.

Add to the backend environment file:

```text
Skin_Lesion_Classification_backend/.env
```

**What this path means:** `.env` is the local environment file that the backend reads at startup. Do not commit this file - it contains local dev secrets and URIs that differ from staging.

```text
MLFLOW_TRACKING_URI=http://localhost:5000   # local dev
MODEL_NAME=skin-lesion-resnet50
MODEL_STAGE=Production
```

**What these variables configure:** `MLFLOW_TRACKING_URI` tells the backend where the MLflow server is. In local dev this is localhost; in staging it is the private IP from `terraform output mlflow_tracking_uri`. `MODEL_NAME` matches the name used when registering the model. `MODEL_STAGE` is `Production` in staging and production, but can be set to `Staging` to test a model before promoting it.

## Rollback Procedure

If the new Production model degrades performance, roll back by promoting the previous version:

Run this as a temporary rollback script from:

```text
Skin_Lesion_XAI_research/
```

**What this path means:** run the rollback script from the research repo directory where the virtual environment and MLflow dependencies are installed.

File path example:

```text
Skin_Lesion_XAI_research/scripts/rollback_model.py
```

**What this file is:** a one-time emergency script kept in the research scripts directory. It is not part of the automated pipeline - it is run manually when a bad model makes it to Production and needs to be reverted immediately.

```python
# Emergency rollback: transition previous Archived version back to Production
import mlflow
from mlflow.tracking import MlflowClient

MLFLOW_URI = os.environ["MLFLOW_TRACKING_URI"]
MODEL_NAME = "skin-lesion-resnet50"
ROLLBACK_VERSION = "3"   # the version you want to restore

mlflow.set_tracking_uri(MLFLOW_URI)
client = MlflowClient()

# Archive the current bad Production version
for mv in client.search_model_versions(f"name='{MODEL_NAME}'"):
    if mv.current_stage == "Production":
        client.transition_model_version_stage(name=MODEL_NAME, version=mv.version, stage="Archived")
        print(f"Archived bad version {mv.version}")

# Restore
client.transition_model_version_stage(name=MODEL_NAME, version=ROLLBACK_VERSION, stage="Production")
print(f"Rolled back to version {ROLLBACK_VERSION}")
```

**What this script does:** `ROLLBACK_VERSION = "3"` is the version number you want to restore - find this in the MLflow UI by looking at the Archived models. The loop first archives the current bad Production version so there is no overlap. Then `transition_model_version_stage` promotes the chosen archived version back to Production. After this script runs, the MLflow registry shows the old version as Production - but the running ECS tasks still have the bad model loaded in memory. That is why the next step restarts the service.

Then restart the ECS tasks so they pick up the rollback version:

```powershell
aws ecs update-service --cluster skin-lesion-staging --service backend --force-new-deployment
```

**What this command does:** `--force-new-deployment` tells ECS to stop the running tasks and start new ones even though the task definition has not changed. The new tasks will call `_load_model` at startup, which reads from the MLflow registry and downloads the restored Production version. This is the mechanism that actually gets the old model weights into memory on the running service.

## Concepts You Just Touched

- [Model Registry (9.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#91-model-registry) - version + stage + artifact path as atomic unit
- [Shadow Deployment (9.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#94-shadow-deployment) - before replacing Production, route 10% of traffic to the new version
- [Immutable Infrastructure (6.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#65-immutable-infrastructure) - the MLflow artifact (model weights + metadata) is immutable once registered

## Questions You Should Be Able To Answer

1. Why does the rollback script archive the current Production version before promoting the old one? What breaks if you skip the archive step?
2. The EC2 user_data script starts MLflow with `&` (background). What happens to MLflow if the EC2 instance reboots? What is the production-grade fix?
3. `mlflow.register_model` creates a new version. `transition_model_version_stage` promotes it. Why are these two separate steps instead of one atomic operation?
4. The backend loads the model at startup with `mlflow.pytorch.load_model`. How long does this take on a cold ECS task start, and how does this interact with the ECS health check grace period?
5. What is a shadow deployment, and why should you shadow-test a new model version before promoting it to Production on a medical platform?

## Cost Pause / Resume

The MLflow EC2 instance and S3 artifact bucket can continue to cost money after testing. Pausing Kubernetes workloads does not stop the MLflow EC2 instance.

Run from the repo root:

```powershell
make cloud-status ENV=staging
```

**What this does:** reports the current running state of all staging cloud resources, including the MLflow EC2 instance. Check this before stopping for the day.

If you are done testing MLflow for the day and this is a disposable staging environment, shut it down:

```powershell
make cloud-shutdown ENV=staging CONFIRM_DESTROY=YES
```

**What this does:** runs `terraform destroy` against the staging workspace. This terminates the MLflow EC2 instance and stops the per-hour charge. The S3 artifact bucket may be retained depending on the `force_destroy` setting - check the Terraform output to confirm whether the bucket was destroyed or left with its objects.

Expected result:

```text
Terraform destroys resources tracked in the staging workspace, including the MLflow EC2 instance if this guide created it.
```

**What this means:** the EC2 instance is terminated and billing stops. The S3 bucket and its model artifacts may persist - confirm this is intentional before destroying. If you still need the model weights, do not destroy the bucket until they are copied or the model is re-trainable.

If you need to preserve model artifacts, confirm the S3 bucket retention plan before destroying staging. Do not destroy the only copy of a model you still need.
