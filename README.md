# Jacked by Summer

A native iOS strength and nutrition tracker built for **iOS 27**. Personal, fast to thumb, and — for the core loop — **fully offline**. Every AI feature runs on device with Apple's Foundation Models framework, so there is no server and, apart from one opt-in escalation, no network requirement at all.

This is a native port of an earlier React prototype. The prototype relied on a hosted model over the network for calorie estimation and coaching; that call kept getting refused or dropped. Moving the intelligence on device removes that failure mode and keeps the data private.

## The four tabs

- **Lift** — a two-day chest/shoulders/biceps split logged week to week. Each set shows last week's number as a faint target and lights molten when matched or beaten. Per-exercise and per-session volume deltas, plus "start next week".
- **Bells** — a seven-day single-kettlebell plan, gamified around a daily streak. Flame streak hero, milestone badges (3/7/14/30/60/100 days), a rolling seven-day dot strip, and two benchmark days (max unbroken swings; complex time).
- **Food** — calories and protein against a TDEE with a −500 cut line. Log by description, photo, barcode scan, nutrition-label scan, or plain manual numbers. Day / Week / Month views with Swift Charts.
- **Body** — bodyweight with a denoised (EMA) trend, a deterministic forecast to goal (recency-weighted regression + a calorie cross-check), a trend chart, and an on-device coach that reads the whole app.

## Stack

- **SwiftUI**, targeting iOS 27+ (iPhone only, portrait, dark).
- **SwiftData** for persistence.
- **Swift Charts** for the food bars and weight trend.
- **FoundationModels** for on-device AI: `SystemLanguageModel`, `LanguageModelSession`, guided generation with `@Generable`, the ready-made `BarcodeReaderTool` / `OCRTool`, direct image input, and `GenerationOptions.ToolCallingMode`.
- **Private Cloud Compute** (`PrivateCloudComputeLanguageModel`) as an opt-in escalation only — never the default. It is the only network path in the app.
- **No third-party packages.**

## Design language

Liquid Glass over a dark warm base (`#16130F`). Surfaces are Apple's real glass materials via the SwiftUI glass APIs — no hand-built opaque panels. The molten identity (`#FF7A18`) is used sparingly: the primary action, the streak flame, progress fills, and "beat your target" highlights. Numbers are the hero, set in a condensed bold face. Reduce Transparency, Increase Contrast, and Reduce Motion are all respected.

## Project layout

```
JackedBySummer/
  App/            App entry + root TabView + shared scaffold
  Design/         Palette, typography, warm background, Liquid Glass components
  Models/         SwiftData @Model types + date helpers
  Data/           Static content (lift split, kettlebell plan) + stat/streak helpers
  Forecast/       Deterministic bodyweight forecast (§10 of the brief)
  AI/             Availability, nutrition estimator, coach service
  Features/       Lift / Bells / Food / Body tab views
```

## Building

Open `JackedBySummer.xcodeproj` in Xcode 26 (or later) with the iOS 27 SDK and run on an Apple-Intelligence-capable device or simulator.

> **Verify the AI API names.** Apple shifts Foundation Models and Liquid Glass API shapes between releases. Every spot that leans on an unconfirmed iOS 27 symbol is flagged with a `// VERIFY:` comment — search the project for those and reconcile against the installed SDK. If the on-device model is unavailable, the AI buttons hide themselves and manual entry keeps working.

## Testing

- **Unit / integration tests** — `JackedBySummerTests/`: forecast, streaks, content/model sanity, and SwiftData persistence (incl. the one-per-day upsert).
- **End-to-end UI tests** — `JackedBySummerUITests/`: launch, tab navigation, log a lift, log a kettlebell session (+ streak), add a manual food entry, log bodyweight.
- **Setup** — the test targets need to be added once in Xcode; see [`Tests/SETUP.md`](Tests/SETUP.md). Then run `./scripts/test.sh` (or ⌘U). `./scripts/run.sh` just builds and launches the app in a simulator.
- **Manual QA** — [`QA-CHECKLIST.md`](QA-CHECKLIST.md) covers what needs a human eye (AI output quality, Liquid Glass appearance, accessibility toggles, offline behaviour).
- **What's been verified so far** — see [`VERIFICATION.md`](VERIFICATION.md). The deterministic core was cross-checked against an executed reference implementation (`Tests/reference/verify_core.py`); a static review fixed a Swift 6 concurrency blocker before first build.

## Requirements

- An Apple-Intelligence-capable device for the AI features (checked at runtime via `SystemLanguageModel.default.availability`; the app degrades gracefully when it's not).
- A Mac with **Xcode 26+ / iOS 27 SDK** to build, run, and test — the app cannot be built off macOS.
