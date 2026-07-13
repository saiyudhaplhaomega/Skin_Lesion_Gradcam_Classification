# Docs Validation Handholding Guide

Use this to understand how documentation integrity is validated and how to maintain it.

## Command Location

Run every command in this guide from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this does: moves your terminal to the main workspace where the root `Makefile`, `scripts/`, and `docs/` folder live.

## Files Edited By This Guide

```text
scripts/docs-validate.ps1
Makefile
docs/99_DOC_ORDER.md
```

What these files do:

- `scripts/docs-validate.ps1` contains the actual validation logic.
- `Makefile` exposes that validator as `make docs-check`.
- `docs/99_DOC_ORDER.md` is the canonical list of guide files that must stay aligned.

## Rule

If it teaches, put it in docs.
If it repeats, put it in Makefile.
If it validates or automates, put it in scripts.

## What Is Docs-Check?

`make docs-check` validates that the guide order, required files, Markdown links, stale paths, and cloud documentation gates are correct. It is the gate before committing changes.

Run it from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
make docs-check
```

What this does: runs the documentation validation from the root workspace so paths resolve correctly.

## How It Works

The docs-check pipeline has two layers:

1. **PowerShell script** (`scripts/docs-validate.ps1`) - validates file existence, stale paths, typos, and ordering rules
2. **Makefile targets** (`docs-check` in root Makefile) - orchestrates the script and prints results

## Validation Script Template

The active validator lives at:

```text
scripts/docs-validate.ps1
```

What this path means: this is the script to inspect when `make docs-check` fails or when you need to add a new documentation rule.

Use the current repository file as the source of truth. It must check:

- every guide listed in `docs/99_DOC_ORDER.md` exists
- every relative Markdown link in README and docs resolves
- stale `docs/build` and `docs/advanced` references are absent
- outdated "Aurora PostgreSQL first" wording is absent
- ECS and EKS auto-heal boundary warnings remain present
- deleted Terraform module/Lambda folders stay absent
- every staging and production guide has `Cost Pause / Resume`
- the staging order keeps cloud cost control, empty Terraform, VPC, and bootstrap gates

## What Gets Validated

The script checks:

1. **Required files exist** - All files listed in `docs/99_DOC_ORDER.md` are present
2. **Relative links resolve** - README and docs links point to existing local files or folders
3. **No stale paths** - No references to `docs/build` or `docs/advanced`
4. **Correct ordering** - `docs/99_DOC_ORDER.md` contains expected guide references
5. **ECS/EKS boundary warnings** - Auto-heal guides have appropriate warnings
6. **Cloud guide cost controls** - Staging and production guides include `Cost Pause / Resume`

## When To Add A New Validation

Add a new check when:

- A new required guide file is created
- A new rule is added to the reading order
- A new integrity constraint is identified

Do not add checks for things that are style choices. Only add checks for things that would break a builder following the guides.

## Common Errors

### Missing required file

```
Missing required file: docs/local-dev/08_MAKEFILE_TESTING_HANDHOLDING.md
```

What this means: `docs/99_DOC_ORDER.md` lists a guide file that does not exist at that path.

Fix: Create the missing file or check the file name spelling.

### Broken Markdown link

```
Broken Markdown link in docs/01_BUILD_ORDER.md: docs/staging/old-name.md
```

What this means: a Markdown link points to a local file that cannot be found.

Fix: Update the link to the current file path or restore the missing guide file.

### Stale docs path

```
Stale docs path found in docs/some/file.md
```

What this means: a guide still references an old folder layout such as `docs/build/` or `docs/advanced/`.

Fix: Update any reference from `docs/build/` or `docs/advanced/` to the correct path in `docs/local-dev/`, `docs/product/`, `docs/staging/`, `docs/production/`, or `docs/reference/`.

## Check Command

Run:

```powershell
make docs-check
```

What this does: runs the root docs validation target.

Expected result:

```text
docs-check ok
```

**What this confirms:** all guide files exist, all relative Markdown links resolve, no stale paths remain, and the staging/production guides include the required cost-control sections. A clean pass here means the guide sequence is internally consistent.

Why: this proves the beginner reading path, local links, and cloud sequencing guardrails are still intact.

## Concepts You Just Touched

- [Runbook-Linked Alerts (10.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#105-runbook-linked-alerts) - docs ARE the runbooks; broken docs are broken runbooks
- [Audit-Immutable Log (11.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#113-audit-immutable-log) - git history is the audit log for documentation

## Questions You Should Be Able To Answer

1. Why is broken cross-link a worse failure than a typo in this curriculum?
2. What property does `make docs-check` actually check? What does it NOT check?
3. If a guide says "after X.md works" and X.md was renamed, who catches the bug?
4. Why does the curriculum number guides instead of relying on a TOC alone?
5. What is the difference between a doc that is wrong and a doc that is stale?

If you cannot answer Q1-Q3, re-read the validation rules above.
If you cannot answer Q4-Q5, read `02_ULTIMATE_PRODUCTION_GUIDE.md` and `99_DOC_ORDER.md` to see how sequence is enforced.

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `docs-check` passes but a link is broken | check is too lenient; relative path validator missing | extend the check to assert each link target exists |
| Two guides claim to be authoritative on the same topic | curriculum drift | add cross-link in one and demote the other to "see also" |
| Sequence in `99_DOC_ORDER.md` does not match folder numbers | rename without renumber | rerun the numbering rule |
| Guide references a file that was deleted | stale link | grep all `.md` for the dead filename |
| Anti-pattern lists differ across guides | no single source | consolidate into `00_START_HERE.md` |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** report status, pause compute, and optionally destroy all dev cloud resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** recreate and verify the dev environment before continuing.

If this guide was local-only, no cloud shutdown is needed.
