# SEO And Public Pages Handholding Guide

**This file is a reference and background companion to `docs/local-dev/10_FRONTEND_SEO_HANDHOLDING.md`.**
**The canonical implementation guide is `docs/local-dev/10_FRONTEND_SEO_HANDHOLDING.md`.**

Use this after the customer dashboard and privacy/consent workflows are clear, and before staging or production deployment.

## Command Location

Run documentation checks from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` moves PowerShell into the main workspace.
- Run documentation checks from this folder because the root `Makefile` and `docs/` folder live here.

Run frontend commands from:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
```

What this command does:
- This `cd` moves directly into the Next.js frontend repository.
- Run `npm` and Next.js commands from this folder, not from the root workspace.

Every frontend path in this guide is relative to:

```text
Skin_Lesion_Classification_frontend
```

What this path block means:
- When the guide says `app/layout.tsx`, it means `Skin_Lesion_Classification_frontend/app/layout.tsx`.
- This prevents accidentally creating frontend files in the root docs repo or backend repo.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Frontend repo: `Skin_Lesion_Classification_frontend/`
- Create or edit every `app/...`, `components/...`, `lib/...`, and public-page metadata path in this guide under `Skin_Lesion_Classification_frontend/`.
- This file is a reference companion; use `docs/local-dev/10_FRONTEND_SEO_HANDHOLDING.md` as the canonical implementation path.

## Goal

Add safe public SEO pages to the Next.js frontend.

SEO is only for public education and marketing pages.

SEO is not for private patient, doctor, admin, research, analytics, lesion, lab-result, or report pages.

Public pages should explain the product safely:

```text
AI-assisted skin lesion monitoring
Grad-CAM explainability
lesion history
body mapping
privacy modes
doctor-review support
educational, non-diagnostic use
```

What this public-copy block means:
- These are safe themes for public pages because they describe monitoring, explainability, history, privacy, review support, and education.
- None of these phrases promise diagnosis or treatment.

Avoid keyword stuffing and unsafe claims:

```text
AI skin cancer diagnosis
detect melanoma instantly
replace dermatologist
cancer test from image
AI dermatologist
skin cancer detector
diagnose melanoma online
guaranteed detection
```

What this unsafe-keyword block means:
- These phrases make claims the product must not make.
- They imply diagnosis, cancer detection, clinician replacement, or guaranteed performance.
- Avoid them in page copy, metadata, structured data, titles, and image alt text.

Use safe terms:

```text
AI-assisted monitoring
educational support
model explanation
image quality guidance
doctor-review support
lesion history
privacy-aware health tool
```

What this safe-term block means:
- These phrases describe the app as educational support and monitoring assistance.
- They are safer for SEO because they avoid diagnosis and treatment promises.

Every public page should include this disclaimer:

```text
This platform is not a medical diagnosis tool. It provides educational AI-supported information and helps organize lesion history for professional review.
```

What this disclaimer block means:
- This text should appear on public pages so visitors understand the product boundary.
- It says the app organizes and explains information, but does not diagnose.

Why: public pages can help people understand the project, but search copy must never imply diagnosis, treatment advice, cancer detection, or clinician replacement.

## Step 1: Add Frontend Public Page Files

Create these files and folders:

```text
app/
  layout.tsx
  page.tsx
  about/page.tsx
  features/page.tsx
  how-it-works/page.tsx
  xai-gradcam/page.tsx
  privacy/page.tsx
  terms/page.tsx
  education/
    what-is-gradcam/page.tsx
    how-to-take-skin-lesion-photo/page.tsx
    ai-limitations/page.tsx
  robots.ts
  sitemap.ts
  opengraph-image.tsx
  twitter-image.tsx
```

What this file tree means:
- `app/layout.tsx` defines shared layout and base metadata.
- `app/page.tsx` is the homepage.
- Each `page.tsx` inside a folder creates a public route, such as `/about` or `/privacy`.
- The `education/.../page.tsx` files create educational article routes.
- `robots.ts` generates `/robots.txt`.
- `sitemap.ts` generates `/sitemap.xml`.
- `opengraph-image.tsx` and `twitter-image.tsx` generate social preview images.

Command:

```powershell
New-Item -ItemType Directory -Force app\about, app\features, app\how-it-works, app\xai-gradcam, app\privacy, app\terms, app\education\what-is-gradcam, app\education\how-to-take-skin-lesion-photo, app\education\ai-limitations
```

What this command does:
- `New-Item -ItemType Directory` creates folders.
- `-Force` prevents errors if a folder already exists.
- Each folder corresponds to a Next.js route that will later contain a `page.tsx` file.

Check:

```powershell
Get-ChildItem app -Recurse
```

What this command does:
- `Get-ChildItem app -Recurse` lists everything under the frontend `app` folder.
- Use it to confirm the route directories were created in the correct place.

Expected result: the route folders exist.

Why: Next.js App Router uses `app/` folders and `page.tsx` files to create routes.

## Step 2: Add Site URL Environment Variable

Edit:

```text
.env.local
```

What this path block means:
- `.env.local` is the local environment file for the frontend.
- It should live in `Skin_Lesion_Classification_frontend/.env.local`.

For local development, add:

```env
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

What this local environment variable does:
- `NEXT_PUBLIC_SITE_URL` stores the base URL used by metadata, sitemap, robots, and JSON-LD.
- The `NEXT_PUBLIC_` prefix makes the value available to browser-side Next.js code.
- `http://localhost:3000` is the normal local frontend URL.

For production, use:

```env
NEXT_PUBLIC_SITE_URL=https://your-domain.com
```

What this production environment variable does:
- Replace `https://your-domain.com` with the real deployed domain.
- Production metadata and sitemap URLs must use the public domain, not localhost.

Check:

```powershell
Select-String -Path .env.local -Pattern "NEXT_PUBLIC_SITE_URL"
```

What this command does:
- `Select-String` searches a file for matching text.
- This verifies that `.env.local` contains `NEXT_PUBLIC_SITE_URL`.

Expected result: the frontend has one browser-safe public site URL.

Why: `metadataBase`, sitemap URLs, robots sitemap links, and structured data need the deployed site URL.

## Step 3: Add Base Metadata

Edit:

```text
app/layout.tsx
```

What this path block means:
- Edit the root layout file in the frontend App Router.
- Root metadata defined here becomes the default SEO metadata for pages that do not override it.

Paste or adapt:

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

What this layout code does:
- `import type { Metadata } from "next"` imports only the TypeScript type for Next.js metadata. It does not add runtime JavaScript.
- `siteUrl` reads `NEXT_PUBLIC_SITE_URL` and falls back to `http://localhost:3000`.
- `metadataBase: new URL(siteUrl)` tells Next.js how to resolve relative metadata URLs.
- `title.default` is the fallback title for pages.
- `title.template` formats page-specific titles.
- `description` is the default search/social description.
- `applicationName`, `authors`, `creator`, and `publisher` identify the project owner and app.
- `keywords` lists safe educational terms; avoid unsafe diagnosis keywords here.
- `openGraph` controls previews on platforms that use Open Graph metadata.
- The Open Graph image points to `/og-image.png`; replace it only with a safe public image.
- `twitter` controls Twitter/X card metadata.
- `robots: { index: true, follow: true }` allows public pages to be indexed by default.
- `RootLayout` wraps every page in `<html lang="en">` and `<body>`.
- `children` is the page content Next.js inserts into the layout.

Check:

```powershell
npm run build
```

What this command does:
- `npm run build` runs the Next.js production build.
- It verifies that the metadata object and root layout compile.

Expected result: Next.js accepts the root metadata.

Why: the base layout gives all public pages safe default metadata and Open Graph/Twitter defaults.

If PowerShell says `npm` is not recognized in this local Codex environment, use the bundled Node runtime directly from the frontend repo:

```powershell
C:\Users\saiyu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe node_modules\typescript\bin\tsc --noEmit
C:\Users\saiyu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe node_modules\next\dist\bin\next build
```

What this fallback does:
- The first command runs the same TypeScript type-check that `npm run type-check` would run.
- The second command runs the same Next.js production build that `npm run build` would run.
- Use this fallback only when `node_modules` already exists but `npm` is not available on PATH.

## Step 4: Add Page-Level Metadata

Every public page should have its own metadata.

Create or edit:

```text
app/how-it-works/page.tsx
```

What this path block means:
- Create or edit the public `/how-it-works` page in the frontend.
- This is a public SEO page, so it can have indexable metadata.

Paste:

```tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "How It Works",
  description:
    "Learn how the skin lesion monitoring platform combines image upload, AI classification, Grad-CAM explainability, privacy modes, and doctor-review support.",
  alternates: {
    canonical: "/how-it-works",
  },
};

export default function HowItWorksPage() {
  return (
    <main>
      <h1>How the Skin Lesion AI Monitoring Platform Works</h1>
      <p>
        This platform is an educational support tool. It is not a medical
        diagnosis system.
      </p>
    </main>
  );
}
```

What this page code does:
- `Metadata` is imported as a type for the page metadata object.
- `metadata.title` sets the browser/search title for this page.
- `metadata.description` explains the page in safe, educational language.
- `alternates.canonical` tells search engines the canonical URL for this page.
- `HowItWorksPage` is the React component rendered at `/how-it-works`.
- `<main>` marks the main page content for accessibility.
- `<h1>` gives the page one primary heading.
- The paragraph states the medical safety boundary directly.

For private pages, add `noindex` metadata:

File path example:

```text
Skin_Lesion_Classification_frontend/app/dashboard/page.tsx
```

What this path block means:
- This example points to a private dashboard page.
- Private app pages should not be indexed by search engines.

```tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Patient Dashboard",
  robots: {
    index: false,
    follow: false,
  },
};
```

What this private metadata code does:
- `Metadata` types the metadata object.
- `title` sets the private page title.
- `robots.index: false` tells crawlers not to index the page.
- `robots.follow: false` tells crawlers not to follow links from this page.
- Use this pattern for patient, clinician, admin, research, lab-result, report, and analytics pages.

Check:

```powershell
npm run build
```

What this command does:
- The build checks that public and private metadata exports are valid.
- It also catches TypeScript or App Router syntax mistakes.

Expected result: public pages have unique titles and descriptions, while private pages are blocked from indexing.

Why: public content can be indexed; patient and clinician workflows must not be search pages.

## Step 5: Add robots.ts

Create:

```text
app/robots.ts
```

What this path block means:
- Create `robots.ts` in the frontend `app` folder.
- Next.js uses this file to generate `/robots.txt`.

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

What this robots code does:
- `MetadataRoute` is the Next.js type for metadata route handlers.
- `siteUrl` reads the public base URL and falls back to localhost.
- `robots()` returns the rules used to generate `/robots.txt`.
- `userAgent: "*"` applies the rules to all crawlers.
- `allow` lists public pages that can be crawled.
- `disallow` lists private app areas and API paths that should not be crawled.
- `sitemap` points crawlers to the generated sitemap URL.

Check:

```powershell
npm run build
```

What this command does:
- It verifies that `app/robots.ts` is valid and can be built by Next.js.

Expected result: Next.js can generate `/robots.txt`.

Why: robots rules tell crawlers what public content is intended for indexing and what private areas should stay out.

## Step 6: Add sitemap.ts

Create:

```text
app/sitemap.ts
```

What this path block means:
- Create `sitemap.ts` in the frontend `app` folder.
- Next.js uses this file to generate `/sitemap.xml`.

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

What this sitemap code does:
- `MetadataRoute` provides the TypeScript type for a Next.js sitemap route.
- `siteUrl` reads the public site URL and falls back to local development.
- `sitemap()` returns an array of sitemap entries.
- `publicRoutes` lists only public pages.
- `.map((route) => ...)` converts each route into a full sitemap object.
- `url` combines the site URL and route path.
- `lastModified: new Date()` marks the page as recently modified at build time.
- `changeFrequency` tells crawlers how often content is expected to change.
- `priority` gives the homepage a higher crawl priority than secondary pages.
- Private dashboard, patient, doctor, admin, lab, report, research, analytics, and API routes are intentionally excluded.

Check:

```powershell
npm run build
```

What this command does:
- It verifies that `app/sitemap.ts` compiles and Next.js can generate the sitemap.

Expected result: Next.js can generate `/sitemap.xml` with only public routes.

Why: the sitemap should never include dashboard, patient, doctor, admin, lab-result, report, research, analytics, or API URLs.

## Step 7: Add Open Graph And Twitter Images

Create:

```text
app/opengraph-image.tsx
app/twitter-image.tsx
```

What this path block means:
- These files define generated social preview images for Open Graph and Twitter/X.
- They belong in the frontend `app` folder.

Start simple with generated image routes or replace them later with branded static images. Do not include patient images, lesion images, lab-result text, report details, or private dashboard screenshots.

Check:

```powershell
npm run build
```

What this command does:
- It confirms that social image routes compile or that replacement static images are available.

Expected result: the build passes and social image routes are generated or static images exist.

Why: share previews should represent the public product safely and must not leak private health data.

## Step 8: Add JSON-LD Components

Create:

```text
components/seo/JsonLd.tsx
components/seo/OrganizationJsonLd.tsx
components/seo/SoftwareApplicationJsonLd.tsx
```

What this file list means:
- `JsonLd.tsx` is the reusable component that outputs JSON-LD.
- `OrganizationJsonLd.tsx` describes the organization/project.
- `SoftwareApplicationJsonLd.tsx` describes the app in schema.org format.

Create the folder:

```powershell
New-Item -ItemType Directory -Force components\seo
```

What this command does:
- It creates the `components/seo` folder.
- `-Force` makes the command safe to rerun if the folder already exists.

Paste into:

```text
components/seo/JsonLd.tsx
```

What this path block means:
- Put the reusable JSON-LD component in this file.
- Other SEO components will import it.

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

What this JSON-LD component code does:
- `JsonLdProps` defines a prop object with one field: `data`.
- `Record<string, unknown>` means `data` is an object with string keys and values of any safe JSON-compatible type.
- `JsonLd` is a React component that renders a `<script>` tag.
- `type="application/ld+json"` tells search engines the script contains structured data.
- `dangerouslySetInnerHTML` is required because JSON-LD must be written as raw script content.
- `JSON.stringify(data)` converts the JavaScript object into JSON text.
- `.replace(/</g, "\\u003c")` escapes `<` characters to reduce script-injection risk.

Paste into:

```text
components/seo/OrganizationJsonLd.tsx
```

What this path block means:
- Put the organization structured-data component in this file.
- Use it only on public pages.

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

What this organization code does:
- `JsonLd` is imported from the reusable component.
- `OrganizationJsonLd` returns JSON-LD describing the project as an organization.
- `@context` tells search engines this follows schema.org vocabulary.
- `@type: "Organization"` chooses the schema type.
- `name`, `url`, and `description` describe the public project safely.
- `process.env.NEXT_PUBLIC_SITE_URL` uses the same public URL configured earlier.

Paste into:

```text
components/seo/SoftwareApplicationJsonLd.tsx
```

What this path block means:
- Put the software-application structured-data component in this file.
- Use it on public pages where describing the app is appropriate.

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

What this software JSON-LD code does:
- `JsonLd` is reused to output the structured-data script.
- `SoftwareApplicationJsonLd` describes the product as a software application.
- `@type: "SoftwareApplication"` tells search engines this is app metadata, not a medical diagnosis claim.
- `applicationCategory: "HealthApplication"` describes the broad app category.
- `operatingSystem: "Web"` says the app runs in the browser.
- `description` uses safe educational language.
- `offers` describes a zero-price example offer without making clinical claims.

Use JSON-LD on public pages only.

Avoid using structured data to imply clinical claims, diagnosis, medical certification, or doctor replacement.

Check:

```powershell
npm run build
```

What this command does:
- It checks that the JSON-LD components compile as TypeScript/React code.

Expected result: TypeScript accepts the structured data components.

Why: Google supports JSON-LD structured data and uses it to better understand page content, but medical claims must stay conservative.

## Step 9: Public Content Plan

Add these public SEO pages first.

`/`

Target:

```text
AI-assisted skin lesion monitoring platform
```

What this target block means:
- This is the safe search intent for the homepage.
- It frames the product as monitoring support, not diagnosis.

Sections:

```text
what it does
how Grad-CAM explainability helps
lesion history and body mapping
privacy modes
doctor-review support
safety disclaimer
```

What this section block means:
- These are the homepage content sections to build first.
- They explain the app, Grad-CAM, history, body mapping, privacy, doctor-review support, and safety boundary.

`/how-it-works`

Target:

```text
how AI skin lesion monitoring works
```

What this target block means:
- This is the search intent for the `/how-it-works` page.
- It should explain the workflow without promising medical conclusions.

Flow:

```text
upload image
image quality check
AI model output
Grad-CAM explanation
lesion history
doctor review
```

What this flow block means:
- These are the steps the page should explain in order.
- The flow starts with upload and ends with doctor review, reinforcing that AI output is not the final clinical decision.

`/xai-gradcam`

Target:

```text
Grad-CAM explainability for medical image AI
```

What this target block means:
- This is the search intent for the Grad-CAM education page.
- The page should teach model attention, not disease confirmation.

Must include:

```text
Grad-CAM shows model attention, not proof of disease.
```

What this safety sentence means:
- This sentence is required because Grad-CAM can be misunderstood as proof.
- It explains that Grad-CAM shows where the model focused, not whether disease is present.

`/privacy`

Target:

```text
privacy-first skin lesion monitoring app
```

What this target block means:
- This is the search intent for the privacy page.
- It emphasizes privacy controls rather than diagnosis.

Explain:

```text
storage modes
metadata-only mode
thumbnail mode
full clinical history mode
consent
deletion
doctor review
lab result privacy
```

What this privacy-topic block means:
- These are the privacy topics the page should cover.
- They explain storage choices, consent, deletion, doctor review, and lab-result privacy.

`/education/how-to-take-skin-lesion-photo`

Target:

```text
how to take a clear skin lesion photo
```

What this target block means:
- This is the safe search intent for the photo guidance page.
- It teaches better image capture without promising better diagnosis.

Include:

```text
lighting
focus
distance
glare
scale reference
same angle over time
do not include face or identifying details
```

What this photo-guidance block means:
- These are the practical tips the education page should include.
- The privacy warning helps users avoid uploading identifying details.

Check:

```powershell
Select-String -Path app\**\page.tsx -Pattern "not a medical diagnosis|Grad-CAM shows model attention|do not include face"
```

What this command does:
- `Select-String` searches page files for required safety phrases.
- The pattern checks diagnosis disclaimer, Grad-CAM safety wording, and photo privacy advice.

Expected result: safety and education language appears in the relevant public pages.

Why: these pages are useful, safe, and appropriate for organic discovery.

## Step 10: Medical Safety SEO Rules

SEO content must never promise diagnosis, cancer detection, treatment advice, or replacement of a clinician.

Safe terms:

```text
AI-assisted monitoring
educational support
model explanation
image quality guidance
doctor-review support
lesion history
privacy-aware health tool
```

What this safe-term block means:
- These phrases can be used in public SEO content.
- They describe education, monitoring, explainability, image guidance, doctor review, history, and privacy.

Avoid:

```text
AI dermatologist
skin cancer detector
diagnose melanoma online
cancer diagnosis from image
replace dermatologist
guaranteed detection
```

What this avoid block means:
- These phrases should not appear in public content or metadata.
- They imply diagnosis, cancer detection, clinician replacement, or guaranteed results.

Every public page should include:

```text
This platform is not a medical diagnosis tool. It provides educational AI-supported information and helps organize lesion history for professional review.
```

What this required-disclaimer block means:
- This sentence should be visible on public pages.
- It clearly states that the app is educational and supports professional review.

Check:

```powershell
Select-String -Path app\**\page.tsx, app\layout.tsx, app\sitemap.ts, app\robots.ts, components\seo\*.tsx -Pattern "AI dermatologist|skin cancer detector|diagnose melanoma online|cancer diagnosis from image|replace dermatologist|guaranteed detection"
```

What this command does:
- It searches public page code, metadata, sitemap, robots rules, and SEO components for unsafe phrases.
- The expected result is no matches in implementation files.

Expected result: no unsafe terms appear, except inside this guide or an explicit safety test.

Why: medical SEO risk often comes from metadata and snippets, not only visible page copy.

## Step 11: Technical SEO Checklist

Before deployment, verify:

```text
[ ] app/layout.tsx has base metadata
[ ] each public page has title and description
[ ] each private page has noindex metadata
[ ] app/robots.ts exists
[ ] app/sitemap.ts exists
[ ] Open Graph image exists
[ ] Twitter image exists
[ ] public pages use one H1 each
[ ] headings follow logical order
[ ] images have alt text
[ ] public pages are server-rendered where possible
[ ] dashboard/private pages are blocked from indexing
[ ] no patient data appears in metadata, sitemap, logs, OG images, or structured data
[ ] production domain configured through NEXT_PUBLIC_SITE_URL
[ ] Google Search Console added after deployment
```

What this checklist block means:
- Each checkbox is a technical SEO and privacy requirement to verify before deployment.
- The list covers metadata, noindex rules, robots, sitemap, social images, headings, accessibility, private route blocking, patient-data leakage, production domain setup, and Search Console.

Google's developer SEO guide also emphasizes that sites should be secure, fast, accessible, and work on all devices.

Run:

```powershell
npm run build
```

What this command does:
- `npm run build` confirms the frontend can compile for production.
- It also catches metadata route and TypeScript errors before deployment.

Expected result: the frontend builds and the public pages can be crawled without exposing private app URLs.

Why: technical SEO must support the same privacy and safety boundaries as the product.

## Step 12: Add Search Console After Deployment

Once you deploy a public production or staging domain:

```text
1. Add the domain to Google Search Console.
2. Submit sitemap: https://your-domain.com/sitemap.xml.
3. Inspect /, /how-it-works, /xai-gradcam, and /privacy.
4. Confirm private pages are not indexed.
5. Monitor indexing, crawl errors, and Core Web Vitals.
```

What this deployment checklist means:
- These are the steps to perform after a real domain is deployed.
- Search Console should receive the sitemap and inspect only safe public routes.
- Private app routes should not be intentionally submitted.

Do not submit dev, local, or private dashboard URLs.

Check:

```text
Google Search Console shows the sitemap as discovered or successful.
Private dashboard, lesion, doctor, admin, research, analytics, lab-result, report, and API pages are not intentionally submitted.
```

What this Search Console check means:
- Search Console should confirm the sitemap was discovered or accepted.
- The submitted URLs should be public pages only.
- Private product routes and APIs must stay out of manual submission.

Expected result: only safe public pages are discoverable through Search Console.

Why: Search Console is a deployment step, not a local development step.

## Step 13: Final Checks

Run from the frontend repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_frontend
npm run build
```

What this frontend check does:
- The first line moves into the frontend repository.
- `npm run build` runs the production build from the correct folder.

Run from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
make docs-check
```

What this docs check does:
- The first line moves back to the main workspace.
- `make docs-check` runs the project documentation validation target.

Expected result:

```text
frontend build passes
docs-check passes
public routes have safe metadata
private routes are noindex or disallowed
no patient data appears in SEO files
```

What this expected-result block means:
- The SEO work is done only when the frontend builds, docs checks pass, public routes use safe metadata, private routes are blocked from indexing, and SEO files contain no patient data.

Why: the implementation is complete only when code builds and the root docs agree with the new guide.

## Worker-Ready Short Instruction

Give this to an implementation worker:

```text
Add SEO support to the Next.js frontend and document it in the main repo.
```

What this worker instruction means:
- This is a short handoff prompt for a future implementation worker.
- It summarizes the task but does not replace the detailed beginner steps above.
