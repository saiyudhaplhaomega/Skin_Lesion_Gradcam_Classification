# Accessibility Interaction Specification — Skin Lesion XAI

**Status:** Implementation-ready
**Style:** Clinical Premium
**Conformance target:** WCAG 2.2 Level AA
**Scope:** Keyboard, ARIA, focus management, motion, color/contrast, screen reader, touch, and cognitive accessibility across all screens

This document defines the accessible interaction contract for the product. It is normative: every interactive component must satisfy these rules before it ships. ARIA patterns follow the W3C ARIA Authoring Practices Guide (APG); where a native HTML element provides the semantics, the native element is preferred over ARIA.

---

## 1. Keyboard navigation

Every interactive element is operable by keyboard alone, with no pointer dependency.

### 1.1 Tab order

Tab order follows the visual reading order (DOM order, top-to-bottom, left-to-right). No positive `tabindex` values — only `0` (in flow) and `-1` (programmatically focusable, removed from tab order).

| Screen region | Tab sequence |
|---|---|
| Global | Skip links → header → primary nav → main → complementary (notifications) → contentinfo |
| Upload flow | Step indicator (informational, not focusable) → file input / dropzone → preview controls → primary action (Continue) → secondary (Cancel) |
| Grad-CAM viewer | Overlay toggle → colormap select → opacity slider → view-mode toggle → save / request review |
| Doctor case detail | Image region → heatmap toggle → explanation panel → patient notes → verdict form fields → submit |
| Consent center | Each toggle in document order → storage mode → retention period → save |

Composite widgets (body map, slider, data table) are a **single tab stop**; internal navigation uses arrow keys (§1.2).

### 1.2 Arrow-key navigation within composite widgets

- **Body map (regions):** Roving `tabindex`. Arrow keys move focus between regions in spatial order (Up/Down/Left/Right map to nearest neighbor); `Home`/`End` jump to first/last region. The map is one tab stop; the focused region carries `tabindex="0"`, all others `-1`.
- **Heatmap opacity slider:** Left/Down decrease, Right/Up increase by the step (default 5%); `Home` = 0%, `End` = 100%; `PageUp`/`PageDown` = ±25%. Implement with native `<input type="range">` where possible.
- **Case queue table:** Arrow keys move the focused cell (Up/Down between rows, Left/Right between columns); `Home`/`End` to row start/end; `Ctrl+Home`/`Ctrl+End` to table start/end. Row selection via `Space`.

### 1.3 Activation keys

- **Buttons / pins / icon buttons:** `Enter` and `Space` both activate.
- **Toggles (switch role):** `Enter` and `Space` flip state; state announced via `aria-checked`.
- **Links:** `Enter` activates.
- **Body map pin placement mode:** `Enter`/`Space` places a pin at the focused region.

### 1.4 Escape key

`Escape` consistently means "back out":
- Closes any open modal or overlay dialog (returns focus to trigger, §3).
- Cancels an in-progress operation where reversible (e.g., dismisses a confirmation).
- Exits pin-placement mode on the body map without placing.
- Collapses an open dropdown/menu and returns focus to its trigger.

### 1.5 Focus trap (modals & overlays)

While a modal/overlay with `aria-modal="true"` is open:
- `Tab` from the last focusable element wraps to the first; `Shift+Tab` from the first wraps to the last.
- Focus cannot reach background content (background is `inert` or `aria-hidden="true"`).
- `Escape` closes the modal.
- The trap is released and focus restored on close.

### 1.6 Skip links

Visually hidden links that appear on focus, first in the DOM:
- "Skip to main content" → `#main`
- "Skip to dashboard" → `#dashboard`
- "Skip to analysis" → `#analysis` (Grad-CAM / results screens)

```html
<a class="skip-link" href="#main">Skip to main content</a>
```
```css
.skip-link {
  position: absolute; left: -9999px;
}
.skip-link:focus {
  left: var(--space-md); top: var(--space-md);
  z-index: 1000; padding: var(--space-sm) var(--space-md);
}
```

---

## 2. ARIA attributes

Use semantic HTML first. Apply ARIA only to fill gaps. Never apply a role that conflicts with the element's native role.

### 2.1 Landmarks

| Landmark | Element / role | Purpose |
|---|---|---|
| Banner | `<header>` | App header (one per page) |
| Navigation | `<nav aria-label="Primary">` | Primary nav; label every `nav` |
| Main | `<main id="main">` | Primary content (one per page) |
| Complementary | `<aside aria-label="Notifications">` | Notifications / activity rail |
| Contentinfo | `<footer>` | Footer / legal / disclaimers |

### 2.2 Live regions

| Region | Setting | Use |
|---|---|---|
| Status / progress | `aria-live="polite"` | Analysis progress, "Saving…", queue count changes |
| Toasts / loading | `role="status"` (implicit polite) | Transient confirmations, loading messages |
| Errors (non-blocking) | `aria-live="assertive"` sparingly | Only for time-critical failures |

Analysis progress example:

```html
<div aria-live="polite" role="status">
  Analyzing image — step 2 of 3
</div>
```

Live-region containers must exist in the DOM **before** content is injected; updating text inside a pre-existing region is what triggers announcement.

### 2.3 Labels and descriptions

- **Icon-only buttons** carry `aria-label`: upload (`aria-label="Upload image"`), heatmap toggle (`aria-label="Toggle Grad-CAM overlay"`), close (`aria-label="Close dialog"`).
- **Form inputs** link helper text via `aria-describedby`; link error text by appending the error node's id to `aria-describedby`.

```html
<label for="retention">Retention period</label>
<select id="retention" aria-describedby="retention-help retention-err">…</select>
<p id="retention-help">How long analysis data is stored before deletion.</p>
<p id="retention-err" role="alert" hidden>Select a retention period.</p>
```

### 2.4 State attributes

| Attribute | Applied to |
|---|---|
| `aria-expanded` | Collapsible sections — consent toggles' detail, filter panels, accordion headers |
| `aria-selected` | Body map regions, queue multi-select rows, tabs |
| `aria-checked` | Switches/toggles (role="switch") |
| `aria-modal="true"` | All modal dialogs (with `role="dialog"`) |
| `aria-current` | Active step in a wizard, active nav item |
| `aria-busy="true"` | Container during its own loading state |

### 2.5 Roles

- `role="status"` — toasts and loading messages (polite, atomic).
- `role="dialog"` + `aria-modal="true"` + `aria-labelledby` (heading) for modals.
- `role="alert"` for blocking error messages (interrupts, use sparingly).
- `role="switch"` for binary toggles; `role="slider"` only if not using native `<input type="range">`.

---

## 3. Focus management

| Event | Behavior |
|---|---|
| Screen load | Focus moves to the first interactive element (or the `<h1>` with `tabindex="-1"` for context-heavy screens). |
| Modal open | Focus moves to the modal heading (`tabindex="-1"`) or first interactive control. |
| Modal close | Focus returns to the element that opened it. |
| Wizard step complete | Focus moves to the first element of the next step (or its heading). |
| Async load | Focus is **never** lost to a removed element; if the focused element is replaced, focus moves to its logical successor or a stable container. |

**Visible focus indicator** (all interactive elements, never removed):

```css
:focus-visible {
  outline: 2px solid var(--focus-ring);
  outline-offset: 2px;
}
```

The focus ring must meet ≥ 3:1 contrast against adjacent colors (§5). Never set `outline: none` without an equally visible replacement. During loading/overlay states, background controls are `inert` so focus cannot land on hidden or non-interactive elements.

---

## 4. Motion and animation

All motion is decorative or supportive and must degrade gracefully.

| Animation | Default | Reduced-motion |
|---|---|---|
| Heatmap fade-in | 300ms ease-out | Instant (no fade) |
| Progress spinner | Continuous rotation | Static indicator + polite text status |
| Toast slide-in | 200ms ease-out | Instant appear |
| Card / panel transition | 150ms ease | Instant |
| Loading skeleton | Subtle pulse | Static placeholder |

```css
/* Motion only when the user has not requested reduced motion */
@media (prefers-reduced-motion: no-preference) {
  .heatmap   { transition: opacity 300ms ease-out; }
  .toast     { transition: transform 200ms ease-out; }
  .panel     { transition: 150ms ease; }
  .skeleton  { animation: pulse 1.5s ease-in-out infinite; }
  .spinner   { animation: spin 1s linear infinite; }
}
@media (prefers-reduced-motion: reduce) {
  .heatmap, .toast, .panel, .skeleton, .spinner { transition: none; animation: none; }
}
```

No animation auto-plays without user consent, nothing flashes more than 3 times per second, and no content auto-advances (carousels, wizards) without explicit user action.

---

## 5. Color and contrast

| Item | Minimum ratio |
|---|---|
| Body text | 4.5:1 (WCAG AA) |
| Large text (≥24px, or ≥18.66px bold) | 3:1 |
| UI components & graphical objects | 3:1 |
| Focus indicator vs adjacent colors | 3:1 |

**Color is never the sole information carrier.** Status (benign / monitor / review), errors, and selections always pair color with an icon and/or text label:

- Benign → green + check icon + "Benign"
- Monitor → amber + clock icon + "Monitor"
- Review → red + flag icon + "Needs review"
- Errors → red + alert icon + specific text message

This satisfies WCAG 1.4.1 (Use of Color) and supports color-vision-deficient users.

---

## 6. Screen reader considerations

- **Content images** get descriptive `alt`; **decorative images** get empty `alt=""` (or `role="presentation"`) so they are skipped.
- **Grad-CAM heatmap** alt: `"Grad-CAM heatmap showing areas of interest overlaid on lesion image."` Pair with a text summary of the highlighted region for non-visual users; do not rely on the image alone to convey the explanation.
- **Body map** container: `"Interactive body map. Use arrow keys to navigate regions."` Each region exposes an accessible name (e.g., "Left forearm") and `aria-selected` state.
- **Tables** use `<th scope="col">` / `<th scope="row">`; the table has a `<caption>` or `aria-label`. Sortable columns expose `aria-sort`.
- **Dynamic updates** (analysis done, queue changed, verdict submitted) are announced through the established `aria-live` regions (§2.2) — never silently.

> Clinical safety note: screen-reader output for analysis results stays educational and non-diagnostic, mirroring the visual UI. Confidence and "needs review" framing must be conveyed in text, not implied by color or position alone.

---

## 7. Touch and mobile

- **Touch targets ≥ 44×44px** with adequate spacing; use `pointer: coarse` to enlarge controls (e.g., body-map pins 24px → 32px) on touch devices.
- **No hover-only interactions** — anything available on hover is also available on focus and on tap/click; tooltips are dismissible and reachable.
- **Swipe gestures are an optional enhancement**, never the only way to perform an action (e.g., the heatmap original/overlay swipe also has visible toggle buttons).
- **Pinch-to-zoom is allowed** on image viewers; the viewport must not disable user scaling (`user-scalable=no` and `maximum-scale=1` are prohibited).

```html
<meta name="viewport" content="width=device-width, initial-scale=1">
```

---

## 8. Cognitive accessibility

- **Consistent navigation:** identical placement and labeling of nav, header, and primary actions across all screens.
- **Progress indicators** for every multi-step flow (upload, consent, verdict), showing current step and total (`aria-current="step"`).
- **Confirmation dialogs** for destructive or irreversible actions (delete lesion, withdraw consent, reject lab result) with clear primary/secondary actions and plain-language consequences.
- **Timeout warnings:** before any session/data timeout, warn the user with an option to extend; never expire silently (WCAG 2.2.1).
- **Error messages** are specific, actionable, and non-technical — they state what went wrong and how to fix it (e.g., "Image is too dark to analyze. Retake the photo in better light." not "Error 422: validation failed").

---

## 9. Conformance checklist (pre-ship gate)

A component is releasable only when all apply:

- [ ] Fully operable by keyboard; tab order matches visual order; no keyboard trap (except intentional modal trap with Escape).
- [ ] Visible `:focus-visible` indicator meeting 3:1 contrast.
- [ ] Correct landmarks, roles, names, and states; verified in a screen reader (NVDA or VoiceOver).
- [ ] Live regions announce dynamic changes.
- [ ] Text ≥ 4.5:1, UI/large text ≥ 3:1; color never the sole carrier.
- [ ] Honors `prefers-reduced-motion`; nothing flashes > 3×/sec; no uncontrolled auto-advance.
- [ ] Touch targets ≥ 44px; no hover-only behavior; zoom not disabled.
- [ ] Destructive actions confirmed; multi-step flows show progress; errors are plain and actionable.

---

## Do / Do not

**Do** — provide text/icon alongside color, honor reduced motion, keep focus visible and managed, label every control, make every gesture-driven action also button-driven.

**Do not** — rely on color alone, use flashing content (> 3 flashes/sec), auto-advance flows without user control, trap keyboard users, disable pinch-to-zoom, or remove focus outlines without a visible replacement.
