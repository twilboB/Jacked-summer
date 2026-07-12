# Building Jacked by Summer locally (with Claude Code)

This app must be built on a **Mac with Xcode 26+ and the iOS 27 SDK** — it can't
be built off macOS. These steps get the code onto your machine and set you up to
build it, run it, and drive Siri.

## 1. Get the repo into ~/Documents/apps

```bash
mkdir -p ~/Documents/apps
cd ~/Documents/apps
git clone https://github.com/twilboB/Jacked-summer.git
cd Jacked-summer
```

(If you were sent a `.zip` instead, unzip it into `~/Documents/apps/` and `cd`
into it — it's the same contents. Cloning is preferred: it stays in sync and
keeps git history so changes can be pushed back.)

## 2. Run Claude Code in local mode here

From inside `~/Documents/apps/Jacked-summer`, either:

- **CLI:** run `claude` in this directory, or
- **IDE:** open the folder in VS Code / Xcode with the Claude Code extension.

Because it's now running on your Mac, Claude has `xcodebuild`, `xcrun simctl`,
and the iOS 27 SDK. Good first prompt:

> Build the app for an iOS 27 simulator, fix anything the compiler rejects
> (start with the `// VERIFY:` spots), then run the tests.

The `// VERIFY:` comments mark the Liquid Glass / Foundation Models / Swift
Charts / App Intents APIs whose exact shape can shift between SDK betas — they're
the most likely first-build fixes.

## 3. Open in Xcode

```bash
open JackedBySummer.xcodeproj
```

Select an iPhone simulator (or your device) and press **⌘R** to run, **⌘U** to
test. Or use the scripts:

```bash
./scripts/run.sh     # build + launch in a simulator
./scripts/test.sh    # unit + UI tests (after step 4)
```

## 4. Add the test targets (one-time, ~2 min)

The unit and UI test **sources** are in `JackedBySummerTests/` and
`JackedBySummerUITests/` but aren't wired into the project yet (hand-editing the
project file without Xcode to validate it risks corrupting it). Add them via
Xcode as described in [`Tests/SETUP.md`](Tests/SETUP.md), then `⌘U` runs
everything.

## 5. Siri / App Intents

The app ships App Intents and an `AppShortcutsProvider` (`JackedBySummer/Intents/`).
Once you **build and run the app once** on a device/simulator, the shortcuts
register automatically. To use them:

1. Simulator/device: **Settings ▸ Apple Intelligence & Siri** — ensure Siri and
   Apple Intelligence are on (Apple Intelligence needs a capable device for the
   food-by-description estimate; the other intents work without it).
2. Try, by voice or in the Shortcuts app:
   - "Log my weight in Jacked by Summer" → Siri asks for the number.
   - "Log a kettlebell session in Jacked by Summer" → pick the day.
   - "Log food in Jacked by Summer" → describe a meal (on-device estimate).
   - "Log calories in Jacked by Summer" → quick manual add.
   - "How many calories do I have left in Jacked by Summer"
   - "What's my streak in Jacked by Summer"
3. In the **Shortcuts app**, all six appear under the app and can be added to the
   Home Screen or automations.

Voice logging writes to the **same store** as the app (`SharedStore.container`),
so a session logged by Siri shows up in the app immediately, and vice-versa.

> Want richer Apple-Intelligence Siri context later (e.g. "how's my cut going")?
> The next step is adopting App Intents **assistant schemas** / an `AppEntity`
> model so Siri can reason over your data. The current App Intents are the
> supported foundation the new Siri already invokes.

## What to expect on first build

The Swift is written to the brief and statically reviewed, but has **not** been
compiled (see [`VERIFICATION.md`](VERIFICATION.md)). Expect a few SDK-name fixes
at the `// VERIFY:` spots — that's exactly what step 2 is for. The deterministic
core (forecast + streaks) was verified against an executed reference and has unit
tests, so those should pass once the target is added.
