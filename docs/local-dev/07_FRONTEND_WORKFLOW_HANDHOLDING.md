# Frontend Workflow Handholding Guide

Use this after the backend mock analysis endpoint works.

The frontend subrepo also has a longer guide:

```text
Skin_Lesion_Classification_frontend/BUILD_FRONTEND.md
```

## Goal

Build the user flow:

```text
select image -> upload -> loading -> result -> explanation when available -> consent when available
```

What this flow means: the first frontend workflow should cover the user's full path through the private app, including waiting and error states, before adding dashboards or public pages.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Step 1 then navigates into the frontend repo.

After Step 1, run every frontend command in this guide from:

```text
Skin_Lesion_Classification_frontend
```

**What this means:** all npm commands, Next.js builds, and frontend file edits happen inside the frontend repo. Running them from the workspace root fails because `package.json` is not at the workspace root.

Every frontend file path in this guide is relative to `Skin_Lesion_Classification_frontend`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Frontend repo: `Skin_Lesion_Classification_frontend/`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit frontend `app/...`, `components/...`, and `lib/...` paths under `Skin_Lesion_Classification_frontend/`.
- Backend checks use `Skin_Lesion_Classification_backend/`; do not create frontend files inside the backend repo.

## Step 1: Enter Frontend Folder

```powershell
cd Skin_Lesion_Classification_frontend
```

What this does: moves your terminal into the Next.js frontend repo so npm and Makefile commands use the correct `package.json`.

Install:

```powershell
make install
```

What this does: installs frontend dependencies through the frontend Makefile.

Check:

```powershell
npm run build
```

What this does: runs the Next.js build directly through npm to prove the app compiles.

## Step 2: Create API Client

Create this file:

```text
lib/api.ts
```

**What this path is:** `lib/` is the frontend module for shared utilities and API client code. Putting all backend calls here keeps them out of page components and makes them easy to test and mock.

Paste:

```ts
export type AnalysisResponse = {
  case_id: string;
  prediction: string;
  confidence: number;
  explanation_available: boolean;
};

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

export async function analyzeImage(file: File): Promise<AnalysisResponse> {
  const formData = new FormData();
  formData.append("image", file);

  const response = await fetch(`${API_BASE_URL}/api/v1/analysis`, {
    method: "POST",
    body: formData,
  });

  if (!response.ok) {
    throw new Error("Image analysis failed");
  }

  return response.json();
}
```

What this API client does:

- `AnalysisResponse` defines the TypeScript shape expected from the backend.
- `API_BASE_URL` reads the browser-safe backend URL from `.env.local`, with a local fallback.
- `FormData` creates the multipart upload body expected by FastAPI.
- `formData.append("image", file)` uses the same field name as the backend route parameter.
- `fetch(..., { method: "POST", body: formData })` sends the image to `/api/v1/analysis`.
- `if (!response.ok)` turns non-2xx API responses into frontend errors.
- `return response.json()` gives the page typed response data to render.

Why: all backend calls live in one place.

## Step 3: Build Upload State

In the main page, track:

```text
selected file
loading
result
error
```

What these states mean:

- `selected file` stores what the user picked.
- `loading` prevents duplicate submits and shows progress.
- `result` stores the successful backend response.
- `error` stores validation or API failure copy.

Why: these are the states a real user experiences.

## Step 4: Manual Check

Open a terminal from the repo root and start the backend:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload
```

What this does: starts the backend API in one terminal so the frontend has a real local server to call.

Open a second terminal from the repo root and start the frontend:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_frontend
npm run dev
```

What this does: starts the Next.js development server in a second terminal while the backend keeps running in the first terminal.

Open:

```text
http://localhost:3000
```

**What this is:** the local Next.js dev server URL. Open it in a browser and try uploading an image to verify the full frontend-to-backend flow works end-to-end.

Upload an image.

If the page shows:

```text
Could not analyze the image. Failed to fetch
```

Check the backend first from a third terminal:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
Invoke-WebRequest -Uri http://localhost:8000/health -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:8000/api/v1/ready -UseBasicParsing
```

Expected result: both commands return status `200`.

If those checks pass but the browser still says `Failed to fetch`, restart the backend so FastAPI reloads the local CORS settings:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload
```

Expected result: uploading from `http://localhost:3000` can call `http://localhost:8000/api/v1/analysis`.

Why: the browser blocks frontend-to-backend calls unless the backend explicitly allows the frontend origin. The backend must allow `http://localhost:3000` for this local workflow.

## Step 5: Build Test Habit

Run:

```powershell
npm run build
```

What this does: compiles the frontend after your changes so TypeScript, routing, and Next.js build behavior are checked.

If you add a test framework later, first tests should cover:

- upload button exists
- file selection changes state
- API error shows error message
- successful response shows prediction

## Stop Point

Build doctor/admin dashboards only when the patient upload and result flow works and the guide sequence reaches `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md`.

Build public SEO and education pages only when the customer dashboard and privacy/consent flow are clear and the guide sequence reaches `local-dev/10_FRONTEND_SEO_HANDHOLDING.md`.

Why: the first frontend workflow should prove private app behavior. Public metadata, sitemap, robots rules, and Search Console setup come later so private patient, doctor, admin, lesion, lab-result, report, research, analytics, and API pages are not accidentally indexed.

## Concepts You Just Touched

- [Timeout Budget (2.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#24-timeout-budget) - frontend timeout sits OUTSIDE the backend budget
- [Backpressure (2.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#25-backpressure) - disable the upload button while in flight
- [Refusal Patterns (12.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#122-refusal-patterns) - error states must NOT imply diagnosis when the model fails
- [Output Validation (12.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#125-output-validation) - the result UI is the last line of defense against bad copy

## Questions You Should Be Able To Answer

1. Why do you build the loading state and error state BEFORE the happy path?
2. What is the right copy to show when the model is uncertain (high disagreement, low confidence)? Why not "we don't know"?
3. If the user navigates away during an upload, what should happen to the in-flight request?
4. What ARIA attributes does the result region need so it is screen-reader friendly?
5. Why is the Grad-CAM heatmap always shown WITH the original image, not alone?

If you cannot answer Q1-Q3, re-read the state-coverage section.
If you cannot answer Q4-Q5, read the Stitch shared brief in `../../Skin_Lesion_Classification_frontend/GOOGLE_STITCH_PROMPTS.md` and [System Design Patterns: 12.2 Refusal](../reference/09_SYSTEM_DESIGN_PATTERNS.md#122-refusal-patterns).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| User double-clicks Upload, two requests fire | button not disabled during in-flight state | upload component state |
| Result flashes "Error" then "Success" | race condition; old promise resolved last | abort previous request on new submit |
| Heatmap renders below the fold on mobile | layout assumes desktop viewport | inspect responsive breakpoints |
| Confidence shown as raw "0.9743" | no formatting; treats softmax as probability | format to "97%" and acknowledge it is model-estimated |
| Error state recommends "consult a doctor" only sometimes | conditional copy missing one branch | grep all error branches for safety language |

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
