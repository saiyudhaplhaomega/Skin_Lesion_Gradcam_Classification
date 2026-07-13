# Microcopy Style Guide — Skin Lesion XAI

**Status:** Implementation-ready
**Style:** Clinical Premium — clear, reassuring, non-technical
**Scope:** Loading, empty, error, confirmation, tooltip, and warning copy across all roles and screens

This guide defines how the product talks to people. It pairs voice principles with the exact, approved strings. Use these strings verbatim where listed; when writing new copy, follow the principles and patterns in §1–§2 so everything reads as one voice.

---

## 1. Voice and tone principles

The product speaks like a calm, competent clinician's assistant — confident but never authoritative about diagnosis, warm but never casual about health.

**Clear** — plain language a non-medical adult understands on first read. No jargon, no acronyms without expansion.

**Reassuring** — steady and supportive, especially in errors and warnings. Reduce anxiety; never amplify it.

**Honest and non-diagnostic** — results are *educational information*, never a diagnosis. Acknowledge uncertainty plainly instead of overclaiming.

**Respectful of agency** — tell people what happened, what it means, and what they can do next. Always offer a way forward.

**Privacy-aware** — be specific and truthful about data handling; never bury or soften legally meaningful facts.

### Tone by context

| Context | Tone | Lead with |
|---|---|---|
| Loading | Calm, brief, sets expectations | What's happening + roughly how long |
| Empty | Encouraging, forward-looking | What this space is for + a next step |
| Error | Reassuring, accountable, actionable | What happened + how to recover |
| Confirmation | Affirming, clear | What succeeded + what happens next |
| Tooltip | Concise, explanatory | What it is / does, in one sentence |
| Warning | Calm, specific, non-alarmist | The limitation + the recommended action |

---

## 2. Writing conventions

- **Headlines:** Title Case, ≤ 5 words, no period.
- **Body:** sentence case, full sentences, 1–2 sentences max.
- **Buttons:** Title Case, verb-first, ≤ 3 words ("Try Again", "View Results").
- **Tooltips:** one sentence, no trailing period unless multiple sentences.
- **Numbers:** spell out under 10 in prose where natural; use digits for durations, sizes, and dates ("10–20 seconds", "10MB", "30 days").
- **Placeholders:** square brackets `[Date]`, `[X] days`, `privacy@example.com` — replace at render time, never show brackets to users.
- **Never** use: alarmist words ("danger", "critical", "failure" toward the user), diagnostic terms ("malignant", "cancerous", "benign tumor" as a verdict), patient identity in tooltips, technical jargon, or passive-aggressive phrasing ("As we already told you…").

---

## 3. Loading states

Keep loading copy to a primary line (what's happening) and an optional secondary line (expectation or reassurance). Pair every spinner with a polite live-region announcement (see accessibility spec).

| Context | Primary | Secondary | Action |
|---|---|---|---|
| Image analysis | Analyzing your image… | This typically takes 10–20 seconds | Cancel Analysis |
| Heatmap generation | Generating explanation heatmap… | Creating a visual breakdown of areas influencing the prediction | — |
| File upload | Uploading your image… | Please keep this page open | — |
| OCR processing | Extracting information from your document… | Reading lab report details | — |
| Doctor review queue | Checking for new cases… | You'll be notified when a case is ready | — |

---

## 4. Empty states

Empty states explain what the space is for and offer a clear first action. Never leave a blank screen.

**No lesions yet**
- Headline: **No Lesions Tracked Yet**
- Body: Upload your first skin image to start building your lesion history. Each image helps you and your doctor monitor changes over time.
- CTA: **Analyze First Image**

**No cases pending review** (Doctor)
- Headline: **No Cases Pending**
- Body: You're all caught up. New submissions will appear here when patients request your review.
- Subtext: Last case reviewed: [Date]

**No notifications**
- Headline: **All Caught Up**
- Body: You have no new notifications. Important updates will appear here.

**No search results**
- Headline: **No Results Found**
- Body: Try adjusting your search terms or filters to find what you're looking for.

---

## 5. Error states

Errors are reassuring and accountable. State plainly what happened, why (if known), that nothing important was lost, and the recovery path. Use "we" for system responsibility; never blame the user.

**Upload failed**
- Headline: **Upload Could Not Be Completed**
- Body: We couldn't upload your image. This might be due to a network issue or the file size exceeding 10MB.
- Actions: **Try Again** · **Contact Support**

**Analysis failed**
- Headline: **Analysis Interrupted**
- Body: Something unexpected happened while analyzing your image. Your image has been saved and you can try again.
- Actions: **Retry Analysis** · **Save for Later**

**Session expired**
- Headline: **Session Ended**
- Body: For your security, your session has timed out. Please sign in again to continue.
- Action: **Sign In Again**

**Network error**
- Headline: **Connection Lost**
- Body: Please check your internet connection and try again.
- Action: **Retry Connection**

---

## 6. Confirmation states

Confirmations affirm success and state what happens next. For results, always restate the non-diagnostic disclaimer.

**Analysis complete**
- Headline: **Analysis Complete**
- Body: Your results are ready. Remember, this is educational information only and is not a medical diagnosis.
- Actions: **View Results** · **Review Disclaimer**

**Review submitted** (Doctor)
- Headline: **Review Submitted**
- Body: Your professional opinion has been saved. The patient will be notified.
- Actions: **Back to Queue** · **View Case**

**Consent updated**
- Headline: **Consent Preferences Saved**
- Body: Your privacy settings have been updated. Changes take effect immediately.
- Actions: **Review Changes** · **Return to Dashboard**

**Deletion requested**
- Headline: **Deletion Request Received**
- Body: Your data will be permanently deleted within 30 days. You can cancel this request during that period.
- Actions: **Cancel Request** · **Confirm**

---

## 7. Tooltip text

One clear sentence each. Explain what something is or does; never reference a specific patient's identity.

| Element | Tooltip |
|---|---|
| Heatmap toggle | Show areas of the image that most influenced the AI prediction |
| Confidence bar | Temperature-scaled confidence reflects model certainty. Higher values indicate more confident predictions. |
| Body map pin | Tap to view lesion history and track changes over time |
| Quality indicator | Indicates how clearly the AI could analyze your image. Low quality may affect prediction accuracy. |
| Doctor review badge | A medical professional has reviewed this case |
| Storage mode | Controls how long your images and data are retained. Higher privacy means shorter retention. |

---

## 8. Warning messages

Warnings are calm and specific. Name the limitation, then the recommended action. Never imply emergency or diagnosis.

**Image quality low**
> Image quality is lower than recommended. For best results, ensure good lighting and a steady hand. The prediction may be less reliable.

**Heatmap noisy**
> The explanation heatmap shows unusual patterns. This may indicate the prediction is less reliable. Professional review recommended.

**Consent expiring**
> Your consent expires in [X] days. Review your preferences to maintain uninterrupted service.

**Consent withdrawn**
- Headline: **Consent Withdrawn**
- Body: Your consent has been withdrawn. Your data will be retained for [X] days as required by law, then permanently deleted.
- Support: Questions? Contact privacy@example.com

---

## 9. Quick reference — string table

For handoff to engineering / localization. Keys are illustrative; align with your i18n namespace.

| Key | String |
|---|---|
| `loading.analysis.primary` | Analyzing your image… |
| `loading.analysis.secondary` | This typically takes 10–20 seconds |
| `loading.analysis.cancel` | Cancel Analysis |
| `loading.heatmap.primary` | Generating explanation heatmap… |
| `loading.heatmap.secondary` | Creating a visual breakdown of areas influencing the prediction |
| `loading.upload.primary` | Uploading your image… |
| `loading.upload.secondary` | Please keep this page open |
| `loading.ocr.primary` | Extracting information from your document… |
| `loading.ocr.secondary` | Reading lab report details |
| `loading.queue.primary` | Checking for new cases… |
| `loading.queue.secondary` | You'll be notified when a case is ready |
| `empty.lesions.headline` | No Lesions Tracked Yet |
| `empty.cases.headline` | No Cases Pending |
| `empty.notifications.headline` | All Caught Up |
| `empty.search.headline` | No Results Found |
| `error.upload.headline` | Upload Could Not Be Completed |
| `error.analysis.headline` | Analysis Interrupted |
| `error.session.headline` | Session Ended |
| `error.network.headline` | Connection Lost |
| `confirm.analysis.headline` | Analysis Complete |
| `confirm.review.headline` | Review Submitted |
| `confirm.consent.headline` | Consent Preferences Saved |
| `confirm.deletion.headline` | Deletion Request Received |
| `warn.quality` | Image quality is lower than recommended… |
| `warn.heatmap` | The explanation heatmap shows unusual patterns… |
| `warn.consentExpiring` | Your consent expires in [X] days… |
| `warn.consentWithdrawn.headline` | Consent Withdrawn |

---

## Do / Do not

**Do** — keep it clear and human, set expectations during waits, take accountability in errors, restate the non-diagnostic disclaimer on results, be specific and truthful about privacy, and always offer a next step.

**Do not** — use alarmist language, use diagnostic terminology as a verdict, reference patient identity in tooltips, expose technical jargon to users, write passive-aggressively, or leave a state with no action.
