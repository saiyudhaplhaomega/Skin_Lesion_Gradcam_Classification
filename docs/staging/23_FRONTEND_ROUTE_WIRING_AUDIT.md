# Frontend Route Wiring Audit

This guide records which frontend pages are live, partially wired, or intentionally not wired yet.

Run commands from:

```powershell
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

Frontend files live in:

```text
Skin_Lesion_Classification_frontend/
```

Backend files live in:

```text
Skin_Lesion_Classification_backend/
```

## Step 1: Inspect The Routes

Run from the frontend repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
Get-ChildItem -Path app -Recurse -Filter page.tsx | Select-Object -ExpandProperty FullName
```

Expected result: every Next.js route page is listed.

Why this choice was made: route inventory starts from real files so no page is missed.

## Step 2: Find Demo Or Static Data

Run from the frontend repo:

```powershell
rg -n "mock|dummy|placeholder|static|demo|sample|fake|const .* = \[|return \[|Math\.random|Coming soon|Not wired|not wired" app components lib --glob "*.ts" --glob "*.tsx"
```

Expected result: remaining matches should be public content arrays or explicit not-wired states, not fake clinical dashboard values.

Why this choice was made: the user-facing risk is fake clinical or operational numbers that look live.

## Current Route Inventory

| Route | Current state | Backend contract |
|---|---|---|
| `/` | static public marketing | no backend needed |
| `/about` | static public content | no backend needed |
| `/features` | static public content | no backend needed |
| `/how-it-works` | static public content | no backend needed |
| `/education` | static public education index | no backend needed |
| `/education/ai-limitations` | static public education | no backend needed |
| `/education/how-to-take-skin-lesion-photo` | static public education | no backend needed |
| `/education/what-is-gradcam` | static public education | no backend needed |
| `/privacy` | static public policy content | no backend needed yet |
| `/terms` | static public policy content | no backend needed |
| `/analyze` | real backend-wired, degraded by backend model state | `POST /api/v1/analysis`, `GET /api/v1/ready` |
| `/research` | partially wired | `GET /api/v1/research/metrics/dataset`, `GET /api/v1/research/active-learning/queue`; performance panel not shown yet |
| `/lab-results` | real backend-wired for list/upload | `GET/POST /api/v1/lab-results` |
| `/doctor/lab-results/[id]` | real backend-wired for OCR review, provider is manual stub | lab OCR endpoints under `/api/v1/lab-results/{id}` |
| `/dashboard` | real backend-wired with honest missing reminder state | `GET /api/v1/dashboard/summary`, `GET /api/v1/dashboard/activity` |
| `/lesions` | real backend-wired with honest missing consent/storage state | `GET /api/v1/lesions` |
| `/lesions/[lesionId]` | partially wired | `GET /api/v1/lesions/{id}`; timeline contract missing |
| `/body-map` | partially wired | `GET /api/v1/lesions`, body-location history; coordinate fields missing from response |
| `/doctor` | partially wired | `GET /api/v1/reviews/pending`; joined review packet contract missing |
| `/reports` | honest not-wired state | report packet APIs missing |
| `/reminders` | honest not-wired state | reminder APIs missing |
| `/admin` | honest not-wired state | admin metrics, audit, verification, flag APIs missing |
| `/analytics` | honest not-wired state | analytics-safe aggregate endpoints missing |
| `/ops` | honest not-wired state | telemetry and operations endpoints missing |
| `/admin/market-research` | static/admin prototype | market research RAG APIs missing |
| `/admin/market-research/briefs/[briefId]` | static/admin prototype | market research brief read API missing |
| `/admin/market-research/sources` | static/admin prototype | market research source API missing |
| `/agents` | static role/agent concept page | role-agent runtime APIs missing |
| `/xai-gradcam` | static XAI explainer | no backend needed yet |

## Missing Backend Contracts

Add these only after checking existing backend architecture in `Skin_Lesion_Classification_backend/app/api/v1/` and schemas in `Skin_Lesion_Classification_backend/app/schemas/`.

### Lesion Timeline

Needed by:

```text
Skin_Lesion_Classification_frontend/app/lesions/[lesionId]/page.tsx
```

Proposed endpoint:

```text
GET /api/v1/lesions/{lesion_id}/timeline
```

Response needs:

```json
{
  "lesion_id": "uuid",
  "events": [
    {
      "event_type": "analysis | doctor_review | body_location | consent | lab_result | report_export",
      "event_id": "uuid",
      "summary": "string",
      "occurred_at": "datetime",
      "actor_role": "patient | doctor | admin | system"
    }
  ]
}
```

Check command after implementing:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
make backend-test
```

Success looks like: backend tests pass and lesion detail can render a real event timeline.

### Body Map Coordinates

Needed by:

```text
Skin_Lesion_Classification_frontend/components/body-map/BodyMap2D.tsx
```

Current issue: `BodyLocationRecord` stores `body_map_x` and `body_map_y`, but `BodyLocationResponse` does not expose them.

Proposed response fields:

```json
{
  "body_map_x": 38.0,
  "body_map_y": 27.0
}
```

Check command after implementing:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
make backend-test
```

Success looks like: body map can plot pins only for records with real saved coordinates.

### Doctor Review Packet

Needed by:

```text
Skin_Lesion_Classification_frontend/components/doctor/DoctorCaseQueue.tsx
```

Proposed endpoint:

```text
GET /api/v1/reviews/{review_id}/packet
```

Response needs:

```json
{
  "review": {},
  "lesion": {},
  "latest_analysis": {},
  "image_quality": {},
  "gradcam": { "available": false, "overlay_url": null },
  "lab_results": [],
  "allowed_actions": ["add_note", "request_retake", "submit_decision"]
}
```

Success looks like: doctor page can show a selected real case without invented heatmaps, quality text, or action availability.

### Reports

Needed by:

```text
Skin_Lesion_Classification_frontend/app/reports/page.tsx
```

Proposed endpoints:

```text
POST /api/v1/reports
GET /api/v1/reports/{report_id}
POST /api/v1/reports/{report_id}/export
```

Success looks like: report export is audited and generated from real selected lesions and analysis records.

### Reminders

Needed by:

```text
Skin_Lesion_Classification_frontend/app/reminders/page.tsx
```

Proposed endpoints:

```text
GET /api/v1/reminders
POST /api/v1/reminders
PATCH /api/v1/reminders/{reminder_id}
```

Success looks like: reminder due dates are loaded from the backend, not hardcoded in the page.

### Admin, Analytics, And Ops

Needed by:

```text
Skin_Lesion_Classification_frontend/app/admin/page.tsx
Skin_Lesion_Classification_frontend/app/analytics/page.tsx
Skin_Lesion_Classification_frontend/app/ops/page.tsx
```

Proposed endpoint groups:

```text
GET /api/v1/admin/summary
GET /api/v1/admin/audit-events
GET /api/v1/admin/feature-flags
GET /api/v1/analytics/summary
GET /api/v1/ops/telemetry
```

Success looks like: no page shows fake counts for health, audit events, DLQ items, drift, fairness slices, or feature flags.

## Step 3: Verify Frontend Contracts

Run from the frontend repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
C:\Users\saiyu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe tests\api-contract-check.mjs
```

Expected result: no output and exit code 0.

Why this choice was made: the check catches endpoint drift where frontend routes call paths the backend does not expose.

Then run:

```powershell
$env:PATH='C:\Users\saiyu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin;' + $env:PATH
.\node_modules\.bin\tsc.cmd --noEmit
```

Expected result: TypeScript exits with code 0.

Why this choice was made: schema mismatches show up quickly as type errors when client types and page components are aligned.

## Step 4: Staging Resume Rule

Do not start the EKS backend only to inspect code.

Resume staging only when you are ready to test Vercel against live backend routes:

```powershell
kubectl scale deployment skin-lesion-backend --replicas=1 -n skin-lesion-staging
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-staging
```

Expected result: one backend pod is ready.

After testing, shut it down again:

```powershell
kubectl scale deployment skin-lesion-backend --replicas=0 -n skin-lesion-staging
kubectl get pods -n skin-lesion-staging
```

Expected result: the backend deployment returns to 0 running pods.

Why this choice was made: staging was intentionally scaled down before sleep, and cost controls come before convenience.
