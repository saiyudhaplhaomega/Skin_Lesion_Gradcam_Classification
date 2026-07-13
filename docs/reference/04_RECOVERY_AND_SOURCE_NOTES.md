# Recovery And Source Notes

This file documents what was recovered and what was rebuilt.

## Command Location

This guide is for notes and recovery checks.

Run commands from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves the terminal to the main workspace root. Needed as a starting point if you run any recovery or search commands from this guide.

## What Could Be Restored Exactly

Tracked files were restored from Git:

- `.github/workflows/*`
- `infra/terraform/main.tf`
- `infra/terraform/modules/*`
- `infra/terraform/lambda/*`

These are preserved as reference material. Do not run them until the guides reach that stage.

## What Could Not Be Restored Exactly

The old root `docs/*.md` long guides were untracked and ignored by Git. After deletion, Git could not restore their exact text.

That means the new root guide set is a reconstruction, not a byte-for-byte recovery.

## What Sources Still Exist

Useful project material still exists in:

```text
Skin_Lesion_Classification_backend/BUILD_BACKEND.md
Skin_Lesion_Classification_frontend/BUILD_FRONTEND.md
graphify-out/obsidian/
graphify-out/GRAPH_REPORT.md
graphify-out/memory/
```

**What these sources mean:**

- `BUILD_BACKEND.md` and `BUILD_FRONTEND.md` - surviving build guides inside each sub-repo that contain step-by-step instructions independent of the main docs.
- `graphify-out/obsidian/` - the Obsidian vault generated from the knowledge graph. Contains community notes, canvas views, and structured summaries of the codebase.
- `graphify-out/GRAPH_REPORT.md` - the knowledge graph report summarizing entities, relationships, and cluster labels.
- `graphify-out/memory/` - project memory notes recording architectural decisions, open gaps, and session context.

The new root guides were rebuilt from:

- the current repository structure
- the surviving backend guide
- the surviving frontend guide
- Graphify/Obsidian summaries
- the architecture decisions discussed for Kubernetes, EKS, SQS, EventBridge, Aurora DSQL, security, reliability, cost, and future plans

## New Rule

Do not delete guide material to simplify the project.

Instead:

1. keep beginner docs short
2. keep local implementation docs in `docs/local-dev/`
3. keep product feature docs in `docs/product/`
4. keep staging transition docs in `docs/staging/`
5. keep production and advanced explanations in `docs/production/` and `docs/reference/`
4. label old material clearly
5. ask before deleting anything

## If More Old Content Is Needed

Search these places first:

```powershell
Get-ChildItem graphify-out\obsidian -File | Select-Object Name
Get-ChildItem graphify-out\memory -File | Select-Object Name
Get-Content Skin_Lesion_Classification_backend\BUILD_BACKEND.md
Get-Content Skin_Lesion_Classification_frontend\BUILD_FRONTEND.md
```

**What these commands do:**

- `Get-ChildItem graphify-out\obsidian -File | Select-Object Name` lists all files in the Obsidian vault directory, giving you a map of available knowledge graph notes.
- `Get-ChildItem graphify-out\memory -File | Select-Object Name` lists all memory note files, useful for finding project context and gap documentation.
- `Get-Content Skin_Lesion_Classification_backend\BUILD_BACKEND.md` reads the backend build guide in full, as a recovery source if the main docs are missing content.
- `Get-Content Skin_Lesion_Classification_frontend\BUILD_FRONTEND.md` reads the frontend build guide similarly.

If a future backup or Git branch contains the old root docs, copy them into:

```text
docs/archive/
```

**What this path means:** a dedicated archive directory for old guide versions, kept separate from the active learning path so they do not confuse beginners.

Do not replace the new beginner path.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the dev environment state.
- `make cloud-pause ENV=dev` pauses pausable resources.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources with explicit confirmation.

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
