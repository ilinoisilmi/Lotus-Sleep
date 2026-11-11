# Lotus Sleep

An original native SwiftUI sleep diary and planner targeting **iOS 17.0 and later**. The owner uses an iPhone 14 Pro Max; new-version device compatibility still needs acceptance testing. No wearable, account, subscription or cloud service is needed for the core app.

**Version 1.3 update:** practical morning notes with optional reminders, Night Rewind with direct sound replay, fourteen-night personal comparisons, saved sound blends, and good-rest streaks with four optional companions. Includes all prior Lotus rebranding, notification, relaxing-audio, questionnaire, caffeine and tracking improvements. Read **[the current update instructions](Docs/LOTUS_1_3.md)** before uploading/installing.

**Verification:** the original 1.0 device build succeeded in GitHub Actions and the owner installed/opened it. Version 1.3 passes local core, structural, audio-file and syntax checks; **its Xcode build and iPhone acceptance checks are still required**. No updated IPA is included in the source update.

## Start from Windows — no Mac ownership required

Follow **[WINDOWS_START_HERE.md](WINDOWS_START_HERE.md)** for the complete click-by-click route:

1. For an existing installation, upload the cumulative update ZIP's extracted contents to the root of your repository. Your existing `.github` workflow stays in place. For a new repository, follow the full Windows guide.
2. Open **Actions → Build Luma for iPhone → Run workflow**. GitHub's hosted Mac runs the tests and compiles `LumaBasic` for an actual iPhone.
3. After a successful run, download **LumaSleep-unsigned-ipa** under Artifacts and extract its ZIP to obtain the `.ipa`.
4. Use **Sideloadly on Windows**, your own Apple Account and a USB cable to sign and install that IPA. Enable Developer Mode and trust your developer profile when the phone requests them.
5. Test a short diary session, then renew signing within seven days using the same account and bundle ID. Do not uninstall to refresh; export backups regularly.

The workflow needs no Apple signing secrets. It uses GitHub's Actions allowance, with potential overage charges if billing is enabled. The original 1.0 workflow succeeded; this new version needs a fresh successful run and device check. The included IPA packager rejects simulator/source inputs and preserves executable permissions; it does not sign the app.

Optional direct Mac installation, the Health scheme, renewal and diagnostic commands are in **[BUILD_AND_INSTALL.md](Docs/BUILD_AND_INSTALL.md)**.

## What's here

- Today, Track, History, Insights and Settings in SwiftUI; adaptive midnight/daylight colors, semantic text sizes, labeled controls and a low-glare bedside display.
- Manual diary, naps, awakenings, subjective quality, notes/tags, revision history and persistent bedtime sessions.
- Read-only incremental HealthKit integration in the optional `LumaHealth` scheme; preserved provenance and deleted-record handling.
- Conservative Core Motion history suggestions for human review; no fabricated sleep detection.
- Explicit optional microphone sessions: on-device level events, no raw audio retained by default, bounded opt-in full recordings, interruptions and deletion.
- CSV/JSON preview, row errors, duplicate detection, exports, versioned backup/restore and local deletion.
- Interval reconciliation, known-stage timelines, source priority, seven-day history with previous-week navigation, regularity, coverage-aware shortfall and qualified habit comparisons.
- A labeled, unvalidated planning curve with cautious check-in adjustment. Not a medical or performance prediction.
- Weekday/weekend planning, wind-down/bedtime/caffeine/habit notifications with permission status and an explicit test and a fixed wake alarm through AlarmKit on iOS 26+.
- Original white/pink/brown noise, rain-like/ocean-like/fan textures, MP3/M4A/WAV imports, looping, volume and a fade-out timer.
- Morning inbox, editable reminders, fourteen-night experiments, saved sound mixes and optional persistent companion progress.
- A five-part sleep-profile questionnaire, qualified schedule-based rhythm estimates, caffeine logging and age/context-aware guidance.
- App Shortcuts and an optional App Group widget showing only your plan. Demo data is separate and external integrations are disabled in demo mode.

Some requested experiments are deliberately unavailable: mattress mode, smart light-sleep wake, snore classification, apnea detection, global unlock history, direct vendor logins and Apple Health XML import. Supported alternatives and precise verification limits are documented in **[FEATURE_STATUS.md](Docs/FEATURE_STATUS.md)**.

## Project map

| Location | Purpose |
| --- | --- |
| `App/` | App state, native screens, integrations and design system |
| `Core/` | Dependency-free Swift package with models, persistence, reconciliation and calculations |
| `Widget/` | Optional WidgetKit extension |
| `Config/` | iOS target, signing settings, permissions and entitlements |
| `Scripts/` | Reproducible project generation, asset generation and packaging audit |
| `.github/workflows/` | Manually started hosted-Mac build producing an unsigned iPhone IPA |
| `Examples/` | Valid CSV/JSON and a rejection example |
| `Tests/` | Native UI smoke tests; not run here |
| `Docs/` | Installation, feature matrix, data formats, testing and sources |

## Development commands

From this folder on a Mac:

```bash
swift test --package-path Core -j 1 -Xswiftc -disable-batch-mode
python3 Scripts/audit_project.py
xcodebuild -project LumaSleep.xcodeproj -scheme LumaBasic \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LumaSleep.xcodeproj -scheme LumaHealth \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The generated project is already included. When you add or remove Swift files, run `python3 Scripts/generate_project.py`. Use `Config/User.xcconfig` for signing overrides you want the generator to preserve; see the example file. No third-party runtime libraries are needed. Python's standard library is sufficient for project generation and audit. Pillow is needed only to regenerate the included icon. NumPy is needed only to regenerate the bundled original WAV sounds; the app and build workflow do not need it.

Read **[ARCHITECTURE.md](ARCHITECTURE.md)** and **[ADDING_FEATURES.md](ADDING_FEATURES.md)** before modifying persistence or adding an integration.
