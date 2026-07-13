# 22 - Vercel Frontend Staging Handholding

Use this after the EKS backend Ingress has a reachable ALB URL.

## Goal

Deploy the Next.js frontend to Vercel and route browser API calls through Vercel to the EKS backend.

Current staging frontend:

```text
https://skin-lesion-classification-frontend.vercel.app
```

Current staging backend ALB:

```text
http://k8s-skinlesi-skinlesi-f9a8d304ec-575886365.us-east-1.elb.amazonaws.com
```

Why Vercel rewrites are used: Vercel pages are HTTPS. The current EKS ALB is HTTP. A browser blocks direct HTTPS-to-HTTP API calls as mixed content, so the frontend calls same-origin `/api/v1/*` and Vercel proxies the request to the ALB.

## Command Location

Run commands from:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
```

Every frontend file path in this guide is relative to:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
```

## Files

Run from:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
```

Edit:

```text
Skin_Lesion_Classification_frontend\vercel.json
Skin_Lesion_Classification_frontend\lib\api.ts
Skin_Lesion_Classification_frontend\components\lab-results\LabResultList.tsx
Skin_Lesion_Classification_frontend\components\lab-results\LabResultUpload.tsx
Skin_Lesion_Classification_frontend\.vercelignore
```

## Required Vercel Routing

Create or keep:

```json
{
  "rewrites": [
    {
      "source": "/api/v1/:path*",
      "destination": "http://k8s-skinlesi-skinlesi-f9a8d304ec-575886365.us-east-1.elb.amazonaws.com/api/v1/:path*"
    },
    {
      "source": "/health",
      "destination": "http://k8s-skinlesi-skinlesi-f9a8d304ec-575886365.us-east-1.elb.amazonaws.com/health"
    }
  ]
}
```

Check:

```powershell
curl.exe -i http://k8s-skinlesi-skinlesi-f9a8d304ec-575886365.us-east-1.elb.amazonaws.com/health
```

Expected:

```text
HTTP/1.1 200 OK
{"status":"ok"}
```

## Build Locally First

Run from the frontend folder:

```powershell
C:\Users\saiyu\AppData\Roaming\npm\npm.cmd run type-check
C:\Users\saiyu\AppData\Roaming\npm\npm.cmd run build
```

Expected:

```text
tsc --noEmit exits 0
next build exits 0
```

## Vercel Login

Use the pinned CLI version if the latest CLI is blocked by npm security checks:

```powershell
C:\Users\saiyu\AppData\Roaming\npm\npx.cmd vercel@50.28.0 login
```

Expected:

```text
Congratulations! You are now signed in.
```

## Preview Deploy

Run from the frontend folder:

```powershell
C:\Users\saiyu\AppData\Roaming\npm\npx.cmd vercel@50.28.0 deploy --yes
```

Expected:

```text
Preview: https://...
Build Completed
```

Note: preview deployments may be protected by Vercel Authentication. If a preview URL shows `401 Authentication Required`, deploy or test the production alias.

## Production Alias Deploy

Run from the frontend folder:

```powershell
C:\Users\saiyu\AppData\Roaming\npm\npx.cmd vercel@50.28.0 deploy --prod --yes
```

Expected:

```text
Production: https://...
Aliased: https://skin-lesion-classification-frontend.vercel.app
```

## Verify Public Website And Backend Proxy

Run:

```powershell
curl.exe -I https://skin-lesion-classification-frontend.vercel.app/research
curl.exe -i https://skin-lesion-classification-frontend.vercel.app/health
curl.exe -i https://skin-lesion-classification-frontend.vercel.app/api/v1/research/metrics/dataset
curl.exe -s -F "image=@C:\Users\saiyu\Downloads\M1650261.jpg" -F "storage_mode=history" https://skin-lesion-classification-frontend.vercel.app/api/v1/analysis
```

Expected:

```text
/research returns 200
/health returns {"status":"ok"}
/api/v1/research/metrics/dataset returns JSON
/api/v1/analysis returns JSON with storage_mode, image_quality, and model_status
```

## Current Staging Limits

The Vercel frontend is live and connected to the EKS backend through rewrites.

The backend still reports:

```text
data_status: database_unavailable
model_status: untrained_stub
```

Why: staging database connection and trained model artifact loading are separate backend infrastructure steps.

Do not claim the full product is complete until:

```text
staging database is attached
migrations have run
trained model artifact is loaded
analysis storage modes persist real data
research dashboard reads real aggregate rows
```

## Stop Or Shutdown

Vercel hosting may remain active, but AWS EKS, ALB, NAT, and related staging resources can continue billing.

Before stopping work, run from the repo root:

```powershell
make cloud-status ENV=staging
```

If you are done testing staging:

```powershell
make cloud-shutdown ENV=staging CONFIRM_DESTROY=YES
```

Expected: staging AWS resources are destroyed according to Terraform state.
