# Jacked by Summer — Manual QA Checklist

Run on an **Apple-Intelligence-capable device** with iOS 27 for full AI coverage,
and once on a **non-capable simulator/device** (or with Apple Intelligence off) to
verify graceful degradation. Automated coverage lives in `JackedBySummerTests` /
`JackedBySummerUITests`; this checklist covers what needs a human eye (AI output
quality, Liquid Glass appearance, accessibility).

Legend: ☐ = to verify.

## 0. Launch & shell
- ☐ App launches in **dark** appearance over the warm charcoal gradient (not flat black).
- ☐ Four tabs in order **Lift · Bells · Food · Body** using the system Liquid Glass tab bar.
- ☐ Content scrolls **behind** the floating tab/nav bars (soft scroll-edge effect).
- ☐ Portrait only; rotating the device does not rotate the UI.

## 1. Lift
- ☐ Week selector shows current week; **‹ ›** browse past/next weeks.
- ☐ **Start Week N+1** creates and moves to the next week.
- ☐ Day 1 / Day 2 segmented toggle switches content.
- ☐ **Superset A** (Day 1) / **Superset B** (Day 2) are grouped with a "back to back, rest after the pair" note; straight sets have **no** superset label.
- ☐ Tapping an exercise expands its form description + one-line cue.
- ☐ Entering a set's weight/reps persists; leaving and returning shows the value.
- ☐ Last week's value appears as a **faint ghost** placeholder for the same set.
- ☐ Meeting/beating last week's set **lights the field molten** (with the flame icon, not colour alone).
- ☐ Per-exercise volume delta vs last week shows ↑ green / ↓ faint.
- ☐ Session total updates with its delta vs the same day last week.

## 2. Bells
- ☐ Streak hero: flame is **lit** when streak > 0, **cold grey** at 0; shows Best and Sessions.
- ☐ **Log today** on a day records a session; logging a different day today **replaces** it (one session per calendar day).
- ☐ Current streak increments correctly day-over-day; a missed day resets per the rules (today missing but yesterday logged still counts).
- ☐ Milestone badges (3/7/14/30/60/100) light **permanently** once longest streak reaches them; progress bar advances to the next.
- ☐ Rolling 7-day dot strip matches logged days; "X / 7" count is correct.
- ☐ Day 1 captures **max unbroken swings** (higher = better); "Best" shows the max.
- ☐ Day 4 captures **complex time** (mm:ss, lower = better); "Best" shows the min.
- ☐ Programming note (keep ballistic days off gym days) is visible.

## 3. Food
- ☐ Day / Week / Month segmented control switches views.
- ☐ Date navigator: ‹ Today ›; **next is disabled** at today (no future).
- ☐ Totals card: calories consumed is the hero number; "left to TDEE" correct; bar marks the **cut line** (TDEE−500); protein bar vs target.
- ☐ **Edit** reveals TDEE and protein-target fields; changes persist and re-flow the bars.
- ☐ Add food (today only) — **manual**: log with just kcal, just protein, both, or neither+name; a completely empty entry is **blocked**.
- ☐ Add food — **description → Estimate** returns a structured estimate; confirm and log (source = text).
- ☐ Add food — **photo → Estimate** (photo passed straight to the model); log (source = photo, camera marker on the row).
- ☐ Add food — **barcode scan** fills the estimate (source = barcode, marker on row).
- ☐ Add food — **label scan** reads the panel and prefers printed numbers (source = label, marker on row).
- ☐ Entry rows show name, macro line, calories, a **confidence tag** for AI entries, a **source marker** for photo/barcode/label, and delete works.
- ☐ **Improve estimate** (Private Cloud Compute) appears **only** on a low-confidence photo estimate and is opt-in; never runs automatically.
- ☐ No photo is stored — only numbers + source flag.
- ☐ Week view: 7 daily bars with TDEE line + dashed cut line; average + delta vs TDEE.
- ☐ Month view: 6 weekly-average bars, same reference lines, 30-day average headline.

## 4. Body
- ☐ Current weight card: latest weight, 7-day change, since-start change (losing shows as the "good" direction), goal progress bar; goal is editable.
- ☐ Log today: field prefilled with last value; logging **upserts** today's value (one per day); footnote about weighing first thing.
- ☐ Forecast card (≥2 entries): trend (denoised) weight, central date with "~N weeks away", the sooner–later window, and **both rates side by side** (scale-trend vs deficit-implied).
- ☐ >1 kg/week trend shows the "ease toward 0.5–0.8 kg/week" note.
- ☐ Diverging rates show the "gap is the signal" line.
- ☐ Fewer than two entries shows the "log at least two weigh-ins" message.
- ☐ Trend chart renders with the goal as a dashed line once ≥2 entries.
- ☐ **Coach** button produces a short (≤~90 words), blunt, specific read that opens with a real win and reconciles scale vs deficit; **Refresh** regenerates; **Deeper review** (PCC) is opt-in.

## 5. AI availability & failure
- ☐ On a non-capable device / Apple Intelligence off: **AI buttons are hidden**, a short note is shown, and **manual entry + all logging still work**.
- ☐ If an estimate or scan throws: a short message appears, manual logging still works, and a **Retry** is offered.

## 6. Offline
- ☐ In Airplane Mode, the entire core loop (all four tabs, logging, estimates via the on-device model, coach read) works. Only **Private Cloud Compute** escalations require network.

## 7. Accessibility (test each toggle in Settings ▸ Accessibility)
- ☐ **Reduce Transparency**: glass surfaces fall back to solid warm cards; all text legible.
- ☐ **Increase Contrast**: text/controls remain legible over glass.
- ☐ **Reduce Motion**: glass morph transitions drop to simple fades; no distracting animation.
- ☐ Deltas and states never rely on colour alone (arrows/icons/labels always present).
- ☐ Dynamic Type: body copy scales; large numbers remain readable.

## 8. Persistence
- ☐ Force-quit and relaunch: all logged data (lifts, kettlebell, food, weight, settings) persists.
