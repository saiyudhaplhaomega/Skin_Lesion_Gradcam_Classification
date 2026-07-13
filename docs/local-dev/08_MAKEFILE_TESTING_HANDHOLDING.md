# Makefile Testing Handholding Guide

Use this to understand how Makefiles work in this project and how to build and maintain them.

## Goal

Understand how Makefiles work across this multi-repo project and how to build and maintain them.

## What Is A Makefile?

A Makefile is a command menu for a project. Instead of remembering long commands, you run short ones:

```powershell
make help
make backend-test
make frontend-build
make docs-check
```

What these commands do:

- `make help` prints the command menu.
- `make backend-test` delegates to the backend test command.
- `make frontend-build` delegates to the frontend production build.
- `make docs-check` runs the documentation validator.

## Why This Project Uses Makefiles

This project has multiple repos:

```text
main workspace (docs/infra)     - Skin_Lesion_GRADCAM_Classification
backend repo                    - Skin_Lesion_Classification_backend
frontend repo                   - Skin_Lesion_Classification_frontend
research repo                   - Skin_Lesion_XAI_research
mobile repo (later)             - Skin_Lesion_Classification_mobile
```

What this map means: the root Makefile coordinates multiple project folders, while each repo-specific Makefile owns commands for that repo.

The root Makefile provides shortcuts across all of them. Each repo has its own Makefile for repo-specific commands.

## Rule

If it teaches, put it in docs.
If it repeats, put it in Makefile.
If it validates or automates, put it in scripts.

## Command Location

Run Makefile commands from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this does: moves your terminal to the root workspace where the root `Makefile` exists.

## Repo And File Map

- Root Makefile: `Makefile` in the main workspace.
- Backend Makefile: `Skin_Lesion_Classification_backend/Makefile`.
- Frontend Makefile: `Skin_Lesion_Classification_frontend/Makefile`.
- Research Makefile: `Skin_Lesion_XAI_research/Makefile`.
- Validation script: `scripts/docs-validate.ps1` in the main workspace.
- Run root commands from the main workspace. Run package-specific commands from the repo named in the step.

## Current Repo State

This project already has a root `Makefile`.

Do not create a second Makefile.
Do not replace the existing root Makefile.

First inspect it:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
Get-Content .\Makefile
make help
```

Expected result: `make help` prints commands such as:

```text
make backend-test
make frontend-build
make docs-check
make check
```

What this means: if those commands appear, the root Makefile already has the beginner testing menu this guide needs. You are reading it to understand it, not pasting a replacement.

## Root Makefile Reference

The root `Makefile` should look like this in shape. Treat this as a reference, not as a command to paste over the current file:

```makefile
# Root command menu for the full Skin Lesion workspace.

.PHONY: help backend-run backend-test backend-lint backend-typecheck frontend-dev frontend-build frontend-typecheck research-help docs-check check

BACKEND_DIR := Skin_Lesion_Classification_backend
FRONTEND_DIR := Skin_Lesion_Classification_frontend
RESEARCH_DIR := Skin_Lesion_XAI_research

help:
	@echo "Skin Lesion workspace commands"
	@echo "  make backend-test       - Run backend pytest"
	@echo "  make frontend-build     - Build the Next.js frontend"
	@echo "  make docs-check         - Check guide order, links, stale paths, and cloud doc gates"
	@echo "  make check              - Run local backend/frontend/docs checks"

backend-test:
	$(MAKE) -C $(BACKEND_DIR) test

frontend-build:
	$(MAKE) -C $(FRONTEND_DIR) build

docs-check:
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-validate.ps1
	@echo "docs-check ok"

check: backend-test backend-lint backend-typecheck frontend-typecheck frontend-build docs-check
```

What this root Makefile does:

- `.PHONY` marks command names that are not real output files.
- `BACKEND_DIR`, `FRONTEND_DIR`, and `RESEARCH_DIR` store folder paths.
- `help` prints the available commands.
- `check` runs the main local verification chain.
- `docs-check` runs the PowerShell docs validator.
- `backend-*`, `frontend-*`, and `research-help` delegate into subrepo Makefiles with `$(MAKE) -C`.
- `cloud-*` delegates cloud lifecycle commands into the Terraform folder with explicit environment variables.

Important: Makefile recipes must use tabs, not spaces.

If your current root Makefile already has these targets, do not edit it during this guide.

If `make help` does not show one of the required commands, edit this existing file:

```text
Makefile
```

What this path is: the root workspace Makefile. Add the missing target to this file only; do not create `Makefile.txt`, `makefile.md`, or a new Makefile in another folder.

## What Belongs In The Root Makefile

The root Makefile should contain only cross-project shortcuts:

```text
help
check
docs-check
backend-run
backend-test
backend-lint
backend-typecheck
frontend-dev
frontend-build
frontend-typecheck
research-help
cloud-status
cloud-start
cloud-pause
cloud-resume
cloud-shutdown
```

**What this list defines:** every Make target that the root Makefile exposes. If a `make <something>` command appears in any documentation file, the target must appear in this list and be implemented in the root Makefile. Targets not on this list belong in sub-repo Makefiles, not the root.

It should not contain long explanations. Long explanations belong in docs.

## Why Use ?= Instead Of :=

Some Makefiles use `?=` so paths can be overridden:

```powershell
make backend-test BACKEND_DIR=../Skin_Lesion_Classification_backend
```

What this does: runs `backend-test` while overriding the backend folder path for that command invocation only.

Current note: the root Makefile in this workspace may use `:=` for fixed local paths. That is okay for this beginner local setup because the backend and frontend repos are already cloned inside the main workspace. Use `?=` later only if you need to point the root Makefile at repos in a different folder.

The backend, frontend, and research repos may be cloned:

- inside the main repo as sibling folders
- or anywhere on disk with overridden paths

## What Belongs In Repo-Specific Makefiles

### Backend Repo Makefile

Location:

```text
Skin_Lesion_Classification_backend/Makefile
```

**What this path is:** the backend-specific Makefile. The root Makefile delegates to it via `$(MAKE) -C $(BACKEND_DIR) test` and similar patterns. Only backend-specific commands belong here - not workspace-wide shortcuts.

This file already exists in the current project. Inspect it:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
Get-Content .\Skin_Lesion_Classification_backend\Makefile
```

Expected result: it contains targets such as `setup`, `install`, `install-dev`, `run`, `test`, `lint`, and `typecheck`.

Only if one of those targets is missing, edit this existing file:

```text
Skin_Lesion_Classification_backend/Makefile
```

Reference shape:

```makefile
.PHONY: help setup install install-dev run test lint typecheck clean

help:
	@echo "Available targets:"
	@echo "  make run"
	@echo "  make test"
	@echo "  make lint"
	@echo "  make typecheck"

run:
	$(VENV_PYTHON) -m uvicorn app.main:app --reload --port 8000

test:
	$(VENV_PYTHON) -m pytest

lint:
	$(VENV_PYTHON) -m ruff check .

typecheck:
	$(VENV_PYTHON) -m mypy app/
```

What this backend Makefile does:

- `run` starts FastAPI through uvicorn.
- `test` runs pytest.
- `lint` runs Ruff checks.
- `typecheck` runs mypy on `app/`.
- `setup`, `install`, and `install-dev` manage Python dependencies.
- `clean` removes local generated environment/cache files.

### Frontend Repo Makefile

Location:

```text
Skin_Lesion_Classification_frontend/Makefile
```

**What this path is:** the frontend-specific Makefile. The root Makefile delegates to it via `$(MAKE) -C $(FRONTEND_DIR) build` and similar. Only Next.js and npm commands belong here.

This file already exists in the current project. Inspect it:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
Get-Content .\Skin_Lesion_Classification_frontend\Makefile
```

Expected result: it contains targets such as `install`, `dev`, `build`, `start`, `lint`, and `typecheck`.

Only if one of those targets is missing, edit this existing file:

```text
Skin_Lesion_Classification_frontend/Makefile
```

Reference shape:

```makefile
.PHONY: help install dev build start lint typecheck clean

help:
	@echo "Frontend commands"
	@echo "  make install"
	@echo "  make dev"
	@echo "  make build"
	@echo "  make start"
	@echo "  make lint"
	@echo "  make typecheck"

install:
	$(NPM) install

dev:
	$(NPM) run dev

build:
	$(NPM) run build

start:
	$(NPM) run start

lint:
	$(NPM) run lint

typecheck:
	$(NPM) run type-check
```

What this frontend Makefile does:

- `dev` starts the Next.js dev server.
- `build` creates a production build.
- `lint` runs the configured frontend linter.
- `typecheck` runs TypeScript without emitting files.
- `install` installs npm dependencies.
- `start` starts the built production app.

### Research Repo Makefile

Location:

```text
Skin_Lesion_XAI_research/Makefile
```

**What this path is:** the research-specific Makefile. The root Makefile delegates to it via `$(MAKE) -C $(RESEARCH_DIR) help`. Training, evaluation, and notebook commands belong here, not in the root.

Only create this file if the research repo is present and has no Makefile yet. If it already exists, inspect and preserve it first:

```makefile
.PHONY: help train evaluate notebook

help:
	@echo "Research commands"
	@echo "  make train"
	@echo "  make evaluate"
	@echo "  make notebook"

train:
	python run_training.py

evaluate:
	python scripts/evaluate.py

notebook:
	jupyter lab
```

What this research Makefile does:

- `train` runs model training.
- `evaluate` runs evaluation scripts.
- `notebook` starts Jupyter Lab for research exploration.

## First Check

Run:

```powershell
make help
make docs-check
```

What this does: first confirms the root command menu loads, then confirms the documentation validator passes.

Expected result:

```text
Skin Lesion workspace commands
  make backend-run        - Start FastAPI from the backend repo
  ...
docs-check ok
```

**What this confirms:** the root Makefile is syntactically correct, the `help` target prints the command menu, and the docs validator passes. If either fails, the Makefile has a tab/space issue or the docs validator found a problem in the documentation ordering.

## Troubleshooting

### Error: missing separator

```
Makefile: missing separator
```

Cause: A recipe line used spaces instead of a tab.

Fix: Use a real tab before command lines:

File path example:

```text
Makefile
```

```makefile
backend-test:
	$(MAKE) -C $(BACKEND_DIR) test
```

What this example shows: the line under `backend-test:` must begin with a real tab in an actual Makefile, even though Markdown may visually render it like spaces.

### Error: no rule to make target

```
make: *** No rule to make target 'backend-test'. Stop.
```

Cause: The target does not exist or the Makefile is malformed.

Fix: Run `make help` and check that the Makefile has real newlines.

### Error: backend folder not found

```
make: *** Skin_Lesion_Classification_backend: No such file or directory
```

Cause: Backend repo is not cloned where the root Makefile expects it.

Fix:

```powershell
git clone https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_backend
```

What this does: clones the backend repository into the current folder when it is missing.

Or override the path:

```powershell
make backend-test BACKEND_DIR=../Skin_Lesion_Classification_backend
```

What this does: tells the root Makefile to use a backend folder outside the default location.

## Rule For Docs Referencing Makefile Commands

Any command shown in docs as `make something` must exist in the Makefile.

Examples:

- If docs say `make docs-check`, root Makefile must have `docs-check`.
- If docs say `make backend-test`, root Makefile must have `backend-test`.
- If docs say `make frontend-build`, root Makefile must have `frontend-build`.

If the command is only an example and not implemented yet, label it clearly:

```text
Planned command, not implemented yet.
```

What this label does: prevents a learner from treating an example command as something that should already work.

## Before Committing Makefile Changes

- [ ] `make help` works
- [ ] `make docs-check` works
- [ ] `make backend-test` calls backend repo
- [ ] `make frontend-build` calls frontend repo
- [ ] paths can be overridden with `BACKEND_DIR=...`
- [ ] no Makefile recipe uses spaces instead of tabs
- [ ] docs only reference Makefile targets that exist

## Concepts You Just Touched

- [Immutable Infrastructure (6.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#65-immutable-infrastructure) - the Makefile is the precursor to a real CI pipeline
- [RED And USE Metrics (10.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#101-red-and-use-metrics) - tests are the first proxy for service health

## Questions You Should Be Able To Answer

1. Why does the root Makefile delegate to sub-repo Makefiles instead of doing the work directly?
2. What is the right exit code semantics for `make docs-check`? Why does it matter?
3. If a test fails, which Make target stops first - and why is that the right behaviour?
4. What is the difference between `make` targets and shell scripts? When should you reach for one vs the other on Windows?
5. Why is `.PHONY` important?

If you cannot answer any of these, re-read the Make basics section and the [Immutable Infra pattern](../reference/09_SYSTEM_DESIGN_PATTERNS.md#65-immutable-infrastructure).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `make: command not found` on Windows | Make not installed | use Chocolatey or the WSL Make |
| Target runs in wrong directory | missing `cd` in the recipe | check the recipe lines |
| Test target says "no tests ran" | pytest collection error or wrong path | run pytest directly with `-v` |
| Recipe works once, fails on rerun | side-effects in the recipe (files left over) | add a `clean` target |
| Make target passes locally, fails in CI | env or path difference | echo `Get-Location` and `$env:PATH` in the recipe |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** report status, pause compute, and optionally destroy all dev cloud resources. These commands themselves depend on the Makefile cloud targets being implemented.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** recreate and verify the dev environment before continuing.

If this guide was local-only, no cloud shutdown is needed.
