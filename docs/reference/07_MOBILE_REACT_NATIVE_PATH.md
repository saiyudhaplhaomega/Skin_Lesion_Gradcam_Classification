# Mobile React Native Path

This guide covers the mobile implementation. It belongs later in the sequence because mobile should reuse stable backend contracts, but it is part of the build plan.

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the main workspace root. The mobile repo does not exist yet; this sets the starting point for creating it.

Planned repo:

```text
Skin_Lesion_Classification_mobile
```

**What this means:** the mobile app will be a new repository alongside the existing backend, frontend, and research repos, created once backend APIs are stable.

## Stack

```text
React Native
Expo
camera capture
encrypted offline storage
upload queue
push reminders
2D body-map pins
3D body-map view when supported
```

**What these stack choices mean:**

- `React Native` - the cross-platform mobile framework that compiles to native iOS and Android UI. Shares TypeScript types and API calls with the web frontend.
- `Expo` - the toolkit that wraps React Native with managed build tools, OTA updates, and access to native device APIs through Expo modules.
- `camera capture` - direct camera access for capturing lesion images, using the Expo Camera module.
- `encrypted offline storage` - images and form data captured without internet access are encrypted at rest using device-level encryption before syncing.
- `upload queue` - captured images are queued locally and uploaded when a network connection is available.
- `push reminders` - push notifications for follow-up appointments, lesion check-in reminders, and lab result alerts.
- `2D body-map pins` - the same lesion location concept from the web frontend, adapted for touch interaction.
- `3D body-map view when supported` - 3D rendering is only enabled on devices with sufficient GPU and WebGL support.

## Backend Contracts Needed

```text
POST /api/v1/analysis
GET/POST /api/v1/lesions
POST /api/v1/consent
GET /api/v1/lesions/{lesion_id}/timeline
signed upload/download URLs
```

**What these API contracts mean:**

- `POST /api/v1/analysis` - the image upload and analysis endpoint. The mobile app uses this same endpoint as the web frontend.
- `GET/POST /api/v1/lesions` - fetches the patient's lesion list and creates new lesion records.
- `POST /api/v1/consent` - submits patient consent for a specific image. Required before any training use.
- `GET /api/v1/lesions/{lesion_id}/timeline` - fetches the full history of a specific lesion, including images over time and doctor notes.
- `signed upload/download URLs` - presigned S3 URLs that let the mobile app upload images directly to S3 and download them without the backend acting as a proxy.

## Check

```powershell
npm run type-check
npm run test
```

**What these commands do:**

- `npm run type-check` runs TypeScript type checking across the mobile codebase without building.
- `npm run test` runs the mobile test suite, covering API integration, offline storage, and UI components.

Expected result: mobile can capture offline, then upload when online without changing backend APIs.

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
