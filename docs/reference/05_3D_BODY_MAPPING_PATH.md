# 3D Body Mapping Path

This is an implementation guide for the later 3D body map block. It is advanced because it requires stable lesion APIs and careful frontend rendering, not because it is optional.

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_frontend
```

**What this does:** moves first to the main workspace root, then into the frontend repository. All 3D body map components live in the frontend.

Current repo:

```text
Skin_Lesion_Classification_frontend
```

**What this means:** all 3D body map components are created inside the Next.js frontend repository, not the backend.

## Build

Create:

```text
components/body-map/BodyMap3D.tsx
components/body-map/BodyPin3D.tsx
components/body-map/bodyModelConfig.ts
public/models/adult_generic_v1.glb
```

**What these files are:**

- `BodyMap3D.tsx` - the main React component that renders the 3D body model canvas and handles pin placement interactions.
- `BodyPin3D.tsx` - a component for an individual 3D lesion pin placed on the body model mesh.
- `bodyModelConfig.ts` - configuration file that maps body region names to mesh geometry regions and UV coordinate ranges.
- `public/models/adult_generic_v1.glb` - the 3D GLB model file for the generic human body. Placed in `public/` so Next.js serves it as a static asset.

Use:

```text
Three.js
React Three Fiber
GLB human body model
clickable mesh regions
fallback to 2D mode
```

**What these technologies do:**

- `Three.js` - the foundational JavaScript 3D library that handles WebGL rendering, cameras, lighting, and geometry.
- `React Three Fiber` - a React wrapper for Three.js that lets you build 3D scenes with React components instead of imperative Three.js calls.
- `GLB human body model` - a binary GLTF 3D file containing the body mesh. GLB is a compact format that bundles geometry and textures into one file.
- `clickable mesh regions` - raycasting detects which mesh region the user clicked, converts the hit point to UV coordinates, and stores the location.
- `fallback to 2D mode` - if WebGL is not supported or the device is too slow, the UI falls back to the 2D body map SVG instead.

## Backend Contract

Store:

```json
{
  "body_model": "adult_generic_v1",
  "mesh_region": "left_forearm",
  "uv_x": 0.238,
  "uv_y": 0.774,
  "surface_side": "front"
}
```

**What these fields mean:**

- `body_model` - identifies the specific 3D model version used when the pin was placed. Important for reproducing the pin location correctly if the model is updated.
- `mesh_region` - the named body region (e.g., "left_forearm"). Human-readable and useful for doctor reports.
- `uv_x` and `uv_y` - UV texture coordinates (0.0 to 1.0) that precisely locate the pin on the mesh surface, independent of screen resolution.
- `surface_side` - distinguishes front from back for body regions that wrap around (e.g., left forearm has both a front and back visible in different poses).

## Check

```powershell
npm run type-check
npm run build
```

**What these commands do:**

- `npm run type-check` runs the TypeScript compiler in check mode to catch type errors in the 3D component code without producing build output.
- `npm run build` runs the full Next.js production build to confirm all 3D components render without build errors and the GLB file is properly included as a static asset.

Expected result: 3D pins save the same lesion record used by the 2D map.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current dev environment state.
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
