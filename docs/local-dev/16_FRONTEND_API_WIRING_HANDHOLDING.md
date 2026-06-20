# Frontend API Wiring Handholding Guide

Use this after `docs/local-dev/07_FRONTEND_WORKFLOW_HANDHOLDING.md` and after the backend FastAPI app runs locally (you confirmed `curl http://localhost:8080/health` returns `{"status":"ok"}` in guide 06 setup).

This guide wires every frontend page that currently shows hardcoded mock data to its real backend endpoint. It extends `lib/api.ts` with all missing client methods and replaces each `Mock*` component with a real-data component that calls the API.

## Why This Guide Exists

After guide 07 the frontend has 33 pages and 29 components, but most pages render hardcoded mock data. Only `LabOcrReviewPanel.tsx` actually imports from `lib/api.ts`. The backend has 29 endpoints across 9 route files. Most of them have no frontend client yet.

| Backend endpoints | Frontend client methods | Coverage |
|-------------------|------------------------|----------|
| 29 | 5 | 17% |

This guide brings coverage to 100% by:

1. Extending `lib/api.ts` with the 24 missing client methods (split across this file and a new `lib/adminMarketResearchApi.ts` extension)
2. Replacing hardcoded mock arrays in each page with real API calls using the React `useEffect` + `useState` pattern
3. Adding loading and error states to every page that does not already have them

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

After Step 1, run every frontend command in this guide from:

```text
Skin_Lesion_Classification_frontend
```

**What this means:** all `npm`, `npx`, and `next` commands and every frontend file edit happens inside the frontend repo. Running them from the workspace root fails because `package.json` is not at the workspace root.

Backend API verification commands run from:

```text
Skin_Lesion_Classification_backend
```

## Account And Identity Map

This guide is **local-only**. No AWS account access is needed. No SSO login is needed. No Terraform commands are run.

```text
ENTER: Local terminal (no AWS account needed)
```

You stay in the local terminal for the entire guide.

## Prerequisites

Before Step 1, confirm all of these are done:

1. Guide 06 setup completed — the backend Docker image `skin-lesion-backend:local` runs and `curl http://localhost:8080/health` returns `{"status":"ok"}`.
2. The frontend has `node_modules` installed:
   ```powershell
   cd Skin_Lesion_Classification_frontend
   Test-Path node_modules
   ```
   Expected result: `True`. If `False`, run `make install` (or `npm install`) from the frontend repo root.
3. The backend listens on the URL the frontend expects. The frontend default in `lib/api.ts` line 8 is:
   ```typescript
   const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";
   ```
   Your backend container listens on port `8080` (per guide 01 `Dockerfile` and guide 06 deployment), so you must set `NEXT_PUBLIC_API_BASE_URL` to match. Verify and set it now:
   ```powershell
   $env:NEXT_PUBLIC_API_BASE_URL = "http://localhost:8080"
   ```
   **What this does:** tells the frontend client to send requests to port 8080 (the backend container port) instead of port 8000 (the default). Without this set, every API call returns a connection error.

If any of these are missing, complete guide 06 and guide 07 first, then return.

## Step 0: Verify The Backend API Responds

This step confirms the backend is reachable and the frontend URL matches the backend port.

In the backend terminal (where the Docker container is running), the expected log line should already show:

```text
INFO:     Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
```

Open a new PowerShell terminal for the verification commands:

```powershell
curl http://localhost:8080/api/v1/ready
```

Expected result:

```json
{"status":"ready"}
```

**What this result means:** the FastAPI app started successfully and registered all routers. The `/api/v1/ready` endpoint is defined in `Skin_Lesion_Classification_backend/app/api/v1/router.py:14`.

If you see `Connection refused`:

1. Confirm the Docker container is still running in Terminal A: `docker ps --filter ancestor=skin-lesion-backend:local`.
2. Confirm the container was started with `-p 8080:8080` (port mapping must match).
3. Confirm the backend `/health` works: `curl http://localhost:8080/health`. If `/health` works but `/api/v1/ready` returns 404, the backend was started before the routers were registered — rebuild and restart the container.

Do not continue until `curl http://localhost:8080/api/v1/ready` returns `{"status":"ready"}`.

## Step 1: Extend lib/api.ts With All Missing Client Methods

This step replaces `Skin_Lesion_Classification_frontend/lib/api.ts` with a complete client that covers all 29 backend endpoints.

Open this file:

```text
Skin_Lesion_Classification_frontend/lib/api.ts
```

In VS Code:
1. In the Explorer panel, navigate to `Skin_Lesion_Classification_frontend/lib/api.ts`.
2. Click the file to open it in the editor tab.
3. Select all the existing content with `Ctrl+A`.
4. Delete it with `Delete`.
5. Copy the TypeScript block below and paste it into the empty editor tab.
6. Press `Ctrl+S` to save.

Replace the file contents with:

```typescript
// ---------------------------------------------------------------------------
// lib/api.ts - Complete client for the backend FastAPI.
// All 29 backend endpoints are wrapped by exported client methods below.
// Every method targets the URL in API_BASE_URL (env var NEXT_PUBLIC_API_BASE_URL).
// ---------------------------------------------------------------------------

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080";

// ---------- Shared types ----------

export type AnalysisResponse = {
  case_id: string;
  prediction: string;
  confidence: number;
  explanation_available: boolean;
};

export type ExplanationResponse = {
  analysis_id: string;
  gradcam_overlay_url: string;
  explanation_text: string;
  confidence: number;
  top_features: { name: string; weight: number }[];
};

export type LesionResponse = {
  id: string;
  patient_id: string;
  body_location: string | null;
  first_seen_date: string | null;
  status: string;
  created_at: string;
};

export type LesionListResponse = {
  total: number;
  items: LesionResponse[];
};

export type BodyLocationResponse = {
  id: string;
  lesion_id: string;
  region: string;
  coordinates: { x: number; y: number };
  recorded_at: string;
  status: string;
};

export type DashboardSummaryResponse = {
  total_analyses: number;
  pending_consent: number;
  approved_for_training: number;
  flagged_for_review: number;
};

export type DashboardActivityItem = {
  timestamp: string;
  type: string;
  description: string;
};

export type DashboardActivityResponse = {
  items: DashboardActivityItem[];
};

export type DoctorReviewResponse = {
  id: string;
  lesion_id: string;
  reviewer_id: string;
  status: string;
  notes: string | null;
  created_at: string;
};

export type LabResultResponse = {
  id: string;
  lesion_id: string | null;
  test_date: string | null;
  lab_name: string | null;
  file_type: string;
  status: string;
  patient_note: string | null;
  doctor_note: string | null;
  consent_to_share_with_doctor: boolean;
  created_at: string;
};

export type LabExtractedValueResponse = {
  id: string;
  extraction_run_id: string;
  name: string;
  value: string;
  unit: string | null;
  confidence: number;
  review_status: string;
  reviewed_value: string | null;
  reviewed_unit: string | null;
  review_note: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
};

export type LabExtractionRunResponse = {
  id: string;
  lab_result_id: string;
  provider: string;
  status: string;
  created_at: string;
  reviewed_at: string | null;
  values: LabExtractedValueResponse[];
};

export type LabOcrReviewPageResponse = {
  lab_result: LabResultResponse;
  run: LabExtractionRunResponse;
};

export type LabOcrReviewPayload = {
  review_status: "accepted" | "edited" | "rejected";
  reviewed_value?: string;
  reviewed_unit?: string;
  review_note?: string;
};

export type ResearchDatasetMetrics = {
  total_cases: number;
  approved_cases: number;
  rejected_cases: number;
  pending_review: number;
};

export type ModelPerformanceMetrics = {
  accuracy: number;
  precision: number;
  recall: number;
  f1: number;
  evaluated_at: string;
};

export type ActiveLearningQueueItem = {
  case_id: string;
  confidence: number;
  predicted_class: string;
  reason: string;
};

export type ActiveLearningQueue = {
  items: ActiveLearningQueueItem[];
};

// ---------- Internal helper ----------

async function apiJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });

  if (!response.ok) {
    throw new Error(`API request failed: ${response.status} ${path}`);
  }

  return response.json();
}

async function apiFormData<T>(path: string, formData: FormData): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`API request failed: ${response.status} ${path}`);
  }

  return response.json();
}

// ---------- Analysis and explanation ----------

export async function analyzeImage(file: File): Promise<AnalysisResponse> {
  const formData = new FormData();
  formData.append("image", file);
  return apiFormData<AnalysisResponse>("/api/v1/analysis", formData);
}

export async function getReady(): Promise<{ status: string }> {
  return apiJson<{ status: string }>("/api/v1/ready");
}

export async function getAnalysisExplanation(
  caseId: string,
): Promise<ExplanationResponse> {
  return apiJson<ExplanationResponse>(`/api/v1/analysis/${caseId}/explanation`);
}

export async function explainWithLlm(
  analysisId: string,
): Promise<ExplanationResponse> {
  return apiJson<ExplanationResponse>(
    `/api/v1/explain-llm/${analysisId}`,
    { method: "POST" },
  );
}

// ---------- Lesions ----------

export async function createLesion(payload: {
  body_location?: string;
  first_seen_date?: string;
}): Promise<LesionResponse> {
  return apiJson<LesionResponse>("/api/v1/lesions", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function listLesions(): Promise<LesionListResponse> {
  return apiJson<LesionListResponse>("/api/v1/lesions");
}

export async function getLesion(lesionId: string): Promise<LesionResponse> {
  return apiJson<LesionResponse>(`/api/v1/lesions/${lesionId}`);
}

// ---------- Body mapping ----------

export async function createBodyLocation(
  lesionId: string,
  payload: { region: string; coordinates: { x: number; y: number } },
): Promise<BodyLocationResponse> {
  return apiJson<BodyLocationResponse>(
    `/api/v1/lesions/${lesionId}/body-location`,
    { method: "POST", body: JSON.stringify(payload) },
  );
}

export async function getBodyLocationHistory(
  lesionId: string,
): Promise<BodyLocationResponse[]> {
  return apiJson<BodyLocationResponse[]>(
    `/api/v1/lesions/${lesionId}/body-location/history`,
  );
}

export async function approveBodyLocation(
  lesionId: string,
  locationId: string,
): Promise<{ status: string }> {
  return apiJson<{ status: string }>(
    `/api/v1/lesions/${lesionId}/body-location/${locationId}/approve`,
    { method: "POST" },
  );
}

export async function correctBodyLocation(
  lesionId: string,
  locationId: string,
  payload: { region: string },
): Promise<BodyLocationResponse> {
  return apiJson<BodyLocationResponse>(
    `/api/v1/lesions/${lesionId}/body-location/${locationId}/correct`,
    { method: "POST", body: JSON.stringify(payload) },
  );
}

// ---------- Dashboard ----------

export async function getDashboardSummary(): Promise<DashboardSummaryResponse> {
  return apiJson<DashboardSummaryResponse>("/api/v1/dashboard/summary");
}

export async function getDashboardActivity(): Promise<DashboardActivityResponse> {
  return apiJson<DashboardActivityResponse>("/api/v1/dashboard/activity");
}

// ---------- Doctor reviews ----------

export async function listPendingDoctorReviews(): Promise<DoctorReviewResponse[]> {
  return apiJson<DoctorReviewResponse[]>("/api/v1/doctor-reviews/pending");
}

export async function createDoctorReview(payload: {
  lesion_id: string;
  notes: string;
}): Promise<DoctorReviewResponse> {
  return apiJson<DoctorReviewResponse>("/api/v1/doctor-reviews", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function getDoctorReview(
  reviewId: string,
): Promise<DoctorReviewResponse> {
  return apiJson<DoctorReviewResponse>(`/api/v1/doctor-reviews/${reviewId}`);
}

export async function getDoctorReviewLabResults(
  reviewId: string,
): Promise<LabResultResponse[]> {
  return apiJson<LabResultResponse[]>(
    `/api/v1/doctor-reviews/${reviewId}/lab-results`,
  );
}

// ---------- Lab results ----------

export async function createLabResult(payload: {
  lesion_id?: string;
  lab_name?: string;
  test_date?: string;
  patient_note?: string;
}): Promise<LabResultResponse> {
  return apiJson<LabResultResponse>("/api/v1/lab-results", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function listLabResults(): Promise<LabResultResponse[]> {
  return apiJson<LabResultResponse[]>("/api/v1/lab-results");
}

export async function getLabResult(
  labResultId: string,
): Promise<LabResultResponse> {
  return apiJson<LabResultResponse>(`/api/v1/lab-results/${labResultId}`);
}

export async function updateLabResult(
  labResultId: string,
  payload: Partial<LabResultResponse>,
): Promise<LabResultResponse> {
  return apiJson<LabResultResponse>(`/api/v1/lab-results/${labResultId}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}

export async function deleteLabResult(labResultId: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/api/v1/lab-results/${labResultId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    throw new Error(`API request failed: ${response.status}`);
  }
}

export async function addDoctorReviewToLabResult(
  labResultId: string,
  payload: { reviewer_id: string; notes: string },
): Promise<LabResultResponse> {
  return apiJson<LabResultResponse>(
    `/api/v1/lab-results/${labResultId}/doctor-review`,
    { method: "PATCH", body: JSON.stringify(payload) },
  );
}

export async function getLatestLabOcrRun(
  labResultId: string,
): Promise<LabOcrReviewPageResponse> {
  return apiJson<LabOcrReviewPageResponse>(
    `/api/v1/lab-results/${labResultId}/ocr-runs/latest`,
  );
}

export async function createLabOcrRun(
  labResultId: string,
): Promise<LabExtractionRunResponse> {
  return apiJson<LabExtractionRunResponse>(
    `/api/v1/lab-results/${labResultId}/ocr-runs`,
    { method: "POST" },
  );
}

export async function reviewLabOcrValue(
  labResultId: string,
  valueId: string,
  payload: LabOcrReviewPayload,
): Promise<LabExtractedValueResponse> {
  return apiJson<LabExtractedValueResponse>(
    `/api/v1/lab-results/${labResultId}/ocr-values/${valueId}/review`,
    { method: "PATCH", body: JSON.stringify(payload) },
  );
}

// ---------- Research metrics ----------

export async function getDatasetMetrics(): Promise<ResearchDatasetMetrics> {
  return apiJson<ResearchDatasetMetrics>("/api/v1/research/metrics/dataset");
}

export async function getModelPerformanceMetrics(): Promise<ModelPerformanceMetrics> {
  return apiJson<ModelPerformanceMetrics>("/api/v1/research/metrics/performance");
}

export async function getActiveLearningQueue(): Promise<ActiveLearningQueue> {
  return apiJson<ActiveLearningQueue>("/api/v1/research/active-learning/queue");
}
```

**What this file does:** defines one exported TypeScript function per backend endpoint. Every function takes the path parameters it needs (lesion ID, lab result ID, etc.) and returns a typed response. Errors throw an `Error` object with the HTTP status code and path so the calling component can show a useful error message.

**What each section does:**

- **Shared types** — TypeScript interfaces matching the Pydantic response models on the backend. Field names use snake_case to match the JSON wire format.
- **`apiJson` helper** — wraps `fetch` with JSON content-type headers and throws on non-OK responses. Used by every method that does not send a file upload.
- **`apiFormData` helper** — same as `apiJson` but for `multipart/form-data` requests (image uploads).
- **Analysis and explanation** — `analyzeImage` (POST), `getReady` (GET), `getAnalysisExplanation` (GET), `explainWithLlm` (POST).
- **Lesions** — `createLesion`, `listLesions`, `getLesion`.
- **Body mapping** — `createBodyLocation`, `getBodyLocationHistory`, `approveBodyLocation`, `correctBodyLocation`.
- **Dashboard** — `getDashboardSummary`, `getDashboardActivity`.
- **Doctor reviews** — `listPendingDoctorReviews`, `createDoctorReview`, `getDoctorReview`, `getDoctorReviewLabResults`.
- **Lab results** — full CRUD plus OCR review endpoints.
- **Research metrics** — dataset metrics, model performance, active learning queue.

**Why `API_BASE_URL` reads from `process.env.NEXT_PUBLIC_API_BASE_URL`:** Next.js bakes any env var starting with `NEXT_PUBLIC_` into the client-side bundle at build time. Setting it to `http://localhost:8080` makes the browser send API requests to the backend port (8080) instead of the default (8000). The default in this file is now `http://localhost:8080` which matches your backend container, but you should still set the env var explicitly to make the intent clear.

Save the file with `Ctrl+S`. Verify the file has no syntax errors before continuing:

```powershell
npx tsc --noEmit
```

**What this does:** runs the TypeScript compiler in check-only mode. It reports any type errors without producing output files.

Expected result: no output (exit code 0). If TypeScript reports errors, the most common cause is a missing import or a typo in a field name. Read the error message and fix the line it points to.

## Step 2: Replace Mock Data With Live API Calls

This step converts each page that currently shows hardcoded data into a client component that calls the API.

### Pattern For Every Page

Every data-driven page follows the same pattern. Use this for each page below.

1. **Open the page file** at the path shown in the step.
2. **Add `"use client"`** at the very top of the file (line 1). This tells Next.js to render the page in the browser so it can use hooks like `useState` and `useEffect`.
3. **Replace the imports** with the API client import plus React hooks.
4. **Replace the static data** (hardcoded arrays inside JSX) with state, an effect, and conditional rendering for loading and error states.

Use this template for every page. Replace the page name, import list, and state types with the ones specific to your page:

```typescript
"use client";

import { useEffect, useState } from "react";
import { /* API methods specific to this page */ } from "@/lib/api";

// Page-specific component imports below

export default function PageName() {
  const [data, setData] = useState<DataType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    apiMethod()
      .then((result) => {
        if (!cancelled) setData(result);
      })
      .catch((err: Error) => {
        if (!cancelled) setError(err.message);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) return <LoadingState />;
  if (error) return <ErrorState message={error} />;
  if (!data) return <EmptyState />;

  return <RealDataView data={data} />;
}
```

**What this template does:**

- `useState<DataType | null>(null)` — the data starts as null. Once the API responds, it is filled with the real response.
- `useState(true)` for `loading` — the page shows a loading indicator until the first API call resolves.
- `useState<string | null>(null)` for `error` — if the API throws, the error message is stored here for display.
- `useEffect` with empty dependency array — fires once when the page mounts, calls the API method, and stores the result.
- The `cancelled` flag prevents state updates if the user navigates away before the API responds.
- The three conditional renders — loading, error, empty — give the user a clear UI for every state. Skipping any of these is how production apps end up showing blank screens during outages.

### Step 2.1: Analyze Page (`/analyze`)

Path: `Skin_Lesion_Classification_frontend/app/analyze/page.tsx`

Open the file. Add `"use client"` at line 1. Replace the import of `MockAnalyzeFlow` with the real flow that calls `analyzeImage` from `lib/api.ts`. Replace the JSX inside `AnalyzePage` with the loading/error/result pattern above. The mock component is replaced with a real one that calls the API and shows the Grad-CAM response when available.

### Step 2.2: Lesions Pages (`/lesions`, `/lesions/[lesionId]`)

Path: `Skin_Lesion_Classification_frontend/app/lesions/page.tsx` and `Skin_Lesion_Classification_frontend/app/lesions/[lesionId]/page.tsx`

Add `"use client"` to each. Replace the static table with `listLesions()` and `getLesion(id)`. Use the loading/error pattern.

### Step 2.3: Body Map Page (`/body-map`)

Path: `Skin_Lesion_Classification_frontend/app/body-map/page.tsx`

Add `"use client"`. Replace the static `BodyMap2D` rendering with one that takes a real lesion list from `listLesions()` and lets the user click to create a body location via `createBodyLocation()`. The existing `components/body-map/BodyMap2D.tsx` becomes a presentation component that receives lesion coordinates as props.

### Step 2.4: Dashboard (`/dashboard`)

Path: `Skin_Lesion_Classification_frontend/app/dashboard/page.tsx`

Add `"use client"`. Replace the hardcoded `StatGrid` numbers with `getDashboardSummary()` and the activity timeline with `getDashboardActivity()`.

### Step 2.5: Reports and XAI (`/reports`, `/xai-gradcam`)

Path: `Skin_Lesion_Classification_frontend/app/reports/page.tsx` and `Skin_Lesion_Classification_frontend/app/xai-gradcam/page.tsx`

Add `"use client"`. The reports page reads analyses via `analyzeImage` history. The XAI page calls `getAnalysisExplanation(caseId)` and `explainWithLlm(analysisId)`. Both need a lesion selected first; pull the lesion list with `listLesions()` and add a selector at the top.

### Step 2.6: Doctor Queue (`/doctor`)

Path: `Skin_Lesion_Classification_frontend/app/doctor/page.tsx`

Add `"use client"`. Replace the static case queue with `listPendingDoctorReviews()`. Replace the per-case details with `getDoctorReview(id)` and `getDoctorReviewLabResults(id)` on click.

### Step 2.7: Doctor Lab Results Detail (`/doctor/lab-results/[id]`)

Path: `Skin_Lesion_Classification_frontend/app/doctor/lab-results/[id]/page.tsx`

Add `"use client"`. Replace the static lab display with `getLabResult(id)` and `getLatestLabOcrRun(id)`. Use the existing `LabOcrReviewPanel.tsx` component for the OCR values section since it already calls `reviewLabOcrValue`.

### Step 2.8: Patient Lab Results (`/lab-results`)

Path: `Skin_Lesion_Classification_frontend/app/lab-results/page.tsx`

Add `"use client"`. Replace the static upload/list UI with `listLabResults()` and `createLabResult()` plus the existing `LabResultUpload.tsx` and `LabResultList.tsx` components (update them to call `createLabResult` on submit).

### Step 2.9: Research Pages (`/research`, `/analytics`, `/agents`, `/ops`)

Path: `Skin_Lesion_Classification_frontend/app/research/page.tsx`, `app/analytics/page.tsx`, `app/agents/page.tsx`, `app/ops/page.tsx`

Add `"use client"` to each. Replace hardcoded metrics with `getDatasetMetrics()`, `getModelPerformanceMetrics()`, and `getActiveLearningQueue()`.

### Step 2.10: Admin Pages (`/admin`, `/admin/market-research`, sources, briefs)

Path: `Skin_Lesion_Classification_frontend/app/admin/page.tsx`, `app/admin/market-research/page.tsx`, `app/admin/market-research/sources/page.tsx`, `app/admin/market-research/briefs/[briefId]/page.tsx`

Add `"use client"` to each. The admin market research API client is in `Skin_Lesion_Classification_frontend/lib/adminMarketResearchApi.ts` and currently only has types. Extend it with the methods:

- `listMarketResearchBriefs()` → `GET /api/v1/admin/market-research/briefs`
- `createMarketResearchBrief(payload)` → `POST /api/v1/admin/market-research/briefs`
- `getMarketResearchBrief(id)` → `GET /api/v1/admin/market-research/briefs/{id}`
- `listMarketResearchSources()` → `GET /api/v1/admin/market-research/sources`
- `createMarketResearchSource(payload)` → `POST /api/v1/admin/market-research/sources`

Then wire each admin page to use these methods.

## Step 3: Add Loading And Error UI Components

The pages above need consistent loading and error components. Add these two files:

`Skin_Lesion_Classification_frontend/components/app/LoadingState.tsx`:

```typescript
export function LoadingState({ label = "Loading..." }: { label?: string }) {
  return (
    <div className="app-card" role="status" aria-live="polite">
      <p>{label}</p>
    </div>
  );
}
```

`Skin_Lesion_Classification_frontend/components/app/ErrorState.tsx`:

```typescript
export function ErrorState({ message }: { message: string }) {
  return (
    <div className="app-card app-card--error" role="alert">
      <h3>Something went wrong</h3>
      <p>{message}</p>
      <p>Check that the backend is running and NEXT_PUBLIC_API_BASE_URL points to it.</p>
    </div>
  );
}
```

These match the existing `ClinicalAppShell` style classes so they blend with the rest of the UI.

## Step 4: Verify With Type Check And Build

After all pages are wired, verify nothing is broken:

```powershell
cd Skin_Lesion_Classification_frontend
npx tsc --noEmit
npm run build
```

**What these commands do:**

- `npx tsc --noEmit` — type-check the whole project without producing output files. Surfaces missing imports, wrong argument types, and undefined references.
- `npm run build` — run the full Next.js production build. Catches any runtime errors that the type checker missed, like dynamic imports or static export issues.

Expected result:

```text
Type check: no output, exit code 0.
Build: Route (app) compiled successfully. All pages generated without errors.
```

If the type check or build fails:

1. Read the first error message — it usually points to a specific file and line.
2. Common cause: an imported API method that does not exist in `lib/api.ts`. Confirm the method name matches exactly (TypeScript is case-sensitive).
3. Common cause: a component import that does not exist yet because you skipped a step. Either complete the skipped step or remove the import.

## Step 5: Run The Frontend And Test Live Calls

Start the Next.js dev server:

```powershell
cd Skin_Lesion_Classification_frontend
npm run dev
```

Expected output:

```text
- ready started server on 0.0.0.0:3000, url: http://localhost:3000
```

Open `http://localhost:3000/analyze` in a browser. Upload a test image. The page should:

1. Show the loading state briefly.
2. Replace the loading state with the real result from `analyzeImage` (case_id, prediction, confidence).
3. If the backend returns 404, the error state shows the message — check the backend is running and the env var is set.

Open `http://localhost:3000/dashboard`. The stat grid should show real numbers from `getDashboardSummary()`.

Open `http://localhost:3000/research`. The metrics should reflect `getDatasetMetrics()` and `getModelPerformanceMetrics()`.

If any page shows hardcoded numbers or "Loading..." that never resolves, the wiring for that page did not save correctly. Open the page file and verify it has `"use client"` at the top and the API method call inside `useEffect`.

## Stop Point

Once all 20 data-driven pages fetch from the API and the build passes, this guide is complete. The next step is to add tests, which is covered in `local-dev/11_FULL_PROJECT_TEST_PLAN.md`.

## Record What Was Changed

After this guide, these frontend files were modified:

```text
lib/api.ts                                              - replaced with full client (29 methods)
lib/adminMarketResearchApi.ts                           - extended with 5 admin methods
components/app/LoadingState.tsx                         - new
components/app/ErrorState.tsx                           - new
app/analyze/page.tsx                                    - wired to analyzeImage
app/lesions/page.tsx                                    - wired to listLesions
app/lesions/[lesionId]/page.tsx                         - wired to getLesion
app/body-map/page.tsx                                   - wired to createBodyLocation
app/dashboard/page.tsx                                  - wired to getDashboardSummary
app/reports/page.tsx                                    - wired to listLesions + analysis history
app/xai-gradcam/page.tsx                                - wired to getAnalysisExplanation
app/doctor/page.tsx                                     - wired to listPendingDoctorReviews
app/doctor/lab-results/[id]/page.tsx                    - wired to getLabResult + getLatestLabOcrRun
app/lab-results/page.tsx                                - wired to listLabResults + createLabResult
app/research/page.tsx                                   - wired to getDatasetMetrics
app/analytics/page.tsx                                  - wired to getModelPerformanceMetrics
app/agents/page.tsx                                     - wired to getActiveLearningQueue
app/ops/page.tsx                                        - wired to getActiveLearningQueue
app/admin/page.tsx                                      - wired to admin endpoints
app/admin/market-research/page.tsx                      - wired to listMarketResearchBriefs
app/admin/market-research/sources/page.tsx              - wired to listMarketResearchSources
app/admin/market-research/briefs/[briefId]/page.tsx     - wired to getMarketResearchBrief
```

## Cost Pause / Resume

This guide is **local-only**. No cloud resources are created. No cost pause is needed. The Docker container from guide 06 keeps running and incurs no cloud cost.
