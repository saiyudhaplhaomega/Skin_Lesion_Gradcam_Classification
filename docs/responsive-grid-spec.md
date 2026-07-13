# Responsive Grid Specification — Skin Lesion XAI

**Status:** Implementation-ready
**Style:** Clinical Premium
**Scope:** Layout grid, breakpoints, spacing, typography, and per-screen responsive behavior

This document is the single source of truth for layout. It is desktop-aware and mobile-capable: every screen has explicit rules at all four breakpoints. No fixed pixel widths for content containers; all widths derive from the grid, fluid percentages, or `max-width` clamps.

---

## 1. Foundations

### 1.1 Base unit

All spacing, sizing, and rhythm derive from a **4px base unit**. Every value in this spec is a multiple of 4.

### 1.2 Grid model

- **12-column** logical grid (columns collapse to 8 on tablet, 4 on mobile).
- **Fluid columns**, fixed gutters, fixed outer margins.
- Content is capped at **max-width 1280px** and centered above that width.
- Column width is never hard-coded; it is computed as:

```
column = (container - (outer_margin * 2) - (gutter * (cols - 1))) / cols
```

### 1.3 Breakpoints

| Token | Range | Columns | Gutter | Outer margin |
|---|---|---|---|---|
| `mobile` | 320px – 767px | 4 | 12px | 16px |
| `tablet` | 768px – 1023px | 8 | 16px | 24px |
| `desktop` | 1024px – 1439px | 12 | 24px | 32px |
| `large` | 1440px+ | 12 (centered) | 24px | 32px, content capped at 1280px |

Breakpoints are **min-width** based in CSS (mobile-first cascade) but every component is **designed at all four sizes** — mobile-first authoring, desktop-first design intent.

---

## 2. Design tokens

### 2.1 Spacing scale (4px base)

| Token | Value | Typical use |
|---|---|---|
| `--space-xs` | 4px | Icon padding, tight inline gaps |
| `--space-sm` | 8px | Control padding, chip spacing |
| `--space-md` | 16px | Card padding, form field gaps |
| `--space-lg` | 24px | Section gaps, gutter (desktop) |
| `--space-xl` | 32px | Outer margin (desktop), block separation |
| `--space-2xl` | 48px | Major section breaks |
| `--space-3xl` | 64px | Hero padding, page-level rhythm |

### 2.2 Grid tokens

```css
:root {
  /* Base */
  --unit: 4px;
  --content-max: 1280px;

  /* Grid (mobile defaults) */
  --grid-cols: 4;
  --grid-gutter: 12px;
  --grid-margin: 16px;

  /* Spacing scale */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;
  --space-2xl: 48px;
  --space-3xl: 64px;

  /* Typography (mobile defaults) */
  --text-base: 14px;
  --text-h2: 16px;
  --text-h1: 20px;

  /* Touch */
  --touch-min: 44px;
  --header-height: 56px;
}

@media (min-width: 768px) {
  :root {
    --grid-cols: 8;
    --grid-gutter: 16px;
    --grid-margin: 24px;
    --text-base: 15px;
    --text-h2: 18px;
    --text-h1: 24px;
    --header-height: 60px;
  }
}

@media (min-width: 1024px) {
  :root {
    --grid-cols: 12;
    --grid-gutter: 24px;
    --grid-margin: 32px;
    --text-base: 16px;
    --text-h2: 20px;
    --text-h1: 28px;
    --header-height: 64px;
  }
}

@media (min-width: 1440px) {
  :root {
    --text-h1: 32px;
    --text-h2: 24px;
  }
}
```

### 2.3 Reference grid container

```css
.grid {
  display: grid;
  grid-template-columns: repeat(var(--grid-cols), 1fr);
  column-gap: var(--grid-gutter);
  row-gap: var(--space-lg);
  padding-inline: var(--grid-margin);
  max-width: calc(var(--content-max) + var(--grid-margin) * 2);
  margin-inline: auto;
  box-sizing: border-box;
}

/* Span helpers — clamp to available columns per breakpoint */
.col-span-full { grid-column: 1 / -1; }
.col-span-half { grid-column: span calc(var(--grid-cols) / 2); }
```

### 2.4 Typography scale per breakpoint

| Breakpoint | Base | H2 | H1 |
|---|---|---|---|
| Mobile | 14px | 16px | 20px |
| Tablet | 15px | 18px | 24px |
| Desktop | 16px | 20px | 28px |
| Large | 16px | 24px | 32px |

Line-height: 1.5 for body, 1.25 for headings. All font sizes resolve from the `--text-*` tokens so a single media query updates the whole scale.

---

## 3. Breakpoint behavior summary

### Mobile (320px – 767px)

Four collapsed columns. Single-column layouts, full-width cards. Navigation collapses to a hamburger menu with a stacked drawer. Upload flow runs as full-screen sequential steps. Body map uses a simplified front/back toggle. Dashboard is a vertical card stack. Heatmap viewer swipes between original and overlay. Base type 14px, H1 20px, H2 16px. **Touch targets ≥ 44px**; primary actions pin to a bottom action bar.

### Tablet (768px – 1023px)

Eight columns. Two-column layouts where content allows. Navigation is a collapsible sidebar (icon-rail when collapsed). Dashboard is a 2-column card grid. Heatmap viewer offers a side-by-side comparison option. Case queue is a scrollable table with a sticky header. Body map is full-size with a side panel. Base type 15px, H1 24px, H2 18px.

### Desktop (1024px – 1439px)

Twelve columns. Full persistent sidebar navigation. Dashboard is a 3-column card grid plus an activity feed rail. Heatmap viewer is a 3-panel layout (original / overlay / slider). Case queue is a full table with an inline detail panel. Body map is full-size with a floating info panel. Base type 16px, H1 28px, H2 20px.

### Large desktop (1440px+)

Twelve columns, centered, content capped at **1280px**. Offers a condensed density option for power users (reduced row height and padding, see §5). Layout accounts for multi-monitor use: modals and slide-overs stay anchored to the content column rather than the viewport edge. Base type 16px, H1 32px, H2 24px.

---

## 4. Screen-specific specifications

Each screen lists layout intent at mobile / tablet / desktop / large. Containers use grid spans, not fixed widths.

### 4.1 Landing page

| Element | Mobile | Tablet | Desktop | Large |
|---|---|---|---|---|
| Hero | Auto height, stacked | Auto height | Full viewport height | Full viewport height, centered |
| Feature grid | 1 column | 2 columns | 3 columns | 3 columns |
| How it works | Vertical steps | Vertical steps | Horizontal steps | Horizontal steps |

Hero CTA is full-width on mobile, inline on tablet+. Feature cards use `grid-template-columns: repeat(auto-fit, minmax(280px, 1fr))` so the count adapts without per-breakpoint overrides.

### 4.2 Patient dashboard

- **Header:** sticky on scroll, height = `--header-height` (64px desktop / 60px tablet / 56px mobile).
- **Card grid:** `repeat(auto-fit, minmax(280px, 1fr))` — yields 1 col mobile, 2 col tablet, 3 col desktop naturally.
- **Activity feed:** dedicated 4-column rail on desktop (right side); full-width block below the cards on mobile/tablet.
- **Notifications:** slide-in panel anchored to the content column on tablet+; full-screen modal on mobile.

### 4.3 Upload flow

- **Step indicator:** horizontal across the top on desktop/tablet; vertical rail on mobile (or compact dots if width is tight).
- **Image preview:** ~60% of content width on desktop (grid span 7 of 12); full-width on mobile.
- **Controls:** docked sidebar on desktop (span 5 of 12); floating bottom action bar on mobile.
- Steps render full-screen on mobile, one per view; multi-pane on desktop.

### 4.4 Grad-CAM viewer

- **Split view:** 50/50 (original vs overlay) on desktop; stacked vertically on mobile.
- **Opacity slider:** horizontal below the image on desktop; vertical alongside the image on mobile to preserve vertical reading space.
- **Toggle controls** (overlay on/off, colormap, view mode): inline button group on desktop; collapsed into a dropdown on mobile.
- Desktop 3-panel mode (original / overlay / slider) only renders at ≥1024px; tablet falls back to side-by-side with the slider beneath.

### 4.5 Doctor dashboard

- **Queue table:** full table desktop; sticky-header scroll on tablet; horizontal scroll within a card on mobile (key columns pinned left).
- **Detail panel:** side-by-side (queue + detail) on desktop; slide-over on tablet; full bottom sheet on mobile.
- **Verdict form:** inline within the detail panel on desktop; bottom sheet on mobile with the submit action pinned above the keyboard.

### 4.6 Body map

- **Map container:** `min-width: 400px`, scales responsively with `aspect-ratio` preserved; never below 400px logical width (horizontal scroll within container if viewport is narrower).
- **Pin markers:** 24px on desktop (pointer), **32px on touch devices** (coarse pointer) for tap accuracy.
- **Info panel:** floating overlay anchored to the tapped pin on mobile; persistent side panel on desktop.
- Front/back is a simple toggle on mobile; both available with a switch on desktop.

```css
@media (pointer: coarse) { .body-map__pin { width: 32px; height: 32px; } }
@media (pointer: fine)   { .body-map__pin { width: 24px; height: 24px; } }
```

### 4.7 Consent center

- **Form layout:** single column on mobile; 2-column (label/control or grouped sections) on desktop.
- **Toggles:** full-width rows on mobile (label left, switch right, full tap row); inline on desktop.
- **Audit log:** paginated table; on mobile each row collapses to a stacked card with action, actor, and timestamp.

---

## 5. Density option (large desktop / power users)

An opt-in **condensed density** mode for ≥1440px reduces vertical padding and row heights without changing the grid. Toggle a `data-density="condensed"` attribute on the app root.

```css
[data-density="condensed"] {
  --space-md: 12px;
  --space-lg: 16px;
  --header-height: 56px;
  --row-height: 36px; /* default comfortable = 48px */
}
```

Density affects spacing and row height only — it never changes column count, gutters, or type scale, so layout integrity is preserved.

---

## 6. Responsive media & assets

- **Always provide `srcset` + `sizes`** for content images (heatmaps, lesion photos, body-map art). Match `sizes` to the grid span the image occupies at each breakpoint.

```html
<img
  src="lesion-800.jpg"
  srcset="lesion-400.jpg 400w, lesion-800.jpg 800w, lesion-1200.jpg 1200w"
  sizes="(min-width: 1024px) 58vw, (min-width: 768px) 50vw, 100vw"
  alt="Lesion image" />
```

- Heatmap overlays render on `<canvas>` or layered `<img>`; size the layer to the container, not a fixed pixel box.
- Use `aspect-ratio` to reserve space and prevent layout shift while images load.

---

## 7. Rules and constraints

**Do**
- Derive all container widths from the grid, fluid percentages, or `max-width` clamps.
- Author mobile-first in CSS, but design and validate every screen at all four breakpoints.
- Keep touch targets ≥ 44px and use `pointer: coarse` to size interactive elements up on touch devices.
- Use `srcset`/`sizes` for every content image.
- Keep all spacing on the 4px scale.

**Do not**
- Use fixed pixel widths for content containers or columns.
- Assume desktop-only layouts or hide functionality behind hover on touch devices.
- Ship responsive images without `srcset`.
- Design mobile-first to the point of ignoring desktop density and information richness.

---

## Appendix A — Computed column widths

Reference only; columns are fluid (`1fr`). Values show the resolved column width at the breakpoint's lower bound.

| Breakpoint | Container | Cols | Gutter | Margin | Column width |
|---|---|---|---|---|---|
| Mobile | 320px | 4 | 12px | 16px | (320 − 32 − 36) / 4 = **63px** |
| Tablet | 768px | 8 | 16px | 24px | (768 − 48 − 112) / 8 = **76px** |
| Desktop | 1024px | 12 | 24px | 32px | (1024 − 64 − 264) / 12 = **58px** |
| Large | 1280px (capped) | 12 | 24px | 32px | (1280 − 64 − 264) / 12 = **79.3px** |

Column width grows with the viewport between breakpoints because columns are `1fr`; the table shows the minimum at each tier.
