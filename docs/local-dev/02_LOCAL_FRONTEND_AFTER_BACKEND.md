# Local Frontend After Backend

Only start this after the backend `/health` endpoint works.

## Goal

Connect the frontend to the backend API and verify one upload flow works before adding more complexity.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Step 1 below then navigates into the frontend repo. Starting here ensures the relative `cd` path works correctly.

After Step 1, every command in this guide runs from:

```text
Skin_Lesion_Classification_frontend
```

**What this means:** npm commands, Next.js builds, and env file edits all happen inside the frontend repo directory. Running them from the workspace root will fail because `package.json` is inside `Skin_Lesion_Classification_frontend`, not at the workspace root.

## Why This Comes After Backend

The frontend needs a real API contract. If you build screens before the backend shape exists, you will rewrite the UI later.

## Step 1: Go To The Frontend Repo

```powershell
cd Skin_Lesion_Classification_frontend
Get-ChildItem
```

What this does:

- `cd Skin_Lesion_Classification_frontend` moves from the project root into the frontend app folder.
- `Get-ChildItem` lists the files in that folder so you can confirm you are editing and running commands in the correct place.

## Step 2: Install Dependencies

```powershell
make install
```

What this does: `make install` runs the frontend Makefile's `install` target, which calls npm to install the packages listed in `package.json`.

Check:

```powershell
make build
```

What this does: `make build` runs the Next.js production build. It proves the TypeScript, React, and Next.js app compile before you start adding UI complexity.

Why: the frontend Makefile wraps the Next.js scripts so the root workspace can call the same commands later.

If `make install` succeeds but npm warns about a vulnerable Next.js version, do not run the forced audit fix during this beginner local-dev path.

First run the narrow patch update from this exact directory:

```powershell
npm install next@14.2.35
make build
npm audit
```

What this does:

- `npm install next@14.2.35` updates only the Next.js package to the patched 14.x version and updates `package-lock.json`.
- `make build` confirms that the frontend still compiles after the patch update.
- `npm audit` reports remaining dependency security findings without automatically changing package versions.

Expected result:

```text
Next.js builds successfully on 14.2.35.
```

If `npm audit` still says the remaining fix would install a newer major version such as `next@16.x`, stop there and continue this local guide. Do not run:

```powershell
npm audit fix --force
```

**Why not:** `--force` bypasses npm's safety check that prevents major version upgrades. Running it here can jump from Next.js 14 to 15 or 16, which has breaking changes in the App Router API. The frontend code in this guide was written for Next.js 14 - a forced major upgrade would break the build and distract from the actual goal of proving the upload flow works.

Why: `npm audit fix --force` can jump to a breaking Next.js major version and distract from the goal of this guide, which is to prove the local frontend-to-backend upload flow first. Treat a Next 15/16 upgrade as a separate planned dependency-upgrade task before production deployment.

## Step 3: Add One API Config Value

Create the local frontend env file:

```powershell
Copy-Item .env.example .env.local
```

What this does: copies the sample frontend environment file to the local-only file Next.js reads during development.

It should contain:

```text
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

What this value means:

- `NEXT_PUBLIC_` tells Next.js this value is safe to expose to browser code.
- `API_BASE_URL` is the backend address the upload form will call.
- `http://localhost:8000` matches the FastAPI server from the backend guide.

The file path is:

```text
Skin_Lesion_Classification_frontend/.env.local
```

**What this path means:** `.env.local` is Next.js's local-only override file. It is not committed to git and is not loaded in CI or production builds. This is intentional - it lets each developer point at their own local backend without affecting other environments. Next.js loads it automatically during `next dev`.

Why: the frontend should not hardcode the backend URL, and browser code should only receive `NEXT_PUBLIC_*` values.

## Step 4: Build One Screen

Edit this file:

```text
Skin_Lesion_Classification_frontend/app/page.tsx
```

**What this file is:** `app/page.tsx` is the Next.js App Router file that maps to the root URL `/`. It is the first page a user sees when they open the frontend.

Replace the scaffold page with this minimal upload screen:

```tsx
"use client";

import { FormEvent, useState } from "react";

type AnalysisResult = {
  label: string;
  confidence: number;
  explanation?: string;
};

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

export default function HomePage() {
  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string>("");
  const [isLoading, setIsLoading] = useState(false);

  async function submitImage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setResult(null);
    setError("");

    if (!file) {
      setError("Choose an image before running the analysis.");
      return;
    }

    const formData = new FormData();
    formData.append("image", file);

    setIsLoading(true);
    try {
      const response = await fetch(`${API_BASE_URL}/api/v1/analysis`, {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        throw new Error(`Backend returned ${response.status}`);
      }

      const data = (await response.json()) as AnalysisResult;
      setResult(data);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Unknown error";
      setError(`Could not analyze the image. ${message}`);
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <main className="shell">
      <section className="panel">
        <p className="eyebrow">Skin Lesion XAI</p>
        <h1>Upload a lesion image</h1>
        <p>
          This is not a medical diagnosis. The AI result is supportive information only.
          Please consult a qualified clinician for medical concerns.
        </p>

        <form className="upload-form" onSubmit={submitImage}>
          <label htmlFor="image">Image file</label>
          <input
            id="image"
            name="image"
            type="file"
            accept="image/png,image/jpeg,image/webp"
            onChange={(event) => setFile(event.target.files?.[0] ?? null)}
          />
          <button type="submit" disabled={isLoading}>
            {isLoading ? "Analyzing..." : "Run analysis"}
          </button>
        </form>

        {error ? <p className="error">{error}</p> : null}

        {result ? (
          <section className="result" aria-live="polite">
            <h2>Result</h2>
            <p>
              Label: <strong>{result.label}</strong>
            </p>
            <p>Confidence: {(result.confidence * 100).toFixed(1)}%</p>
            {result.explanation ? <p>{result.explanation}</p> : null}
          </section>
        ) : null}
      </section>
    </main>
  );
}
```

What this code does, line by line:

- `"use client";`
  - Next.js App Router components are Server Components by default.
  - This upload page needs browser-only features: file input, `useState`, form events, and `fetch` from the user's browser.
  - The directive tells Next.js to ship this component to the browser as a Client Component.

- `import { FormEvent, useState } from "react";`
  - `useState` is a React hook. It lets the component remember values that change while the user interacts with the page.
  - `FormEvent` is a TypeScript type. It describes the event object received when a form is submitted.
  - Importing `FormEvent` prevents TypeScript from treating `event` as `any`, so mistakes are caught earlier.

- `type AnalysisResult = { ... }`
  - This defines the shape of the JSON response the frontend expects from the backend.
  - `label: string` means the backend returns a class name such as `"nevus"` or `"benign"`.
  - `confidence: number` means the backend returns a numeric confidence value, expected here as a decimal like `0.82`.
  - `explanation?: string` means the field is optional. The backend may return it, but the UI must still work when it is missing.

- `const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";`
  - `process.env.NEXT_PUBLIC_API_BASE_URL` reads the backend URL from `.env.local`.
  - `NEXT_PUBLIC_` is required because this value is used in browser code. Next.js does not expose ordinary server-only environment variables to the browser.
  - `?? "http://localhost:8000"` is a fallback. If the env var is missing, the page still calls the local FastAPI server.

- `export default function HomePage() { ... }`
  - This is the page component Next.js renders for `app/page.tsx`.
  - `export default` is required because Next.js looks for the default export in page files.

- `const [file, setFile] = useState<File | null>(null);`
  - `file` stores the image selected by the user.
  - `setFile` updates that value when the user picks a file.
  - `File | null` means the value is either a browser `File` object or `null` before the user selects anything.

- `const [result, setResult] = useState<AnalysisResult | null>(null);`
  - `result` stores the successful backend response.
  - It starts as `null` because no analysis has been run yet.
  - When the backend returns JSON, `setResult(data)` stores it so React can re-render the result section.

- `const [error, setError] = useState<string>("");`
  - `error` stores a user-facing error message.
  - It starts as an empty string, which means "show no error."
  - The UI renders the error paragraph only when this string has content.

- `const [isLoading, setIsLoading] = useState(false);`
  - `isLoading` tracks whether a request is currently running.
  - It disables the submit button so the user cannot start duplicate uploads.
  - It also changes the button text from `Run analysis` to `Analyzing...`.

- `async function submitImage(event: FormEvent<HTMLFormElement>) { ... }`
  - This function runs when the form is submitted.
  - `async` lets the function use `await` while calling the backend.
  - `FormEvent<HTMLFormElement>` tells TypeScript this event came from a form element.

- `event.preventDefault();`
  - Browsers normally reload the page when a form submits.
  - React apps usually prevent that reload and handle the submission in JavaScript.
  - Without this line, the selected file and state would be lost on submit.

- `setResult(null); setError("");`
  - These clear old output before starting a new request.
  - This prevents the previous result or error from staying visible while a new image is being analyzed.

- `if (!file) { ... return; }`
  - This validates that the user selected an image before submitting.
  - If no file exists, the function sets a readable error and stops.
  - `return` is important because the code should not call the backend with an empty upload.

- `const formData = new FormData();`
  - `FormData` is the browser API for multipart form uploads.
  - File uploads should not be sent as normal JSON because image bytes are binary data.

- `formData.append("image", file);`
  - Adds the selected file to the form body.
  - The field name is `"image"` because the backend endpoint expects a multipart field with that exact name.

- `setIsLoading(true);`
  - Marks the request as in progress before calling `fetch`.
  - The UI uses this to disable the button and show loading text.

- `const response = await fetch(...);`
  - Sends the image to the backend.
  - The URL is `${API_BASE_URL}/api/v1/analysis`, which becomes `http://localhost:8000/api/v1/analysis` during local development.
  - `method: "POST"` is used because the frontend is sending data to create/run an analysis.
  - `body: formData` sends the image as multipart form data.
  - Do not set the `Content-Type` header manually here; the browser adds the correct multipart boundary automatically.

- `if (!response.ok) { throw new Error(...) }`
  - `response.ok` is true for HTTP 2xx responses.
  - If the backend returns 400, 404, 500, or another error, this turns it into a JavaScript exception.
  - The `catch` block below converts that exception into visible UI text.

- `const data = (await response.json()) as AnalysisResult;`
  - Reads the backend JSON response.
  - `as AnalysisResult` tells TypeScript to treat the parsed JSON as the response type defined above.
  - This does not validate the backend at runtime; it is a TypeScript compile-time hint.

- `setResult(data);`
  - Stores the successful result in React state.
  - React re-renders the page, and the result section becomes visible.

- `catch (caught) { ... }`
  - Handles network failures, backend errors, and unexpected exceptions.
  - The `caught instanceof Error` check safely extracts a message when the caught value is a real Error object.
  - `setError(...)` makes the failure visible to the user.

- `finally { setIsLoading(false); }`
  - `finally` runs whether the request succeeds or fails.
  - This guarantees the button is re-enabled after the request finishes.

- `<main className="shell">`
  - `<main>` marks the primary content of the page for browsers and assistive technology.
  - `className="shell"` applies existing CSS layout styles.

- `<form className="upload-form" onSubmit={submitImage}>`
  - Creates the upload form.
  - `onSubmit={submitImage}` connects the form submit event to the function above.

- `<label htmlFor="image">Image file</label>`
  - Labels the file input.
  - `htmlFor="image"` connects the label to the input with `id="image"`, improving accessibility.

- `<input ... type="file" accept="image/png,image/jpeg,image/webp" ... />`
  - Renders the browser file picker.
  - `accept` hints that only PNG, JPEG, and WebP images should be selected.
  - `onChange` reads the first selected file and stores it with `setFile(...)`.

- `<button type="submit" disabled={isLoading}>`
  - Submits the form.
  - `disabled={isLoading}` prevents repeated clicks while the backend request is running.
  - The text changes based on `isLoading`.

- `{error ? <p className="error">{error}</p> : null}`
  - This is conditional rendering.
  - If `error` has text, React renders the paragraph.
  - If `error` is empty, React renders nothing.

- `{result ? (...) : null}`
  - This renders the result section only after a successful backend response.
  - Before analysis, `result` is `null`, so the result UI is hidden.

- `<section className="result" aria-live="polite">`
  - Groups the result content.
  - `aria-live="polite"` tells screen readers to announce the new result when it appears without interrupting the user.

- `{(result.confidence * 100).toFixed(1)}%`
  - Converts a decimal confidence like `0.82` into a display value like `82.0%`.
  - `toFixed(1)` keeps one digit after the decimal point.

- `{result.explanation ? <p>{result.explanation}</p> : null}`
  - Shows the explanation only if the backend included one.
  - This protects the UI from crashing when the optional field is absent.

Then edit:

```text
Skin_Lesion_Classification_frontend/app/styles.css
```

**What this file is:** the global CSS file loaded for every page in the Next.js app. Adding upload-specific styles here keeps everything in one place while the app is small. Split into component-level CSS modules once the codebase grows.

Add this to the bottom of the file:

```css
.upload-form {
  display: grid;
  gap: 12px;
  margin-top: 24px;
}

.upload-form label {
  font-weight: 700;
}

.upload-form input {
  border: 1px solid #c8d1d6;
  border-radius: 6px;
  padding: 10px;
}

.upload-form button {
  width: fit-content;
  border: 0;
  border-radius: 6px;
  background: #245c58;
  color: #ffffff;
  cursor: pointer;
  font-weight: 700;
  padding: 10px 14px;
}

.upload-form button:disabled {
  cursor: wait;
  opacity: 0.7;
}

.error {
  margin-top: 20px;
  color: #9b1c1c;
  font-weight: 700;
}

.result {
  margin-top: 24px;
  border-top: 1px solid #d8dee4;
  padding-top: 20px;
}

.result h2 {
  margin: 0 0 12px;
  font-size: 1.25rem;
}
```

What this CSS does:

- `.upload-form` uses a simple vertical grid so label, input, and button have consistent spacing.
- The `input` rules make the file picker visually match the rest of the form.
- The `button` rules create a clear primary action without depending on a component library yet.
- `button:disabled` shows that the app is waiting for the backend.
- `.error` makes backend or validation failures visible.
- `.result` separates successful output from the upload controls.

Why: this creates the smallest useful frontend workflow. It proves file selection, backend communication, loading state, error state, and result rendering before you build dashboards.

The backend mock endpoint this page expects is:

```text
POST /api/v1/analysis
multipart form field: image
```

**What this contract means:** the frontend sends a multipart POST with the image file in a field named `image`. If the backend uses a different field name (like `file` or `photo`), the backend will receive nothing and return an error. The field name must match exactly on both sides.

Expected JSON:

```json
{
  "label": "nevus",
  "confidence": 0.82,
  "explanation": "Mock result for local development."
}
```

**What this response shape means:** `label` is the predicted class name shown to the user. `confidence` is a decimal between 0 and 1 - the frontend multiplies by 100 to display as a percentage. `explanation` is optional (the `?` in the TypeScript type) - the frontend renders it when present and hides it when absent.

If your backend guide used a different path or response shape, update this frontend page only after the backend test proves the new contract.

Do not build dashboards yet.

## Step 5: Run The Check

```powershell
make dev
```

**What this does:** runs `next dev` via the Makefile, which starts the Next.js development server with hot reload. Changes to `.tsx` and `.css` files appear in the browser without restarting the server.

Open:

```text
http://localhost:3000
```

**What this is:** the local address Next.js uses by default. Open it in a browser after `make dev` prints "Ready" to see the upload page.

With the backend off, choose an image and click `Run analysis`.

Expected result:

```text
Could not analyze the image.
```

With the backend running and the mock analysis endpoint implemented, choose an image and click `Run analysis`.

Expected result:

- upload button is visible
- loading state appears
- backend error is displayed if backend is off
- result label and confidence are displayed if backend is on

Run the build check from the frontend repo:

```powershell
make build
```

**What this does:** runs `next build`, which type-checks all TypeScript, compiles React components, and bundles assets for production. This catches errors that `next dev` sometimes lets through. If this succeeds, the code is ready to be deployed - not just to run locally.

Expected result:

```text
Next.js creates a production build without TypeScript errors.
```

**What this confirms:** the TypeScript types are correct, there are no missing imports, and Next.js can generate the production bundle. A passing build here is the minimum bar before moving to Docker or cloud deployment steps.

## Stop Point

Stop here until one upload flow works. Do not build doctor/admin dashboards yet.

## Concepts You Just Touched

- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service) - applies to the frontend too: render from props/server data, not module-level state
- [Timeout Budget (2.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#24-timeout-budget) - browser gives up at 15s; backend has less
- [Cache-Aside (4.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#41-cache-aside) - design space for the dashboard later

## Questions You Should Be Able To Answer

1. Why does the frontend depend on the backend `/health` being green before it makes sense to start the dev server?
2. What is `NEXT_PUBLIC_API_BASE_URL` and why is the `NEXT_PUBLIC_` prefix significant?
3. If the backend returns a 500, what should the upload UI show the patient? Why is "an error occurred" insufficient?
4. What is the difference between Server Components and Client Components in Next.js, and which does the upload form need?
5. Why is a hard-coded `localhost:8000` in code worse than an env var?

If you cannot answer Q1-Q3, re-read "Why This Comes After Backend" and the upload-flow steps above.
If you cannot answer Q4-Q5, read [System Design Patterns: 8.5 Signed URLs](../reference/09_SYSTEM_DESIGN_PATTERNS.md#85-signed-urls) and the Next.js docs on the App Router.

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `next: command not found` | dependencies not installed | run `npm install` in frontend repo |
| CORS error in browser console | backend missing CORS middleware for `http://localhost:3000` | check `app/main.py` for `CORSMiddleware` |
| Upload returns empty response | `NEXT_PUBLIC_API_BASE_URL` not set or wrong | check `.env.local` |
| Frontend builds but the upload page is blank | client-side fetch threw before render | open browser devtools console |
| Hot reload not picking up changes | running production build (`next start`) instead of `next dev` | use `npm run dev` |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** `make cloud-status ENV=dev` reports running dev cloud resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms it is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
