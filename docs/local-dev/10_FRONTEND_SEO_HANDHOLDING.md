# Frontend SEO Handholding Guide

**This guide is the canonical implementation guide. For reference and additional context, also see `docs/product/09_SEO_AND_PUBLIC_PAGES_HANDHOLDING.md`.**

Use this after the customer dashboard and privacy/consent workflows are clear, and before staging or production deployment.

This guide walks through adding SEO metadata, public pages, sitemap, robots rules, and Open Graph support to the Next.js frontend. It is the local-dev companion to the frontend build guide (`BUILD_FRONTEND.md`).

## Command Location

Run frontend commands from:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
```

What this does: moves your terminal directly into the Next.js frontend repo where `package.json`, `app/`, and frontend commands live.

Every path in this guide is relative to that directory.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Frontend repo: `Skin_Lesion_Classification_frontend/`
- Create or edit every `app/...`, `components/...`, `lib/...`, and metadata file path in this guide under `Skin_Lesion_Classification_frontend/`.
- Run all `npm`, `next`, and frontend `make` commands from `Skin_Lesion_Classification_frontend/`.

## Goal

Add safe public SEO pages to the Next.js frontend.

SEO is only for public education and marketing pages. It is not for private patient, doctor, admin, research, analytics, lesion, lab-result, or report pages.

Public pages must explain the product safely using terms like:

```
AI-assisted skin lesion monitoring
Grad-CAM explainability
lesion history
body mapping
privacy modes
doctor-review support
educational, non-diagnostic use
```

What these phrases do: describe the product as educational monitoring and explainability support without making diagnosis or treatment claims.

Avoid unsafe claims:

```
AI skin cancer diagnosis
detect melanoma instantly
replace dermatologist
cancer test from image
AI dermatologist
skin cancer detector
diagnose melanoma online
guaranteed detection
```

What these phrases risk: they imply diagnosis, guaranteed accuracy, or replacing clinicians, which is unsafe for this healthcare/XAI product.

Every public page must include this disclaimer:

```
This platform is not a medical diagnosis tool. It provides educational AI-supported information and helps organize lesion history for professional review.
```

What this disclaimer does: sets the safety boundary for public pages before a user reaches any upload or analysis workflow.

## Prerequisite

Before starting, confirm the frontend build passes:

```powershell
npm run build
```

What this does: runs the Next.js production build so you know the frontend is healthy before adding SEO metadata.

If it fails, fix the build first using `BUILD_FRONTEND.md` before adding SEO.

## Step 1: Add Site URL Environment Variable

Edit:

```
.env.local
```

**What this file is:** the local-only environment file Next.js reads during development. It is not committed to git and not loaded in production builds. Changes here only affect the local dev server.

Add:

```env
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

What this variable does: gives browser-safe frontend code and Next.js metadata generation the public base URL for local development.

For production, replace the URL with your deployed domain.

Check:

```powershell
Select-String -Path .env.local -Pattern "NEXT_PUBLIC_SITE_URL"
```

What this checks: confirms `.env.local` contains the site URL variable before metadata, robots, or sitemap code depends on it.

Expected result: the variable is set to one browser-safe public site URL.

Why: metadataBase, sitemap URLs, robots sitemap links, and structured data all need the deployed site URL.

## Step 2: Update Base Layout Metadata

Edit:

```
app/layout.tsx
```

**What this file is:** the root layout that wraps every page in the Next.js App Router. Metadata defined here becomes the default for all routes that do not override it. This is where site-wide title templates, Open Graph defaults, and robots settings belong.

Find or create the root metadata export and replace it with:

```tsx
import type { Metadata } from "next";

const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "Skin Lesion AI Monitoring Platform",
    template: "%s | Skin Lesion AI Monitoring Platform",
  },
  description:
    "An educational AI-assisted skin lesion monitoring platform with Grad-CAM explainability, lesion history, privacy controls, and doctor-review support.",
  applicationName: "Skin Lesion AI Monitoring Platform",
  keywords: [
    "skin lesion monitoring",
    "Grad-CAM explainability",
    "AI medical imaging education",
    "lesion history tracking",
    "explainable AI healthcare",
  ],
  authors: [{ name: "Saiyudh Mannan" }],
  creator: "Saiyudh Mannan",
  publisher: "Saiyudh Mannan",
  openGraph: {
    type: "website",
    locale: "en_US",
    url: siteUrl,
    siteName: "Skin Lesion AI Monitoring Platform",
    title: "Skin Lesion AI Monitoring Platform",
    description:
      "Educational AI-assisted skin lesion monitoring with explainability, privacy controls, and doctor-review support.",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Skin lesion AI monitoring platform overview",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Skin Lesion AI Monitoring Platform",
    description:
      "Educational AI-assisted skin lesion monitoring with Grad-CAM explainability and privacy-first workflows.",
    images: ["/og-image.png"],
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

What this layout metadata does:

- `Metadata` gives TypeScript the correct shape for Next.js metadata.
- `siteUrl` reads `NEXT_PUBLIC_SITE_URL` and falls back to localhost.
- `metadataBase` lets relative metadata URLs resolve to an absolute site URL.
- `title`, `description`, and `keywords` define safe default SEO text.
- `openGraph` and `twitter` define social preview metadata.
- `robots: { index: true, follow: true }` allows public pages to be indexed by default.
- `RootLayout` wraps every route and sets the page language to English.

Check:

```powershell
npm run build
```

What this checks: verifies Next.js accepts the metadata object and layout component.

Expected result: Next.js accepts the root metadata without errors.

Why: the base layout gives all public pages safe default metadata and Open Graph/Twitter cards. Private pages override this with noindex.

## Step 3: Add Public Page Routes

Create these route folders and placeholder pages:

```powershell
New-Item -ItemType Directory -Force app\about, app\features, app\how-it-works, app\xai-gradcam, app\privacy, app\terms, app\education\what-is-gradcam, app\education\how-to-take-skin-lesion-photo, app\education\ai-limitations
```

What this does: creates the public route folders that Next.js will turn into pages when each folder contains a `page.tsx`.

Create a basic page in each. For example, `app/about/page.tsx`:

```tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "About",
  description:
    "Learn about the Skin Lesion AI Monitoring Platform - an educational tool for tracking and understanding skin lesions with AI-assisted analysis.",
  alternates: {
    canonical: "/about",
  },
};

export default function AboutPage() {
  return (
    <main className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">About</h1>
        <p className="text-gray-600">
          This platform is an educational support tool. It is not a medical
          diagnosis system.
        </p>
      </div>
    </main>
  );
}
```

What this page does:

- Exports route-specific metadata for `/about`.
- Sets a canonical URL so search engines know the preferred page address.
- Renders one safe public page with an H1 and medical-safety language.

Repeat the page pattern for each public page. Each route needs matching metadata, canonical URL, default function name, and visible H1:

| File path | Route | Title / H1 | Canonical | Default function |
|---|---|---|---|---|
| `app/features/page.tsx` | `/features` | Features | `/features` | `FeaturesPage` |
| `app/how-it-works/page.tsx` | `/how-it-works` | How It Works | `/how-it-works` | `HowItWorksPage` |
| `app/xai-gradcam/page.tsx` | `/xai-gradcam` | Grad-CAM Explainability | `/xai-gradcam` | `XaiGradcamPage` |
| `app/privacy/page.tsx` | `/privacy` | Privacy Policy | `/privacy` | `PrivacyPage` |
| `app/terms/page.tsx` | `/terms` | Terms of Service | `/terms` | `TermsPage` |
| `app/education/what-is-gradcam/page.tsx` | `/education/what-is-gradcam` | What Is Grad-CAM? | `/education/what-is-gradcam` | `WhatIsGradcamPage` |
| `app/education/how-to-take-skin-lesion-photo/page.tsx` | `/education/how-to-take-skin-lesion-photo` | How to Take a Skin Lesion Photo | `/education/how-to-take-skin-lesion-photo` | `HowToTakeSkinLesionPhotoPage` |
| `app/education/ai-limitations/page.tsx` | `/education/ai-limitations` | AI Limitations | `/education/ai-limitations` | `AiLimitationsPage` |

What this table does: it gives you the exact file path to create or edit, the route Next.js will expose, the text to use in both `metadata.title` and the page `<h1>`, the canonical URL, and the route-specific component function name.

Use these exact default function declarations:

```tsx
// app/about/page.tsx
export default function AboutPage() {}

// app/features/page.tsx
export default function FeaturesPage() {}

// app/how-it-works/page.tsx
export default function HowItWorksPage() {}

// app/xai-gradcam/page.tsx
export default function XaiGradcamPage() {}

// app/privacy/page.tsx
export default function PrivacyPage() {}

// app/terms/page.tsx
export default function TermsPage() {}

// app/education/what-is-gradcam/page.tsx
export default function WhatIsGradcamPage() {}

// app/education/how-to-take-skin-lesion-photo/page.tsx
export default function HowToTakeSkinLesionPhotoPage() {}

// app/education/ai-limitations/page.tsx
export default function AiLimitationsPage() {}
```

Important: in your real file, keep the function body from the page template. The `{}` above is only showing the exact function name to use for each route.

When you copy the `app/about/page.tsx` example into another route, update all route-specific names in the copied file:

1. Change `metadata.title`.
2. Change `metadata.description`.
3. Change `alternates.canonical`.
4. Change the default function name.
5. Change the visible `<h1>` and page copy.

For example, `app/features/page.tsx` should not still say `AboutPage`:

```tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Features",
  description:
    "Explore educational skin lesion monitoring features including AI-assisted analysis, Grad-CAM explainability, lesion history, privacy modes, and doctor-review support.",
  alternates: {
    canonical: "/features",
  },
};

export default function FeaturesPage() {
  return (
    <main className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">Features</h1>
        <p className="text-gray-600">
          This platform is not a medical diagnosis tool. It provides
          educational AI-supported information and helps organize lesion
          history for professional review.
        </p>
      </div>
    </main>
  );
}
```

What this rename does: `export default function FeaturesPage()` gives the route component a meaningful debug and stack-trace name. Next.js does not require the function name to match the route, but keeping it route-specific prevents confusing copy-paste leftovers such as every page exporting `AboutPage`.

For private pages (dashboard, doctor, admin, research), add noindex metadata in each private route's `page.tsx`.

Current private route in this local frontend:

| Private route | File path | Default function |
|---|---|---|
| `/dashboard` | `app/dashboard/page.tsx` | `DashboardPage` |

Future private routes should use the same pattern when they are created:

| Future private route | Future file path | Default function |
|---|---|---|
| `/doctor` | `app/doctor/page.tsx` | `DoctorPage` |
| `/admin` | `app/admin/page.tsx` | `AdminPage` |
| `/research` | `app/research/page.tsx` | `ResearchPage` |

What this means: only edit private pages that actually exist. Do not create empty doctor/admin/research pages just for SEO. When those pages are built later, add the noindex metadata at the top of their own `page.tsx` files.

Edit:

```text
app/dashboard/page.tsx
```

```tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Patient Dashboard",
  robots: {
    index: false,
    follow: false,
  },
};

export default function DashboardPage() {
  return (
    <main>
      <h1>Patient Dashboard</h1>
    </main>
  );
}
```

What this private metadata does: tells search engines not to index or follow private dashboard routes.

Important: do not add `alternates.canonical` to private pages. A private dashboard must not have a canonical URL pointing to `/about`, `/features`, or any public page. Private pages use `robots: { index: false, follow: false }` instead.

Check:

```powershell
npm run build
```

What this checks: confirms all public and private route files compile with their metadata.

Expected result: all routes build without errors and public pages have unique metadata.

Why: each public page needs its own title and description for search indexing. Private pages must opt out explicitly.

## Step 4: Add robots.ts

Create:

```
app/robots.ts
```

**What this file is:** a special Next.js App Router file that generates `/robots.txt` at build time. Next.js reads the default export from this file and converts it to the standard robots.txt format automatically.

Paste:

```tsx
import type { MetadataRoute } from "next";

const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: [
          "/",
          "/about",
          "/features",
          "/how-it-works",
          "/xai-gradcam",
          "/privacy",
          "/terms",
          "/education",
        ],
        disallow: [
          "/dashboard",
          "/lesions",
          "/analyze",
          "/reports",
          "/doctor",
          "/admin",
          "/research",
          "/api",
        ],
      },
    ],
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
```

What this robots file does:

- `MetadataRoute.Robots` gives the generated robots response the right type.
- `allow` lists public pages crawlers may visit.
- `disallow` blocks private app areas and API routes from crawler access.
- `sitemap` points crawlers to the generated sitemap URL.

Check:

```powershell
npm run build
```

What this checks: confirms Next.js can generate `/robots.txt`.

Expected result: Next.js generates `/robots.txt` at build time.

Why: robots rules tell crawlers what public content to index and what private areas to skip. The sitemap link must use the deployed domain.

## Step 5: Add sitemap.ts

Create:

```
app/sitemap.ts
```

**What this file is:** a special Next.js App Router file that generates `/sitemap.xml` at build time. Next.js reads the array returned by the default export and formats it as a valid XML sitemap.

Paste:

```tsx
import type { MetadataRoute } from "next";

const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

export default function sitemap(): MetadataRoute.Sitemap {
  const publicRoutes = [
    "",
    "/about",
    "/features",
    "/how-it-works",
    "/xai-gradcam",
    "/privacy",
    "/terms",
    "/education/what-is-gradcam",
    "/education/how-to-take-skin-lesion-photo",
    "/education/ai-limitations",
  ];

  return publicRoutes.map((route) => ({
    url: `${siteUrl}${route}`,
    lastModified: new Date(),
    changeFrequency: route === "" ? "weekly" : "monthly",
    priority: route === "" ? 1 : 0.7,
  }));
}
```

What this sitemap does:

- Lists only public routes.
- Builds absolute URLs from `siteUrl`.
- Sets `lastModified`, `changeFrequency`, and `priority` for crawler hints.
- Excludes private patient, doctor, admin, research, analytics, report, lab, and API paths.

Check:

```powershell
npm run build
```

What this checks: confirms Next.js can generate `/sitemap.xml`.

Expected result: Next.js generates `/sitemap.xml` containing only public routes. No dashboard, patient, doctor, admin, lab-result, report, research, analytics, or API URLs.

Why: the sitemap must never include private app URLs or health data paths.

## Step 6: Add Open Graph and Twitter Images

Create or edit these two files:

```
app/opengraph-image.tsx
app/twitter-image.tsx
```

**What these files are:** special Next.js App Router files that generate social preview images for `/og:image` and Twitter card `image` metadata. Next.js serves these as image routes - no manual import is needed. Search engines and social platforms fetch them automatically when they crawl the site.

From the frontend repo, create the files if they do not already exist:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
New-Item -ItemType File -Force app\opengraph-image.tsx
New-Item -ItemType File -Force app\twitter-image.tsx
```

What this does: creates the two special Next.js image route files under the `app/` folder. They must be directly under `app/`, not inside `public/`, `components/`, or a route folder.

Open:

```text
app/opengraph-image.tsx
```

Paste:

```tsx
import { ImageResponse } from "next/og";

export const runtime = "edge";

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: "#f9fafb",
          color: "#1f2937",
          fontFamily: "Arial, sans-serif",
        }}
      >
        <div style={{ fontSize: 56, fontWeight: 700 }}>Skin Lesion AI</div>
        <div style={{ fontSize: 28, color: "#4b5563", marginTop: 18 }}>
          Educational Monitoring Platform
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    },
  );
}
```

Open:

```text
app/twitter-image.tsx
```

Paste:

```tsx
import { ImageResponse } from "next/og";

export const runtime = "edge";

export default function TwitterImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: "#f9fafb",
          color: "#1f2937",
          fontFamily: "Arial, sans-serif",
        }}
      >
        <div style={{ fontSize: 56, fontWeight: 700 }}>Skin Lesion AI</div>
        <div style={{ fontSize: 28, color: "#4b5563", marginTop: 18 }}>
          Educational Monitoring Platform
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    },
  );
}
```

What these image route files do:

- `app/opengraph-image.tsx` generates the Open Graph preview image used by social platforms.
- `app/twitter-image.tsx` generates the Twitter/X card preview image.
- `ImageResponse` generates a 1200x630 image from JSX.
- `runtime = "edge"` uses the runtime expected by Next.js generated image routes.
- The safe public text describes the platform without diagnosis claims.

Do not include patient images, lesion images, private dashboard screenshots, or any health data in social preview images.

Check:

```powershell
npm run build
```

What this checks: verifies the social preview image routes compile.

Expected result: build passes and image routes are generated or static images are found.

Why: social share previews must represent the public product safely and must not leak private health data.

## Step 7: Add JSON-LD Components

Create the folder and files:

```powershell
New-Item -ItemType Directory -Force components\seo
```

What this does: creates a shared folder for SEO helper components.

Create `components/seo/JsonLd.tsx`:

**What this file is:** the base JSON-LD renderer. Other structured-data components import it instead of duplicating the script-tag logic.

```tsx
type JsonLdProps = {
  data: Record<string, unknown>;
};

export function JsonLd({ data }: JsonLdProps) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        __html: JSON.stringify(data).replace(/</g, "\\u003c"),
      }}
    />
  );
}
```

What this component does:

- Accepts structured data as a plain object.
- Emits a JSON-LD script tag for search engines.
- Replaces `<` with `\u003c` to reduce script-injection risk.

Create `components/seo/OrganizationJsonLd.tsx`:

**What this file is:** structured data describing the organization or product owner in schema.org format. Search engines use this to understand who built the product. This is the only JSON-LD component that uses Organization schema - no patient or health data belongs in Organization markup.

```tsx
import { JsonLd } from "./JsonLd";

export function OrganizationJsonLd() {
  return (
    <JsonLd
      data={{
        "@context": "https://schema.org",
        "@type": "Organization",
        name: "Skin Lesion AI Monitoring Platform",
        url: process.env.NEXT_PUBLIC_SITE_URL,
        description:
          "Educational AI-assisted skin lesion monitoring platform with explainability and privacy-first workflows.",
      }}
    />
  );
}
```

What this component does: describes the public organization/product owner in schema.org format without including private health data.

Create `components/seo/SoftwareApplicationJsonLd.tsx`:

**What this file is:** structured data describing the web application in schema.org format, using `SoftwareApplication` type with `applicationCategory: "HealthApplication"`. This tells search engines it is a health-related app without making diagnosis claims.

```tsx
import { JsonLd } from "./JsonLd";

export function SoftwareApplicationJsonLd() {
  return (
    <JsonLd
      data={{
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        name: "Skin Lesion AI Monitoring Platform",
        applicationCategory: "HealthApplication",
        operatingSystem: "Web",
        description:
          "Educational AI-assisted skin lesion monitoring with Grad-CAM explainability, lesion history, and privacy controls.",
        offers: {
          "@type": "Offer",
          price: "0",
          priceCurrency: "EUR",
        },
      }}
    />
  );
}
```

What this component does: describes the web app as a health-related software application while keeping the wording educational and non-diagnostic.

Add these components to `app/layout.tsx` inside the body, before the closing tag:

```tsx
import { OrganizationJsonLd } from "../components/seo/OrganizationJsonLd";
import { SoftwareApplicationJsonLd } from "../components/seo/SoftwareApplicationJsonLd";

// Inside the RootLayout return:
<>
  <OrganizationJsonLd />
  <SoftwareApplicationJsonLd />
  <body>{children}</body>
</>
```

What this layout addition does: renders the JSON-LD scripts globally so public pages have structured data.

Why the imports use `../components/...`: this frontend's `tsconfig.json` does not define an `@/*` path alias. Because `app/layout.tsx` lives inside the `app/` folder, `../components/seo/...` walks up one folder to the frontend root and then into `components/seo/`.

If you see this error:

```text
Cannot find module '@/components/seo/SoftwareApplicationJsonLd'
```

replace the `@/components/...` imports with the two relative imports shown above.

Check:

```powershell
npm run build
```

What this checks: confirms imports and structured-data components compile.

Expected result: TypeScript accepts the structured data components and the build succeeds.

Why: JSON-LD helps search engines understand page content. Medical claims must stay conservative.

## Step 8: Medical Safety Content Check

Run this check from the frontend directory:

```powershell
Select-String -Path app\**\page.tsx -Pattern "not a medical diagnosis|Grad-CAM shows model attention|do not include face"
```

What this checks: searches public page code for required safety language.

Expected result: safety and education language appears in the relevant public pages.

Run this check to confirm no unsafe terms:

```powershell
Select-String -Path app\**\page.tsx, app\layout.tsx, app\sitemap.ts, app\robots.ts, components\seo\*.tsx -Pattern "AI dermatologist|skin cancer detector|diagnose melanoma online|cancer diagnosis from image|replace dermatologist|guaranteed detection"
```

What this checks: searches frontend SEO files for unsafe medical marketing terms.

Expected result: no matches (except inside this guide or an explicit safety test).

Why: medical SEO risk comes from metadata and snippets, not only visible page copy.

## Step 9: Technical SEO Checklist

Before deploying, verify all of these:

```
[ ] app/layout.tsx has base metadata with correct site URL
[ ] each public page has title, description, and canonical URL
[ ] each private page has noindex metadata
[ ] app/robots.ts exists and blocks private routes
[ ] app/sitemap.ts exists and includes only public routes
[ ] app/opengraph-image.tsx exists
[ ] app/twitter-image.tsx exists
[ ] components/seo/JsonLd.tsx and OrganizationJsonLd and SoftwareApplicationJsonLd exist
[ ] public pages use one H1 each
[ ] headings follow logical order (H1 -> H2 -> H3)
[ ] images have alt text
[ ] production domain configured through NEXT_PUBLIC_SITE_URL
[ ] Google Search Console will be added after deployment
```

What this checklist does: gives you a final manual review list before a public deploy.

Run:

```powershell
npm run build
```

What this checks: confirms the finished SEO changes still compile.

Expected result: build passes with no errors or warnings related to metadata.

## Step 10: Vercel Production Environment Variable

If you are deploying on Vercel, do not edit `.env.local` to set the production domain.

Keep `.env.local` for local development:

```env
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

What this local value does: keeps local metadata, sitemap, and robots links pointing to your local frontend while you are working on `http://localhost:3000`.

For Vercel production, set the environment variable in Vercel:

```text
Vercel Dashboard -> your frontend project -> Settings -> Environment Variables
```

Add:

```env
NEXT_PUBLIC_SITE_URL=https://your-production-domain.com
```

Select:

```text
Production
```

Also add a Preview value when you want preview deployments to generate preview URLs:

```env
NEXT_PUBLIC_SITE_URL=https://your-preview-domain.vercel.app
```

Select:

```text
Preview
```

What these Vercel values do: Vercel injects the right value during its build. Production deployments use the production domain. Preview deployments use the preview value. Your local `.env.local` can stay on `http://localhost:3000`.

If you prefer the Vercel CLI after the project is linked, you can add the variable from the frontend repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
vercel env add NEXT_PUBLIC_SITE_URL production
vercel env add NEXT_PUBLIC_SITE_URL preview
```

What these commands do: prompt you for the value and save it into the selected Vercel environment. Do not put secrets in `NEXT_PUBLIC_` variables because they are exposed to the browser bundle.

For a local production-style check before deploying, temporarily set `.env.local` to your expected production URL, run the build, then change it back to localhost:

```powershell
npm run build
```

What this checks: rebuilds metadata outputs after changing `NEXT_PUBLIC_SITE_URL`.

Expected result: the build passes, and deployed `/sitemap.xml` and `/robots.txt` use the Vercel environment value.

Why: Vercel has separate Local, Preview, and Production environments. `.env.local` is for your machine. Vercel Dashboard or `vercel env add` is where production and preview values belong.

## After Deployment

After deploying to a production or staging domain:

1. Add the domain to Google Search Console.
2. Submit the sitemap at `https://your-domain.com/sitemap.xml`.
3. Inspect `/`, `/how-it-works`, `/xai-gradcam`, and `/privacy` in Search Console.
4. Confirm private pages are not indexed.
5. Monitor for crawl errors and Core Web Vitals.

Do not submit dev, local, or private dashboard URLs to Search Console.

## Step 11: Final Docs Check

Run from the project root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
make docs-check
```

What this does: returns to the main workspace and verifies the docs still pass after frontend SEO guide changes.

Expected result: docs-check passes. No conflicts between `BUILD_FRONTEND.md` and this guide.

## End State

After this guide:

- Public pages at `/`, `/about`, `/features`, `/how-it-works`, `/xai-gradcam`, `/privacy`, `/terms`, and `/education/*` have unique metadata, sitemap entries, and robots rules.
- Private routes are blocked from indexing.
- JSON-LD structured data is present on public pages.
- Social preview images are generated.
- Medical safety disclaimer appears on all public pages.
- No unsafe SEO terms are present anywhere in the SEO chain.

## Concepts You Just Touched

- [Role Separation (11.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#114-role-separation) - SEO applies ONLY to public routes; private patient/doctor/admin routes must be no-indexed
- [PHI Tokenization (11.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#111-phi-tokenization) - no PHI ever appears in meta tags, sitemap, or structured data
- [Output Validation (12.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#125-output-validation) - SEO copy must not imply diagnosis or treatment

## Questions You Should Be Able To Answer

1. Why is `robots.txt` insufficient by itself to prevent private route indexing? What else is needed?
2. What is the difference between `noindex`, `nofollow`, and `disallow`? Which combination protects a private route?
3. Why is JSON-LD structured data on public pages valuable but risky on private pages?
4. What is the SEO failure mode if the patient dashboard has a `canonical` link to a public URL?
5. Why must the safety language ("educational AI support, not diagnosis") appear in the meta description, not just the page body?

If you cannot answer Q1-Q3, re-read the robots / sitemap rules.
If you cannot answer Q4-Q5, read [System Design Patterns: 11.4 Role Separation](../reference/09_SYSTEM_DESIGN_PATTERNS.md#114-role-separation).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| Private route appears in Google results | missing `<meta name="robots" content="noindex">` | inspect the `<head>` for that route |
| Sitemap.xml lists a private URL | sitemap generator scanned all routes | filter to public-only |
| Structured data validator complains | schema.org type mismatch | use Google Rich Results test |
| Lighthouse SEO score drops after a refactor | `<title>` or `<meta description>` removed | check the layout file |
| Page indexed but with patient PHI in the title | dynamic title from a private route mis-used | grep `<title>` generation |
