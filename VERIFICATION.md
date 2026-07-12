# Verification status

This records exactly what has and has not been verified, and how — so nothing
here is taken on faith.

## Environment note

The build/test work described below was prepared in a **Linux** environment with
**no macOS, no Xcode, and no Swift toolchain** (installing one was blocked by
network egress policy). Therefore **no Swift code has been compiled or run**.
The iOS app must be built and tested on a Mac with Xcode 26+ / the iOS 27 SDK.

## ✅ Verified by execution (independent of Swift/Xcode)

The deterministic core — the pieces most prone to subtle bugs — was mirrored
**line-for-line** into a Python reference implementation
(`Tests/reference/verify_core.py`) and **run**. All assertions pass. Because the
mirror is faithful, an algorithmic bug there would be a bug in the Swift too.

Covered and passing:

- **Forecast (§10):** exact slope recovery on a perfectly linear series (slope
  error → 0), EMA trend, weekly rate, `noData` / `hit` / `stalled` / `slow` /
  `ok` classification (including the flat-vs-slow boundary), calorie
  cross-check (≥4-day rule, average, deficit, implied weekly rate), and
  sooner ≤ central ≤ later window ordering under noise.
- **Streaks:** current streak (today logged, today-missing-but-yesterday,
  neither, gap-break, empty), longest streak (basic, single, empty, all,
  multiple runs), and the rolling seven-day window shape/count.

The Swift unit tests in `JackedBySummerTests/` encode these same vectors, so
once the test target is added (see `Tests/SETUP.md`) they should pass on-device.

## ✅ Verified by adversarial static review

A multi-agent build-readiness review (7 areas, every finding independently
verified to reject false positives) ran over the whole Swift codebase. It
surfaced and **fixed**:

1. **Blocker — Swift 6 concurrency (3 sites):** `static let` `DateFormatter`s in
   `Date+App.swift` are non-`Sendable` and are rejected in Swift 6 language
   mode. Fixed with `nonisolated(unsafe)`.
2. **Low — dead code:** an inert `.swipeActions` on a non-`List` row in
   `FoodView` (deletion already worked via the inline trash button). Removed.

Additionally hardened proactively: `Palette.moltenGradient` changed from a
stored `static let` to a computed `static var` to avoid any Sendable question.

The review **correctly did not touch** the iOS-27 API surface (Liquid Glass,
Foundation Models, Swift Charts). Those remain flagged with `// VERIFY:`
comments because their exact shapes shift between betas and can only be
confirmed against the installed SDK.

## ⚠️ NOT verified here — must be checked on the Mac

- That the app **compiles** against the real iOS 27 SDK (the `// VERIFY:`
  API names in particular).
- Anything requiring the Simulator/device: SwiftUI layout & Liquid Glass
  appearance, SwiftData persistence at runtime, the Foundation Models AI
  (nutrition estimator, coach), camera/photo/barcode/label capture, and the
  XCUITest flows.

Run `./scripts/test.sh` (after `Tests/SETUP.md`) for the automated suite, and
walk `QA-CHECKLIST.md` for the human-eye checks (AI output quality, glass
appearance, accessibility toggles, offline behaviour).
