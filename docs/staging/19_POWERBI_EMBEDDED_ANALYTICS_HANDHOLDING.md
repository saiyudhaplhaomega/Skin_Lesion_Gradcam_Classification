# Power BI Embedded Analytics Handholding Guide

Use this after native doctor, admin, research, model monitoring, consent, and lab-result workflows exist.

Power BI is an embedded analytics module for internal and reviewer dashboards. It must not replace the patient or customer dashboard.

## Current Project Implementation

Guide 19 now has the backend contract and analytics-safe view definitions, but it does not create a live Power BI workspace.

Files created or edited:

```text
Skin_Lesion_Classification_backend/app/api/v1/analytics.py
Skin_Lesion_Classification_backend/app/core/powerbi_config.py
Skin_Lesion_Classification_backend/app/schemas/analytics_schema.py
Skin_Lesion_Classification_backend/app/services/powerbi_embed_service.py
Skin_Lesion_Classification_backend/app/db/analytics_views.sql
Skin_Lesion_Classification_backend/alembic/versions/j5k6l7m8n930_add_analytics_safe_views.py
Skin_Lesion_Classification_backend/tests/test_powerbi_embed_service.py
Skin_Lesion_Classification_frontend/app/analytics/page.tsx
```

Existing frontend state:

```text
Skin_Lesion_Classification_frontend/app/analytics/page.tsx
```

**What this means:** the frontend already has a non-indexed analytics shell. I did not install Power BI frontend packages yet because that would modify the existing dirty frontend lockfile and requires real Power BI workspace/report IDs to verify meaningfully.

Current backend endpoints:

```text
GET /api/v1/analytics/powerbi/admin-embed-token
GET /api/v1/analytics/powerbi/doctor-embed-token
GET /api/v1/analytics/powerbi/research-embed-token
```

Current local check:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests/test_powerbi_embed_service.py -v
```

Expected result:

```text
admin embed config shape passes with local stub settings
doctor is rejected from admin report
unknown/unauthorized analytics role is rejected
```

Why: this proves the backend contract and role gate before a real Azure app registration or Power BI workspace exists.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Makefile checks and AWS CLI commands run from here.

Backend files belong in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** analytics API routes, embed token service, and Alembic migrations for analytics views are Python code in the backend repo. `cd Skin_Lesion_Classification_backend` before creating or testing those files.

Frontend files belong in:

```text
Skin_Lesion_Classification_frontend
```

**What this means:** Power BI embed components and analytics page routes are frontend code. `cd Skin_Lesion_Classification_frontend` before creating or building those files.

Power BI setup happens in the Microsoft Power BI workspace.

## Goal

Add Embedded Analytics for:

```text
admin analytics
doctor review analytics
research dataset monitoring
model performance monitoring
image quality monitoring
body-location verification monitoring
consent and privacy monitoring
lab-result review monitoring
operations monitoring
```

**What these use cases have in common:** they are internal and professional audiences - admins, doctors, researchers - who need aggregated operational data to do their jobs. None of them are patient-facing.

Do not use Power BI for:

```text
patient dashboard
customer lesion timeline
body map interaction
privacy center
medical wording shown to patients
```

**Why these are excluded:** patients need a purpose-built experience with controlled language and no risk of accidentally exposing analytics data. Power BI's generic interface is designed for data analysts, not patients receiving health information. Building patient-facing features in Power BI creates compliance risk and poor UX.

Why: patient UX needs tighter control, calmer language, and fewer chances to expose analytics data.

## Step 1: Privacy Rules

Power BI must consume analytics-safe data only.

Do not expose these fields in Power BI views by default:

```text
patient name
patient email
raw image URL
lab report file URL
free-text doctor note
free-text patient note
exact personal identifier
unnecessary personal data
```

**Why these are excluded:** raw image URLs and lab report URLs are direct links to patient medical data - exposing them in a report means any analyst with report access can download patient files. Free-text notes can contain personal details that defeat pseudonymization. Patient name and email are direct identifiers that break GDPR and HIPAA de-identification.

Allowed analytics fields:

```text
aggregated counts
pseudonymous IDs
model version
dataset version
status fields
quality scores
triage categories
consent status
body-region category
doctor-verification status
storage mode
created month
```

**What makes these safe:** aggregated counts contain no individual identity. Pseudonymous IDs allow tracking a case through the pipeline without linking to a patient. Model version, quality scores, and status fields describe the system's behavior, not the patient. Created month (not date) reduces re-identification risk from timing correlations.

Check:

```powershell
make docs-check
```

**What this does:** runs the documentation readiness checks to confirm the privacy rule is recorded before any Power BI dataset or view is created.

Expected result:

```text
the privacy rule is documented before any Power BI dataset is created
```

**What this means:** the privacy exclusion list is written down and verified before any analytics SQL is written. Creating views first and documenting privacy rules later is the wrong order.

## Step 2: Analytics-Safe Views

Current repo:

```text
Skin_Lesion_Classification_backend
```

When this step is reached, create an Alembic migration for views such as:

```text
analytics_analysis_summary
analytics_lesion_summary
analytics_consent_summary
analytics_doctor_review_summary
analytics_lab_result_summary
analytics_storage_summary
analytics_model_version_summary
```

Current implemented view definitions:

```text
analytics_prediction_summary
analytics_consent_summary
analytics_doctor_review_summary
analytics_lab_result_summary
analytics_training_workflow_summary
```

These are stored in:

```text
Skin_Lesion_Classification_backend/app/db/analytics_views.sql
Skin_Lesion_Classification_backend/alembic/versions/j5k6l7m8n930_add_analytics_safe_views.py
```

**What these views do:** each view is a PostgreSQL `CREATE VIEW` that selects only privacy-safe columns from the underlying tables. Power BI connects to these views, not to the raw tables. This means even if a Power BI user tries to browse the schema, they only see what the view exposes.

Example view shape:

File path for the SQL view definition:

```text
Skin_Lesion_Classification_backend/app/db/analytics_views.sql
```

```sql
CREATE VIEW analytics_analysis_summary AS
SELECT
  ae.id AS analysis_id,
  ae.created_at,
  ae.prediction_label,
  ae.confidence,
  ae.calibrated_confidence,
  ae.triage_level,
  ae.model_version,
  ae.preprocessing_version,
  ae.gradcam_method,
  ae.image_quality_score,
  ae.blur_score,
  ae.lighting_score,
  ae.glare_score,
  l.body_location_status,
  i.storage_mode
FROM analysis_events ae
JOIN lesions l ON ae.lesion_id = l.id
LEFT JOIN images i ON ae.image_id = i.id;
```

**What this view exposes:** model performance data (prediction label, confidence, triage level, model version, Grad-CAM method) and image quality metrics (blur, lighting, glare scores). No patient identifiers, no image URLs, no notes. The JOIN to `lesions` adds body location status. The LEFT JOIN to `images` adds storage mode without making it required.

Lab result view rule:

```sql
CREATE VIEW analytics_lab_result_summary AS
SELECT
  id AS lab_result_id,
  lesion_id,
  file_type,
  status,
  test_date,
  created_at,
  updated_at
FROM lab_results;
```

**What this view exposes:** lab result metadata (type, status, dates) only. No file URL, no patient note, no doctor note.

Do not include:

```text
file_url
patient_note
doctor_note
```

**Why these three are excluded:** `file_url` is a direct link to a patient medical document. `patient_note` and `doctor_note` are free-text fields that can contain personally identifying information.

Check:

```powershell
cd Skin_Lesion_Classification_backend
pytest
```

**What this does:** runs the backend test suite to verify that the Alembic migration creating the analytics views runs without error and that any tests covering the view schema pass.

Expected result:

```text
analytics views are migration-controlled and exclude raw medical files and notes
```

**What this means:** the views are created through Alembic (version-controlled) and the excluded fields are confirmed absent from the view definitions.

## Step 3: Power BI Report Pages

Create one Power BI report with pages:

```text
Overview
AI Analysis
Model Performance
Image Quality
Doctor Reviews
Body Location Verification
Consent & Privacy
Lab Results
Research Dataset
Operations
```

**What these pages cover:** `Overview` is a high-level summary across all metrics. `AI Analysis` shows per-prediction confidence and triage distribution. `Model Performance` tracks model version metrics over time. `Image Quality` monitors blur, lighting, and glare scores. `Doctor Reviews` shows review throughput and correction rates. `Body Location Verification` tracks how often body regions are verified vs. left unverified. `Consent & Privacy` shows consent status distribution. `Lab Results` monitors OCR extraction status. `Research Dataset` tracks approved training data counts by label and dataset version. `Operations` shows API latency, error rates, and queue depths.

MVP pages:

```text
Overview
Research Dataset
Model Performance
Image Quality
Doctor Reviews
```

**What these five cover first:** the minimum set to verify the analytics pipeline works and to answer the most critical operational questions (how is the model performing, is the training data building correctly, are doctors reviewing).

Skip at first:

```text
near-real-time streaming
complex RLS
patient-facing Power BI
free-text analysis
automatic lab OCR analytics
advanced fairness analytics unless data is ready
```

**Why these are deferred:** near-real-time streaming requires a separate data pipeline (Direct Query or Push dataset). Complex RLS (Row-Level Security) requires careful testing to avoid data leaks. Patient-facing Power BI is excluded entirely (see Step 1). Free-text and OCR analytics require NLP preprocessing that does not exist yet. Fairness analytics requires labeled demographic data and statistical methodology that should be designed carefully, not added as a quick report.

Why: the first report should prove privacy-safe analytics before adding operational complexity.

## Step 4: Backend Embed Token Service

Current repo:

```text
Skin_Lesion_Classification_backend
```

Create at this backend embed-token gate:

```text
app/api/v1/analytics.py
app/services/powerbi_embed_service.py
app/schemas/analytics_schema.py
app/core/powerbi_config.py
```

**What each file does:** `analytics.py` defines the FastAPI route handlers for the embed token endpoints. `powerbi_embed_service.py` contains the logic to call the Power BI REST API and generate embed tokens using the MSAL (Microsoft Authentication Library) client credentials flow. `analytics_schema.py` defines the Pydantic response shape that the frontend receives. `powerbi_config.py` reads all Power BI environment variables and exposes them as a typed settings object.

Endpoints:

```text
GET /api/v1/analytics/powerbi/admin-embed-token
GET /api/v1/analytics/powerbi/doctor-embed-token
GET /api/v1/analytics/powerbi/research-embed-token
```

**What these endpoints do:** each endpoint checks the caller's role, then generates a Power BI embed token with the appropriate report ID and optional RLS identity. The frontend calls one of these endpoints, receives the embed config, and passes it directly to the PowerBIEmbed component. The client secret never leaves the backend.

Backend responsibilities:

```text
check authenticated user
check role permissions
select correct report and workspace
generate Power BI embed token
apply RLS identity when needed
return frontend-safe embed config
log audit event
```

**What each responsibility means:** `check authenticated user` verifies the JWT is valid and not expired. `check role permissions` confirms the user's role matches the endpoint (doctors cannot call the admin endpoint). `apply RLS identity` sets the Power BI RLS username to the caller's user ID so the report filters to only their data. `log audit event` writes a `powerbi_report_viewed` record to the audit log.

Environment variables:

```text
POWERBI_TENANT_ID=
POWERBI_CLIENT_ID=
POWERBI_CLIENT_SECRET=
POWERBI_WORKSPACE_ID=
POWERBI_ADMIN_REPORT_ID=
POWERBI_DOCTOR_REPORT_ID=
POWERBI_RESEARCH_REPORT_ID=
POWERBI_DATASET_ID=
POWERBI_ALLOW_STUB_TOKENS=false
```

**What these variables configure:** `TENANT_ID` and `CLIENT_ID` identify the Azure AD app registration. `CLIENT_SECRET` is the app credential for the client credentials OAuth flow - this is never sent to the browser. `WORKSPACE_ID` is the Power BI workspace GUID. The three report IDs select which Power BI report to embed for each role.

Never expose these variables in the frontend.

Current local behavior:

```text
POWERBI_ALLOW_STUB_TOKENS=true is allowed only for local contract tests.
Default behavior is false, so live endpoints return 503 until real Azure/Power BI credentials are configured.
```

Check:

```powershell
cd Skin_Lesion_Classification_backend
pytest
```

**What this does:** runs the backend tests including any tests for the analytics endpoints. Tests should verify role enforcement (admin token endpoint rejects doctor callers) and that the embed config response shape is correct.

Expected result:

```text
only the backend can generate embed tokens
```

**What this means:** there is no path for the frontend to call the Power BI API directly. The client secret is server-side only.

## Step 5: Frontend Embed Pages

Current repo:

```text
Skin_Lesion_Classification_frontend
```

Install at this frontend embed gate:

```powershell
npm install powerbi-client powerbi-client-react
```

Do not run this install until you are ready to touch the frontend repo and verify the resulting lockfile/build. The current repo already has a frontend analytics shell, so the next frontend step is package install plus real embed component after the backend endpoint has real Power BI credentials.

**What these packages do:** `powerbi-client` is the official Microsoft JavaScript SDK for embedding Power BI reports. `powerbi-client-react` wraps it in a React component (`PowerBIEmbed`) that handles the SDK lifecycle (initialization, token refresh, render).

Create:

```text
components/analytics/PowerBIReport.tsx
app/admin/analytics/page.tsx
app/doctor/analytics/page.tsx
app/research/analytics/page.tsx
```

**What each file does:** `PowerBIReport.tsx` is the reusable embed component. The three page files are Next.js route pages that call the backend embed token endpoint, receive the config, and render `PowerBIReport` with those values.

Component shape:

```tsx
"use client";

import { PowerBIEmbed } from "powerbi-client-react";
import { models } from "powerbi-client";

type PowerBIReportProps = {
  reportId: string;
  embedUrl: string;
  embedToken: string;
};

export function PowerBIReport({
  reportId,
  embedUrl,
  embedToken,
}: PowerBIReportProps) {
  return (
    <div className="h-[80vh] w-full overflow-hidden rounded border">
      <PowerBIEmbed
        embedConfig={{
          type: "report",
          id: reportId,
          embedUrl,
          accessToken: embedToken,
          tokenType: models.TokenType.Embed,
          settings: {
            panes: {
              filters: { visible: false },
              pageNavigation: { visible: true },
            },
            background: models.BackgroundType.Transparent,
          },
        }}
        cssClassName="h-full w-full"
      />
    </div>
  );
}
```

**What this component does:**

- `"use client"` - marks this as a Next.js Client Component because `PowerBIEmbed` uses browser APIs and cannot run on the server.
- `type PowerBIReportProps` - the three values from the backend embed config: the report GUID, the embed URL, and the short-lived embed token.
- `tokenType: models.TokenType.Embed` - tells the SDK this is a Power BI embed token (as opposed to an Azure AD user token). The backend generates this type.
- `filters: { visible: false }` - hides the filter pane so analysts cannot filter to expose individual patient-level data accidentally.
- `pageNavigation: { visible: true }` - shows the page navigation tabs so users can switch between report pages.
- `background: models.BackgroundType.Transparent` - makes the report background match the app's design system instead of Power BI's default white.

Use the existing app API client and auth flow if one exists. Do not store Power BI secrets in the browser.

Check:

```powershell
cd Skin_Lesion_Classification_frontend
npm run type-check
npm run build
```

**What these commands do:** `npm run type-check` runs TypeScript's type checker without compiling to find type errors quickly. `npm run build` does the full Next.js production build to confirm there are no import errors, missing components, or build-time failures.

Expected result:

```text
admin, doctor, and research analytics pages compile and request embed config from the backend
```

**What this means:** the TypeScript types are correct, the components compile, and the page routes exist in the Next.js build output.

## Step 6: Security And Row-Level Rules

Use:

```text
admin report: system-wide aggregated data
doctor report: assigned or reviewable cases only
research report: de-identified and consent-approved data only
```

**What each access rule means:** admins see everything in the system. Doctors see only cases assigned to them (enforced by RLS on the doctor report). Researchers see only rows from the `approved/` training bucket where consent is confirmed and data is de-identified.

Add audit event:

```text
powerbi_report_viewed
```

**What this event records:** every time a user opens an analytics page, the backend logs this event with the user's ID, role, and which report was accessed. This creates an audit trail for who accessed analytics and when.

Audit metadata:

```json
{
  "report_type": "admin",
  "report_id": "POWER_BI_REPORT_ID"
}
```

**What these fields capture:** `report_type` identifies which category of report was accessed (admin, doctor, or research). `report_id` is the Power BI report GUID - allows correlating the audit log to the specific report in the Power BI workspace.

Check:

```text
admin can open admin analytics
doctor cannot open admin analytics
research reviewer cannot see patient-identifying data
embed token expires and refreshes
dashboard access is audit-logged
Power BI report does not expose raw image URLs or lab file URLs
RLS filters doctor dashboard before production use
```

**What each check verifies:** `doctor cannot open admin analytics` must be an HTTP 403 from the backend - not just hidden in the UI. `embed token expires and refreshes` confirms the frontend handles token expiry and fetches a new one without a page reload. `RLS filters doctor dashboard` means the Power BI report is tested with a doctor's RLS identity to confirm it only shows their assigned cases.

## Step 7: Refresh Strategy

Start simple:

```text
Power BI connects to analytics views
manual refresh or scheduled daily refresh
```

**What this means:** Power BI Import mode downloads a snapshot of the analytics view data into the Power BI dataset. Scheduled daily refresh re-downloads it once per day. This is the simplest starting point and is enough for dashboards where next-day accuracy is acceptable.

After the MVP refresh gate:

```text
hourly refresh for admin dashboards
incremental refresh for larger datasets
near-real-time only for specific operations events
```

**What each approach does:** `hourly refresh` re-imports the view data every hour - useful for operational dashboards. `incremental refresh` only imports rows added or modified since the last refresh, avoiding full re-download of large tables. `near-real-time` uses Power BI streaming datasets or DirectQuery to show data within minutes - requires more infrastructure and cost.

Near-real-time candidates:

```text
analysis_completed
doctor_review_created
lab_result_uploaded
body_location_verified
```

**Why these four events specifically:** they represent immediate clinical actions where a near-real-time operational view has value - a new AI analysis, a doctor submitting a review, a new lab result, a body location being verified. These events are high-frequency enough to justify the added streaming complexity.

## Stop Point

Power BI is ready to implement only after:

```text
native role dashboards exist
analytics-safe views are defined
privacy exclusions are documented
backend token endpoint contract is documented
frontend embed page contract is documented
audit logging exists
staging secrets handling exists
```

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

If this guide was local-only, no cloud shutdown is needed.
