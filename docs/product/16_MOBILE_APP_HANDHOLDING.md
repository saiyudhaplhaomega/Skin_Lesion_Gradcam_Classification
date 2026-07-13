# React Native Mobile App Handholding Guide

Use this only after the web app and FastAPI contracts are stable. The mobile app should reuse the same backend APIs as the web app, not create a separate product.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the main workspace root where all sibling repos live. The mobile repo does not exist yet - this is the starting point before you run `create-expo-app`.

Current stable repos before this guide:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
Skin_Lesion_XAI_research
```

**What this means:** these three repos must be stable and their API contracts must be finalised before starting the mobile app. The mobile app reuses the same backend APIs - it does not get its own separate backend.

Planned mobile repo:

```text
Skin_Lesion_Classification_mobile
```

**What this means:** the mobile app will be a new repo created alongside the existing ones. It is not a subdirectory of the backend or frontend.

## Goal

Build a patient/customer mobile app that supports:

```text
login/register
patient dashboard
lesion profiles
2D body mapping with patient-submitted location status
image capture/upload
privacy mode selection
AI analysis result display
Grad-CAM and image-quality feedback
safe explanation display
lab result upload
consent/privacy controls
reminders and notifications
reports
```

**What this feature list means:** these are the screens and capabilities the patient-facing mobile app needs. The order matters - build auth and basic navigation before adding image capture and AI display. `login/register` comes before everything because without auth you cannot scope data to a user. `2D body mapping` means the patient taps on a body diagram to mark where their lesion is. `Grad-CAM and image-quality feedback` means showing the model's heatmap and flagging if the image was blurry or poorly lit.

Doctor/admin dashboards stay web-first at the beginning.

## Safety Copy

Use this copy throughout the mobile app:

```text
This AI result is not a medical diagnosis. It is intended to support awareness and organization of your lesion history. Please consult a qualified clinician for medical advice.
```

**What this copy does:** this disclaimer appears on every AI result screen. It ensures the patient cannot misread the model's output as a medical verdict. It must be visible and unambiguous, not hidden in fine print.

Grad-CAM copy:

```text
The heatmap shows image regions that influenced the AI model. It does not prove disease and should not be interpreted as a diagnosis.
```

**What this copy does:** this text accompanies the Grad-CAM heatmap overlay. Without it, a patient could mistake a highlighted region for a confirmed lesion boundary or a sign of disease.

Body-map copy:

```text
Your selected location is patient-submitted and may be corrected by a doctor during review.
```

**What this copy does:** this text appears next to any body location the patient placed on the body map. It signals that the location is approximate and can be adjusted by a reviewing clinician.

Lab-result copy:

```text
Lab results are uploaded as clinical context for doctor review. The AI does not diagnose from blood test results.
```

**What this copy does:** lab result uploads are for contextual reference only. This copy prevents patients from expecting an AI interpretation of their blood work.

Maximum privacy copy:

```text
No image will be stored. Visual history, doctor image review, and visual PDF reports will be limited.
```

**What this copy does:** when the patient selects maximum privacy mode, this copy explains what they lose by not storing images. It sets expectations upfront so patients can make an informed choice.

## Tech Stack

Use:

```text
Expo
React Native
TypeScript
Expo Router
TanStack Query
Zustand or Context for lightweight app state
React Hook Form
Zod
Expo Image Picker
Expo Camera
Expo SecureStore
Expo Notifications
Expo FileSystem
Three.js later for mobile 3D body map
React Three Fiber later for mobile 3D body map
SQLite later for offline queue/history cache
```

**What these stack choices mean:**

- `Expo` - the toolkit that wraps React Native and provides managed builds, over-the-air updates, and access to device APIs. Lets you avoid native Android/iOS setup in early phases.
- `React Native` - the cross-platform mobile framework. Compiles to native iOS and Android UI using a single TypeScript codebase.
- `TypeScript` - type safety so the same type definitions can be shared with the web frontend.
- `Expo Router` - file-based routing for Expo apps, similar to Next.js. Each file in the `app/` folder becomes a route automatically.
- `TanStack Query` - handles server state: fetching, caching, background refresh, and error states for API calls.
- `Zustand or Context` - for lightweight client state like current user, selected privacy mode, or draft form data.
- `React Hook Form` - form state management for login, registration, and consent flows.
- `Zod` - schema validation for form inputs and API response types, so the app does not silently accept malformed data.
- `Expo Image Picker` - provides a system UI for selecting images from the camera or gallery without writing native code.
- `Expo Camera` - for custom camera views with additional guidance overlays (added later in Phase M4).
- `Expo SecureStore` - encrypted key-value storage for auth tokens. Not for images or large data.
- `Expo Notifications` - local and push notification support for reminders.
- `Expo FileSystem` - access to the device file system for temporary image handling during upload.
- `Three.js` and `React Three Fiber` - added later for the 3D body map. Not needed for MVP.
- `SQLite` - local database for offline upload queues. Added in the advanced phase.

Notes from official Expo docs:

- `create-expo-app` can create a default TypeScript Expo project with recommended tooling.
- Expo Router is file-based routing for Expo/React Native apps.
- `expo-image-picker` supports `launchImageLibraryAsync()` and camera/gallery system UI.
- `expo-camera` provides `CameraView` and `takePictureAsync()` for custom camera flows.
- `expo-secure-store` is for encrypted key-value storage, not full images or lab reports.
- `expo-notifications` supports local and push notification workflows, but push notifications may require a development build depending on SDK/platform.
- 3D body mapping is added after the 2D body map works and must keep a 2D fallback.

## Step 1: Create The Mobile Repo

Current directory:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this means:** run the following commands from this directory so the new mobile repo is created as a sibling alongside the backend and frontend repos.

Create:

```powershell
npx create-expo-app@latest Skin_Lesion_Classification_mobile --template default
cd Skin_Lesion_Classification_mobile
npx expo start
```

**What this does:**

- `npx create-expo-app@latest Skin_Lesion_Classification_mobile --template default` - scaffolds a new Expo project with TypeScript, Expo Router, and the default file structure already configured.
- `cd Skin_Lesion_Classification_mobile` - moves into the new repo.
- `npx expo start` - starts the Expo development server. You can then open the app in Expo Go on a phone, or in a web browser, or in a simulator.

If Expo asks to install dependencies, accept.

Expected result:

```text
Expo starts and shows QR/device/web options.
```

**What this result means:** the Expo Metro bundler started successfully. A QR code lets you scan and open the app in Expo Go on your phone. The `w` key opens it in a browser. The `a` or `i` keys open it in Android/iOS simulators if those are installed.

Why: Expo gives camera/image picker/routing/notifications support without starting with native Android/iOS setup.

## Step 2: Install Mobile Dependencies

Current repo:

```text
Skin_Lesion_Classification_mobile
```

**What this means:** all commands in this step run from inside the `Skin_Lesion_Classification_mobile` directory.

Run:

```powershell
npx expo install expo-router react-native-safe-area-context react-native-screens expo-linking expo-constants expo-status-bar
npx expo install expo-image-picker expo-camera expo-secure-store expo-notifications expo-file-system
npm install @tanstack/react-query zustand react-hook-form zod
```

**What this does:**

- `npx expo install ...` - installs packages using Expo's version-aware installer, which picks compatible versions of native packages for your current Expo SDK version. This is safer than `npm install` for Expo-specific packages.
- `expo-router react-native-safe-area-context react-native-screens expo-linking expo-constants expo-status-bar` - core navigation and layout packages needed for Expo Router to work.
- `expo-image-picker expo-camera expo-secure-store expo-notifications expo-file-system` - device API packages for images, camera, encrypted storage, push notifications, and file access.
- `npm install @tanstack/react-query zustand react-hook-form zod` - JavaScript-only packages that don't need native module linking, so plain `npm install` is fine for these.

Check:

```powershell
npx expo start
```

**What this does:** confirms the app still starts after adding dependencies. If any native package has a version conflict, Expo will warn here rather than failing silently.

Expected result: the app still starts.

## Step 3: Create Mobile Folder Structure

Current repo:

```text
Skin_Lesion_Classification_mobile
```

**What this means:** all files and directories in this step are created inside `Skin_Lesion_Classification_mobile/`.

Create this structure:

```text
app/
  _layout.tsx
  (auth)/
    login.tsx
    register.tsx
    forgot-password.tsx
  (tabs)/
    _layout.tsx
    dashboard.tsx
    lesions.tsx
    body-map.tsx
    analyze.tsx
    reports.tsx
    privacy.tsx
  lesions/
    [lesionId].tsx
    [lesionId]/timeline.tsx
    [lesionId]/reports.tsx
    [lesionId]/lab-results.tsx
  analyze/
    select-lesion.tsx
    create-lesion.tsx
    body-location.tsx
    privacy-mode.tsx
    capture.tsx
    preview.tsx
    image-quality.tsx
    result.tsx
  body-map-3d/
    index.tsx
    [lesionId].tsx
  lab-results/
    index.tsx
    upload.tsx
    [labResultId].tsx
  reminders/
    index.tsx
    create.tsx
  settings/
    index.tsx
    consent.tsx
    storage.tsx
    notifications.tsx
    account.tsx
src/
  api/
  components/
    bodyMap/
      BodyMap2D.tsx
      BodyMapPin.tsx
      BodyRegionSelector.tsx
      BodyMap3D.tsx
      BodyMap3DPin.tsx
      BodyMapModeToggle.tsx
      BodyMapFallbackNotice.tsx
  hooks/
  store/
  types/
  utils/
  constants/
    bodyModel.ts
```

**What this folder structure means:**

- `app/` - Expo Router's convention. Every `.tsx` file here becomes a route automatically. Parenthesised folders like `(auth)` and `(tabs)` are route groups - they group related screens without affecting the URL path.
- `app/_layout.tsx` - the root layout that wraps all routes. This is where you set up providers (React Query, auth context, etc.).
- `(auth)/` - screens that appear before the user is logged in. Expo Router keeps these outside the tabs navigation.
- `(tabs)/` - the main bottom-tab navigation. Each file here is one tab.
- `[lesionId].tsx` - a dynamic route. The bracket syntax means the segment is a URL parameter, so `/lesions/abc123` maps to this file with `lesionId = "abc123"`.
- `src/` - non-route code: API clients, reusable components, hooks, types, and utilities.
- `bodyMap/` - all body map components live together. The 3D components are scaffolded here from the start but only implemented in Phase M3B.

Check:

```powershell
npx expo start
```

**What this does:** confirms Expo Router can resolve all the route files without errors. If a route file has a syntax error or an unresolvable import, Expo will surface the error here.

Expected result: Expo Router can resolve the route files.

## Step 4: Add API Client

Current repo:

```text
Skin_Lesion_Classification_mobile
```

**What this means:** all files in this step are created inside `Skin_Lesion_Classification_mobile/`.

Create:

```text
src/api/client.ts
```

**What this file is:** a shared HTTP client function that all API calls in the app go through. Centralising it here means auth token injection and error handling are in one place, not scattered across hooks.

Paste:

```ts
import * as SecureStore from "expo-secure-store";

const API_BASE_URL = process.env.EXPO_PUBLIC_API_BASE_URL;

export async function apiFetch<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const token = await SecureStore.getItemAsync("access_token");

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers ?? {}),
    },
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || "API request failed");
  }

  return response.json() as Promise<T>;
}
```

**What this function does:**

- `import * as SecureStore from "expo-secure-store"` - imports Expo's encrypted key-value store. This is where the JWT access token is kept between app restarts.
- `const API_BASE_URL = process.env.EXPO_PUBLIC_API_BASE_URL` - reads the base URL from an environment variable. The `EXPO_PUBLIC_` prefix makes the variable visible on the client side in Expo.
- `apiFetch<T>` - a generic async function. The `<T>` type parameter lets callers specify what shape they expect back (e.g., `apiFetch<Lesion[]>(...)`).
- `await SecureStore.getItemAsync("access_token")` - reads the stored JWT. Returns `null` if no token exists (unauthenticated state).
- The `Authorization: Bearer ${token}` header is only added if a token exists, so unauthenticated requests (login, register) still work.
- `if (!response.ok)` - throws an error for any non-2xx HTTP response, so callers do not need to check the status themselves.
- `return response.json() as Promise<T>` - parses the JSON response and casts it to the caller's expected type.

Create:

```text
.env
```

**What this file is:** the local environment variables file. Expo reads variables prefixed with `EXPO_PUBLIC_` and makes them available in client code.

Paste:

```text
EXPO_PUBLIC_API_BASE_URL=http://localhost:8000
```

**What this does:** points the mobile app at the local FastAPI backend during development. Change this to the staging or production backend URL when deploying.

Check:

```powershell
npx expo start
```

**What this does:** confirms the TypeScript compiler accepts the `apiFetch` function signature and SecureStore import with no type errors.

Expected result: TypeScript accepts the API client.

## Step 5: Add Multipart Image Upload

Current repo:

```text
Skin_Lesion_Classification_mobile
```

Create:

```text
src/api/images.api.ts
```

**What this file is:** the API call specifically for uploading lesion images as multipart form data. Image uploads cannot use `apiFetch` directly because they need `multipart/form-data` encoding, not JSON.

Paste:

```ts
import * as SecureStore from "expo-secure-store";

export type StorageMode =
  | "full_clinical_history"
  | "privacy_balanced"
  | "maximum_privacy";

export async function uploadLesionImage(params: {
  lesionId: string;
  imageUri: string;
  storageMode: StorageMode;
}) {
  const token = await SecureStore.getItemAsync("access_token");
  const formData = new FormData();

  formData.append("storage_mode", params.storageMode);
  formData.append("file", {
    uri: params.imageUri,
    name: "lesion.jpg",
    type: "image/jpeg",
  } as unknown as Blob);

  const response = await fetch(
    `${process.env.EXPO_PUBLIC_API_BASE_URL}/api/v1/lesions/${params.lesionId}/images`,
    {
      method: "POST",
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: formData,
    },
  );

  if (!response.ok) {
    throw new Error(await response.text());
  }

  return response.json();
}
```

**What this code does:**

- `StorageMode` - a union type for the three privacy levels the patient can choose. The backend uses this to decide whether to keep the image long-term, short-term, or not at all.
- `formData.append("storage_mode", params.storageMode)` - adds the privacy preference as a form field alongside the image.
- `formData.append("file", { uri, name, type } as unknown as Blob)` - React Native's `FormData` accepts a special object `{ uri, name, type }` for files instead of a real browser `Blob`. The `as unknown as Blob` cast is needed for TypeScript to accept it.
- The `Authorization` header is set manually here because `apiFetch` is not used for multipart uploads. The `Content-Type` header is intentionally left out.

Important:

```text
Do not manually set Content-Type for multipart upload. Let fetch/native code set the boundary.
```

**What this warning means:** `multipart/form-data` requires a boundary string (e.g., `boundary=----FormBoundaryXYZ`) appended to the `Content-Type` header. If you set `Content-Type: multipart/form-data` manually without the boundary, the server cannot parse the form data. React Native's `fetch` sets the correct `Content-Type` with boundary automatically when you pass a `FormData` body.

Check:

```powershell
npx expo start
```

**What this does:** confirms the TypeScript compiler accepts the upload function, including the `FormData` type cast.

Expected result: the app still starts.

## Step 6: Add Domain Types

Current repo:

```text
Skin_Lesion_Classification_mobile
```

Create:

```text
src/types/lesion.types.ts
src/types/analysis.types.ts
```

**What these files are:** shared TypeScript type definitions that mirror the backend API response shapes. Keeping them in one place means the API hooks, components, and form validators all reference the same types.

Paste:

```ts
export type BodyLocationStatus =
  | "unknown"
  | "patient_submitted"
  | "doctor_verified"
  | "doctor_corrected"
  | "rejected"
  | "disputed";

export type TriageLevel =
  | "low_concern"
  | "monitor"
  | "retake_image"
  | "professional_review_recommended"
  | "urgent_professional_review_recommended";

export type Lesion = {
  id: string;
  userId: string;
  userLabel?: string;
  bodyLocationStatus: BodyLocationStatus;
  currentBodyLocationRecordId?: string;
  status: "active" | "archived" | "deleted";
  firstSeenAt: string;
  createdAt: string;
  updatedAt: string;
};

export type AnalysisEvent = {
  id: string;
  userId: string;
  lesionId: string;
  imageId?: string;
  predictionLabel: string;
  confidence: number;
  calibratedConfidence?: number;
  triageLevel: TriageLevel;
  modelVersion: string;
  imageQualityScore?: number;
  blurScore?: number;
  lightingScore?: number;
  glareScore?: number;
  createdAt: string;
};
```

**What these types mean:**

- `BodyLocationStatus` - the workflow state of a lesion's body location. Starts as `unknown`, becomes `patient_submitted` when the patient places a pin, and transitions to `doctor_verified` or `doctor_corrected` after a clinician reviews it.
- `TriageLevel` - the AI model's urgency recommendation. The UI uses this to decide how prominently to display a "please seek professional review" message.
- `Lesion` - the main lesion record. `userLabel` is an optional nickname the patient gives a lesion (e.g., "mole on right arm"). `firstSeenAt` is when the patient first noticed it, which may differ from `createdAt` when they uploaded it.
- `AnalysisEvent` - one AI analysis result for one image. `calibratedConfidence` is the temperature-scaled confidence value shown to users; `confidence` is the raw softmax output stored for research. `imageQualityScore`, `blurScore`, `lightingScore`, and `glareScore` come from the image quality assessment step.

Check:

```powershell
npx expo start
```

**What this does:** confirms the TypeScript compiler accepts all the type definitions with no syntax errors.

## Step 7: Add React Query Hooks

Current repo:

```text
Skin_Lesion_Classification_mobile
```

Create:

```text
src/hooks/useLesions.ts
```

**What this file is:** React Query hooks that wrap the lesion API endpoints. Components import these hooks instead of calling `apiFetch` directly, which keeps data-fetching logic out of components.

Paste:

```ts
import { useQuery } from "@tanstack/react-query";

import { apiFetch } from "../api/client";
import type { Lesion } from "../types/lesion.types";

export function useLesions() {
  return useQuery({
    queryKey: ["lesions"],
    queryFn: () => apiFetch<Lesion[]>("/api/v1/lesions"),
  });
}

export function useLesion(lesionId: string) {
  return useQuery({
    queryKey: ["lesion", lesionId],
    queryFn: () => apiFetch<Lesion>(`/api/v1/lesions/${lesionId}`),
    enabled: Boolean(lesionId),
  });
}
```

**What this code does:**

- `import { useQuery } from "@tanstack/react-query"` - imports the hook that handles fetching, caching, and background refresh.
- `queryKey: ["lesions"]` - the cache key. React Query deduplicates and shares data across all components that use the same key. If two components call `useLesions()`, only one network request goes out.
- `queryFn: () => apiFetch<Lesion[]>(...)` - the function React Query calls to fetch data. The `<Lesion[]>` generic tells TypeScript what shape to expect.
- `useLesion(lesionId)` - fetches a single lesion by ID. The `enabled: Boolean(lesionId)` condition prevents the query from running if `lesionId` is empty or undefined, which can happen during navigation.

Use mutations later for:

```text
create lesion
upload image
run analysis
submit body location
upload lab result
create reminder
update consent
delete image/lab result
```

**What this means:** mutations in React Query handle writes (POST, PUT, DELETE). Each of these operations gets its own `useMutation` hook in a later step. They are not read operations, so `useQuery` is not the right tool for them.

Check:

```powershell
npx expo start
```

**What this does:** confirms the query hooks compile without TypeScript errors and the React Query imports resolve correctly.

## Step 8: Build Mobile Phases In Order

### Phase M1: Mobile Foundation

Build:

```text
Expo TypeScript app
Expo Router
auth screens
API client
React Query
basic UI components
environment variables
```

**What to build in this phase:** the bare minimum to have a working app shell. Auth screens, the API client, and React Query setup must come first because everything else depends on them. Do not build any feature screens until auth and API plumbing work.

Check:

```powershell
npx expo start
```

**What this does:** confirms the foundation starts without errors. Use this check after every phase.

### Phase M2: Patient Dashboard

Build:

```text
dashboard summary screen
recent activity feed
my lesions screen
lesion detail screen
loading/empty/error states
```

**What to build in this phase:** the read-only views a patient sees after logging in. These screens only fetch data - no uploads or mutations yet.

APIs:

```text
GET /api/v1/dashboard/summary
GET /api/v1/dashboard/activity
GET /api/v1/lesions
GET /api/v1/lesions/{lesion_id}
```

**What these endpoints provide:** `summary` returns counts and alerts. `activity` returns a time-sorted list of recent events (new images, analysis results, doctor messages). The lesion endpoints return the patient's lesion list and individual lesion records.

### Phase M3: Body Map And Lesion Creation

Build:

```text
create lesion flow
2D body map
patient-submitted location
location verification badge
lesion pin display
```

**What to build in this phase:** the flow a patient uses to record a new lesion. The 2D body map is an SVG diagram the patient taps to set a location. The badge shows whether the location has been verified by a doctor.

API:

```text
POST /api/v1/lesions/{lesion_id}/body-location
GET  /api/v1/lesions/{lesion_id}/body-location/history
```

**What these endpoints do:** `POST` saves the patient's tapped location. `GET history` returns all past location records for a lesion, so the doctor can see if the location was ever changed.

### Phase M3B: Mobile 3D Body Map

Build after the 2D body map works:

```text
3D body-map route
3D body model viewer
rotate/pan/zoom controls
tap-to-place lesion pin
existing lesion pins
2D fallback toggle
unsupported-device state
loading/error states
coordinate summary
```

**What to build in this phase:** the 3D alternative to the 2D body map. This is optional from the user's perspective but required as a capability. Builds on top of the stable 2D flow.

Create:

```text
app/body-map-3d/index.tsx
app/body-map-3d/[lesionId].tsx
src/components/bodyMap/BodyMap3D.tsx
src/components/bodyMap/BodyMap3DPin.tsx
src/components/bodyMap/BodyMapModeToggle.tsx
src/components/bodyMap/BodyMapFallbackNotice.tsx
src/constants/bodyModel.ts
```

**What these files do:**

- `app/body-map-3d/index.tsx` - the 3D body map screen for creating a new location.
- `app/body-map-3d/[lesionId].tsx` - the 3D body map screen for editing an existing lesion's location.
- `BodyMap3D.tsx` - the main 3D canvas component using React Three Fiber. Renders the GLB body model and handles raycasting for tap-to-place.
- `BodyMap3DPin.tsx` - a 3D pin placed at the UV coordinate where the patient tapped.
- `BodyMapModeToggle.tsx` - a button that switches between 2D and 3D view.
- `BodyMapFallbackNotice.tsx` - a notice shown when the device does not support WebGL or 3D rendering.
- `bodyModel.ts` - maps body region names to UV coordinate ranges and mesh geometry regions.

Planned 3D stack:

```text
three
@react-three/fiber
Expo GL support if required by the selected renderer
GLB body model asset
```

**What these libraries do:** `three` is the underlying WebGL 3D library. `@react-three/fiber` wraps it in React components so you build the 3D scene declaratively. Expo GL provides the WebGL context on native mobile. The GLB asset is the 3D human body model file.

Install only when you reach this phase:

```powershell
npm install three @react-three/fiber
```

**What this does:** installs Three.js and its React wrapper. Installing them early in the project would add bundle size before they are used.

If the renderer requires Expo GL in the selected setup, install it with Expo:

```powershell
npx expo install expo-gl
```

**What this does:** installs the Expo GL module that provides a WebGL surface for native mobile rendering. Required for Three.js to render on iOS and Android.

3D data sent to the same backend body-location endpoint:

```json
{
  "source": "patient_submitted",
  "body_region": "left_forearm",
  "body_side": "left",
  "body_model_version": "adult_generic_v1",
  "mesh_region": "left_forearm",
  "uv_x": 0.238,
  "uv_y": 0.774,
  "note": "Mole near elbow"
}
```

**What these fields mean:** `body_region` and `mesh_region` are the named region the patient tapped. `uv_x` and `uv_y` are texture coordinates (0.0 to 1.0) that precisely locate the pin on the mesh, independent of screen size. `body_model_version` records which model version was used so the pin can be reproduced correctly if the model is updated.

Important rules:

```text
3D is an input aid, not clinical verification.
The saved location remains patient_submitted until doctor review.
If 3D fails, the app must offer the 2D body map.
3D pins must open the same lesion detail screen as 2D pins.
Do not block analysis if 3D is unavailable.
```

**What these rules mean:**

- `3D is an input aid, not clinical verification` - the 3D location has no higher authority than the 2D location. Both are patient-submitted.
- `The saved location remains patient_submitted until doctor review` - even if the patient uses 3D, the backend status does not automatically become verified.
- `If 3D fails, the app must offer the 2D body map` - 3D is a progressive enhancement, not a requirement for the core flow.
- `3D pins must open the same lesion detail screen as 2D pins` - both input methods lead to the same place. The underlying data shape is identical.
- `Do not block analysis if 3D is unavailable` - image capture and analysis should work on any device regardless of 3D support.

Check:

```powershell
npx expo start
```

**What this does:** confirms Three.js and Expo GL are correctly linked and the 3D routes resolve without errors.

Expected result: the user can switch between 2D and 3D body maps, and both submit the same body-location API shape.

### Phase M4: Image Capture, Upload, Analyze

Build:

```text
Expo ImagePicker MVP
camera/photo selection
preview screen
storage mode selection
multipart upload
analysis endpoint call
result screen
Grad-CAM display
```

**What to build in this phase:** the core analysis flow. The patient selects or takes an image, chooses a storage mode, uploads it, and sees the AI result. This is the most important feature of the app.

Use `expo-image-picker` first. Add `expo-camera` later for custom camera guidance.

### Phase M5: Privacy And Consent

Build:

```text
privacy mode selection
consent center
retention preference
delete image/lesion/lab result actions
```

**What to build in this phase:** the controls that let patients manage their data. Consent must be explicit and revocable. Delete actions must reach the backend - do not just hide records on the client.

### Phase M6: Lab Results

Build:

```text
lab results list
upload PDF/image
test date
lab name
patient note
doctor review status
delete lab result
```

**What to build in this phase:** the flow for uploading lab reports as context for doctor review. Lab results are not analysed by AI - they are clinical context only.

### Phase M7: Reminders And Notifications

Build:

```text
create reminders
upcoming reminders screen
local notifications
push notifications later
```

**What to build in this phase:** the reminder system for follow-up appointments and check-ins. Start with local notifications (no server needed). Push notifications require a backend notification service and a development build, so add those later.

Use Expo Notifications later for reminders. Request notification permission only when reminders are enabled.

### Phase M8: Reports

Build:

```text
reports list
generate report
open/download/share report
```

**What to build in this phase:** the PDF report flow. Patients can generate a summary report of their lesion history and share it with a doctor. The backend generates the PDF; the mobile app requests it and provides an open/download/share action.

### Phase M9: Advanced Mobile

Build after MVP:

```text
offline queue
encrypted local cache
custom camera guidance
ruler/scale calibration
push notification integration
```

**What these features are:** the advanced capabilities that go beyond basic functionality. `offline queue` lets patients capture images without internet and upload them when connected. `encrypted local cache` keeps a history of recent data locally without sending it to a server. `custom camera guidance` overlays alignment tips on the camera preview. `ruler/scale calibration` lets patients measure lesion size using a reference object. None of these block the MVP.

The 3D body map can be built as Phase M3B after the 2D map and backend body-location contract are stable. Keep advanced 3D refinements, animation polish, and device-specific performance work in Phase M9.

## Offline And Security Rules

Start simple:

```text
if offline, block analysis upload
show a friendly message
allow draft notes locally if needed
do not store sensitive images locally longer than needed
```

**What this means:** the MVP offline behaviour is simple - if there is no internet, tell the user and do not let them upload. Draft text notes can be saved locally. Do not let uploaded images sit on the device longer than the upload takes.

Later offline mode:

```text
encrypted upload queue
local SQLite metadata cache
temporary encrypted image cache
retry upload when online
clear local image after successful upload
```

**What this means:** the advanced offline mode queues captures locally and uploads them when connectivity returns. Each piece is encrypted at rest. The queue retries automatically. After a successful upload, the local copy is deleted so sensitive images do not accumulate on the device.

Hard rules:

```text
Do not store medical images in AsyncStorage.
Do not store full images in SecureStore.
Use SecureStore only for tokens and small secrets.
Use temporary file URIs only during upload.
Clear local temp files after upload when possible.
Do not save lesion photos to the public camera roll unless the user explicitly chooses.
```

**What these rules mean:**

- `Do not store medical images in AsyncStorage` - AsyncStorage is unencrypted. Any medical image stored there is readable without authentication.
- `Do not store full images in SecureStore` - SecureStore is encrypted but has a small size limit (a few kilobytes). It is for tokens and credentials, not image data.
- `Use SecureStore only for tokens and small secrets` - follows from the above. Access tokens, refresh tokens, and small preference values are fine.
- `Use temporary file URIs only during upload` - Expo's image picker returns a temporary file URI. Use it only to read the image bytes for the upload, then let the OS clean it up.
- `Clear local temp files after upload when possible` - explicitly delete the temp file after the upload succeeds to avoid leaving medical images in the temp directory.
- `Do not save lesion photos to the public camera roll unless the user explicitly chooses` - the default camera capture flow should not save images to the photo library. Medical images in the camera roll can be seen by other apps, synced to cloud photo services, and shared accidentally.

## Minimum Mobile MVP

Build first:

```text
login/register
dashboard
my lesions
lesion detail
2D body map
create lesion
patient-submitted body location
set storage mode
pick/take image
upload image
run analysis
show result and Grad-CAM
show safety explanation
lab result upload
privacy/consent center
basic reports list
basic reminders
```

**What this MVP list means:** every item here covers a core patient journey. The list is ordered roughly by dependency - you cannot show analysis results before you can upload images, and you cannot upload images before you have auth. Build in this sequence and verify each step works before moving to the next.

Avoid first:

```text
3D body map before the 2D map and backend body-location API work
on-device AI inference
automatic lab OCR
doctor mobile dashboard
full offline encrypted mode
AR measurement
multi-model comparison UI
complex chat UI
real-time camera AI guidance
```

**What to avoid and why:**

- `3D body map before the 2D map works` - the 3D map depends on a stable body-location API contract. Build 2D first to prove the contract.
- `on-device AI inference` - running the model on the phone requires model conversion and device-specific optimisation. It is a separate project.
- `automatic lab OCR` - OCR from the phone adds complexity and accuracy risk. The backend handles OCR as an optional step.
- `doctor mobile dashboard` - the doctor experience is web-first. Mobile for doctors adds complexity without clear benefit at MVP.
- `full offline encrypted mode` - the SQLite queue, encrypted cache, and retry logic are significant engineering. Do simple offline blocking first.
- `AR measurement` - augmented reality lesion measurement is a research feature, not an MVP need.
- `multi-model comparison UI` - comparing outputs from multiple models requires ensemble infrastructure that is not yet built.
- `complex chat UI` - a real-time chat or message thread between patient and doctor is a product decision that needs design work first.
- `real-time camera AI guidance` - live model inference on the camera feed is both technically complex and requires careful safety framing.

## Final Check

Run from the mobile repo:

```powershell
npx expo start
```

**What this does:** starts the Expo development server and opens the app. Use this as the basic smoke test after completing any phase.

If test scripts exist later, run:

```powershell
npm run type-check
npm run test
```

**What these commands do:**

- `npm run type-check` runs the TypeScript compiler in no-emit mode to catch type errors across all source files without producing a build output.
- `npm run test` runs the mobile test suite once it is set up. Tests cover API hooks, form validation logic, and utility functions.

Expected result: the mobile app uses the same backend contracts as the web app and keeps all medical outputs framed as supportive information, not diagnosis.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current state of all dev cloud resources.
- `make cloud-pause ENV=dev` pauses pausable resources without destroying them.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment. The `CONFIRM_DESTROY=YES` guard prevents accidental destruction.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` applies Terraform configuration to create or resume the dev environment.
- `make cloud-status ENV=dev` confirms all resources are healthy before beginning work.

If this guide was local-only, no cloud shutdown is needed.
