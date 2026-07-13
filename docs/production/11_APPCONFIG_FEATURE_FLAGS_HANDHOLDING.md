# AppConfig Feature Flags Handholding Guide

Use this after manual staging deployment and rollback work.

AppConfig is for runtime flags such as:

```text
rag_explanation_v2
new_heatmap_method
canary_batch_percent
async_report_generation
patient_memory_beta
```

**What these flags are for:**

- `rag_explanation_v2` - controls whether the new RAG-based explanation pipeline is active. Off by default; enable for a subset of users during rollout.
- `new_heatmap_method` - switches between the current Grad-CAM++ implementation and a new heatmap approach without redeployment.
- `canary_batch_percent` - controls what fraction of inference batches routes through the canary model path.
- `async_report_generation` - when on, PDF report generation is handled by a background worker instead of blocking the API request.
- `patient_memory_beta` - enables the patient memory/lesion history feature for beta users only.

## Current Module Warning

The former module under:

```text
infra/terraform/modules/appconfig
```

**What this module was:** a Terraform module that defined AppConfig resources. It was removed after this guide documented the implementation approach directly.

was removed after its ideas were integrated into this guide. If you recreate it later, fix Terraform resource names to match provider snake_case naming.

Replace these invalid or suspicious names:

```text
aws_appconfigHostedConfigurationVersion -> aws_appconfig_hosted_configuration_version
aws_appconfigDeployment -> aws_appconfig_deployment
```

**What these name replacements mean:** the AWS Terraform provider uses snake_case for resource names. `aws_appconfigHostedConfigurationVersion` is not a valid resource type. The corrected names (`aws_appconfig_hosted_configuration_version` and `aws_appconfig_deployment`) match the actual provider documentation and will pass `terraform validate`.

These resource names match the current HashiCorp AWS provider AppConfig resources. Still run `terraform validate` with your installed provider before applying.

## Command Location

Start from:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves the terminal to the main workspace root. Run this first so relative paths to `infra/terraform` and `Skin_Lesion_Classification_backend` resolve correctly.

Terraform files belong in:

```text
infra/terraform
```

**What this path is:** the directory where all Terraform infrastructure files live. AppConfig Terraform resources go here as `appconfig.tf`.

Backend feature flag code belongs in:

```text
Skin_Lesion_Classification_backend
```

**What this path is:** the FastAPI repository where the Python feature flag dataclass and tests live.

## Parameters You Must Set First

```text
ENVIRONMENT=staging
APPCONFIG_APPLICATION_NAME=skin-lesion-staging
APPCONFIG_PROFILE_NAME=feature-flags
APPCONFIG_ENVIRONMENT_NAME=staging
APPCONFIG_POLL_SECONDS=60
FAIL_CLOSED_FLAGS=rag_explanation_v2,vlm_cross_check
FAIL_OPEN_FLAGS=async_report_generation
```

**What these parameters mean:**

- `ENVIRONMENT=staging` - scope all AppConfig resources to staging. Create separate applications for each environment.
- `APPCONFIG_APPLICATION_NAME=skin-lesion-staging` - the AppConfig Application name that groups profiles and environments together.
- `APPCONFIG_PROFILE_NAME=feature-flags` - the Configuration Profile name containing the feature flag values.
- `APPCONFIG_ENVIRONMENT_NAME=staging` - the AppConfig Environment name (not the same as an AWS environment). Each deployment reads from a specific environment.
- `APPCONFIG_POLL_SECONDS=60` - how often the backend polls AppConfig for updated flag values. Lower values mean faster propagation but more API calls.
- `FAIL_CLOSED_FLAGS=rag_explanation_v2,vlm_cross_check` - if AppConfig is unreachable, these flags default to OFF. Clinical explanation and cross-check features are safer off than on.
- `FAIL_OPEN_FLAGS=async_report_generation` - if AppConfig is unreachable, async report generation defaults to ON because it is safer for performance than synchronous blocking.

## Step 1: Define The Flag Contract

Create:

```text
Skin_Lesion_Classification_backend/app/core/feature_flags.py
```

**What this file is:** the Python module that defines the feature flag contract. Every flag the backend uses is declared here with its safe default value.

Paste:

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class FeatureFlags:
    new_heatmap_method: bool = False
    rag_explanation_v2: bool = False
    vlm_cross_check: bool = False
    async_report_generation: bool = True
    patient_memory_beta: bool = False


def default_feature_flags() -> FeatureFlags:
    return FeatureFlags()
```

**What this code does:**

- `from dataclasses import dataclass` imports the dataclass decorator, which generates `__init__`, `__repr__`, and equality methods automatically.
- `@dataclass(frozen=True)` makes the FeatureFlags instance immutable after creation. You cannot accidentally change a flag mid-request.
- `class FeatureFlags` defines the flag schema. Each field is a `bool` with a safe default - most flags default to `False` so new features are off until explicitly enabled.
- `async_report_generation: bool = True` is an exception: it defaults to True because async generation is the safer default for API performance.
- `def default_feature_flags() -> FeatureFlags:` is a factory function that creates a FeatureFlags instance with all defaults. The app calls this when AppConfig is unavailable.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.core.feature_flags import default_feature_flags; print(default_feature_flags())"
```

**What this check does:** imports the `default_feature_flags` function and prints the resulting object. If the import fails or the dataclass has a syntax error, this will raise an exception immediately, not at runtime during a request.

Expected result:

```text
Feature flag defaults load without AWS.
```

Why: local dev must not require AppConfig.

## Step 2: Add AppConfig Resources

Create or edit:

```text
infra/terraform/appconfig.tf
```

**What this file is:** the Terraform file where AppConfig infrastructure resources are declared: application, environment, configuration profile, hosted configuration version, and deployment strategy.

Use the module only after correcting resource names. For learning, first create one application, one environment, one configuration profile, one hosted configuration version, and one deployment strategy.

Check:

```powershell
cd infra/terraform
terraform fmt
terraform validate
terraform plan
```

**What these commands do:**

- `cd infra/terraform` moves into the Terraform directory where `.tf` files live.
- `terraform fmt` formats all `.tf` files to canonical style.
- `terraform validate` checks resource types, required arguments, and provider version compatibility without calling AWS.
- `terraform plan` previews what AWS resources would be created. Review the plan carefully before applying to avoid unexpected changes.

Expected result:

```text
Terraform plans AppConfig resources only.
No deployment changes are triggered by feature flag setup.
```

## Step 3: App Reads Flags Safely

Backend rule:

```text
If AppConfig is unavailable, use local default_feature_flags().
Do not block /health on AppConfig.
Do not let patient safety wording depend only on a remote flag.
```

**What these rules mean:**

- `If AppConfig is unavailable, use local default_feature_flags()` - the app must start and serve requests even if AppConfig is down. The safe defaults are the fallback.
- `Do not block /health on AppConfig` - the `/health` endpoint must not call AppConfig. If AppConfig is slow or unavailable, the liveness probe must still pass.
- `Do not let patient safety wording depend only on a remote flag` - clinical safety language (like "this is not a diagnosis") must always appear regardless of flag state. Flags should gate experimental features, not mandatory safety copy.

Create tests:

```text
Skin_Lesion_Classification_backend/tests/test_feature_flags.py
```

**What this file is:** a pytest test module that proves the feature flag defaults are safe before AppConfig is ever called.

Paste:

```python
from app.core.feature_flags import default_feature_flags


def test_safe_feature_flag_defaults() -> None:
    flags = default_feature_flags()

    assert flags.rag_explanation_v2 is False
    assert flags.vlm_cross_check is False
    assert flags.async_report_generation is True
```

**What this test does:**

- `from app.core.feature_flags import default_feature_flags` imports the factory function. If the module has errors, this import fails and the test fails immediately.
- `flags = default_feature_flags()` creates a FeatureFlags instance with all defaults without any network calls.
- `assert flags.rag_explanation_v2 is False` - checks that the RAG explanation v2 flag defaults to off. This feature should not activate until explicitly enabled via AppConfig.
- `assert flags.vlm_cross_check is False` - confirms the vision-language model cross-check is off by default.
- `assert flags.async_report_generation is True` - confirms async report generation defaults to on, since that is the safer mode for API performance.

Check:

```powershell
cd Skin_Lesion_Classification_backend
pytest tests/test_feature_flags.py
```

**What this does:** runs only the feature flag test file. If defaults change accidentally (e.g., someone flips `rag_explanation_v2` to `True` in the code), this test catches it before deployment.

Expected result:

```text
Feature flags have safe local defaults.
```

## Completion Gate

AppConfig is ready only when:

```text
Terraform validates AppConfig resources
backend has local safe defaults
tests cover default flag behavior
flags are not used for mandatory medical safety copy
flag changes have an audit trail or deployment record
```

**What this gate means:**

- `Terraform validates AppConfig resources` - run `terraform validate` and `terraform plan` in `infra/terraform/` to confirm the resource definitions are correct.
- `backend has local safe defaults` - the backend starts and runs all its endpoints without any AppConfig connection.
- `tests cover default flag behavior` - at least one test asserts the default value of each flag. This catches accidental changes.
- `flags are not used for mandatory medical safety copy` - review every flag usage in the codebase. No flag should gate mandatory clinical disclaimer or safety text.
- `flag changes have an audit trail or deployment record` - AppConfig deployments are versioned. Each flag change should be traceable to a deployment timestamp and initiator.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` checks dev cloud environment state.
- `make cloud-pause ENV=dev` pauses pausable resources to reduce billing.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the flag prevents accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms it is healthy before work begins.

If this guide was local-only, no cloud shutdown is needed.
