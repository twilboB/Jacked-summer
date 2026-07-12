# Wiring up the test targets

The test **sources** are committed and ready:

- `JackedBySummerTests/` — XCTest unit + SwiftData integration tests
- `JackedBySummerUITests/` — XCUITest end-to-end "user tests" driving all four tabs

They are deliberately **not** wired into `JackedBySummer.xcodeproj` yet. The
project file was authored on a machine without Xcode, and hand-editing
`project.pbxproj` to add targets without Xcode to validate it risks corrupting a
working project. Adding the targets in Xcode takes about two minutes and is
reliable. Do it once:

## 1. Unit test target

1. **File ▸ New ▸ Target… ▸ Unit Testing Bundle.**
2. Product Name: **`JackedBySummerTests`**. Target to be Tested: **JackedBySummer**. Finish.
3. Xcode creates a stub group/file. Delete the stub `.swift` file it generated.
4. In the Project navigator, right-click the `JackedBySummerTests` group ▸ **Add Files to "JackedBySummer"…**, select everything in the repo's `JackedBySummerTests/` folder, and ensure **Target Membership = JackedBySummerTests**.
5. In the target's **Build Settings**, confirm `IPHONEOS_DEPLOYMENT_TARGET` is 27.0 and Swift version 6.

## 2. UI test target

1. **File ▸ New ▸ Target… ▸ UI Testing Bundle.**
2. Product Name: **`JackedBySummerUITests`**. Target to be Tested: **JackedBySummer**. Finish.
3. Delete the stub file, then **Add Files…** from the repo's `JackedBySummerUITests/` folder with **Target Membership = JackedBySummerUITests**.

## 3. Run

```bash
# From the repo root, on a Mac with Xcode 26+ / iOS 27 SDK:
./scripts/test.sh          # unit + UI tests on an auto-picked iPhone simulator
DEVICE="iPhone 17 Pro" ./scripts/test.sh   # or pick a device explicitly
./scripts/run.sh           # just build and launch the app in the simulator
```

Or in Xcode: **⌘U** to run all tests, **⌘R** to run the app.

> **Note on `xcbeautify`:** `scripts/test.sh` pipes through `xcbeautify` if
> present (`brew install xcbeautify`) for readable output, and falls back to
> raw `xcodebuild` if not.

## What the tests cover

| Suite | File | Covers |
|---|---|---|
| Forecast | `ForecastTests.swift` | All five forecast states, exact slope recovery, EMA trend, calorie cross-check, projection window ordering |
| Stats | `StatsTests.swift` | Current/longest streak edge cases, rolling 7-day window, set/session volume, food totals |
| Content & model | `ContentAndModelTests.swift` | Lift split & superset pairing, 7 kettlebell days & benchmarks, date helpers, formatters, enum mappings |
| Persistence | `ModelPersistenceTests.swift` | SwiftData schema round-trip, single-settings-row rule, one-weigh-in-per-day upsert |
| UI (end-to-end) | `JackedBySummerUITests.swift` | Launch, tab navigation, log a lift, log a kettlebell day + streak, add a manual food entry, log bodyweight |

The forecast and streak logic were additionally cross-checked against a
standalone reference implementation that was executed and verified before these
Swift tests were written.
