# Verification record — Lotus Sleep 1.3, 11 November 2026

The original Luma Sleep 1.0 build succeeded in [GitHub Actions](https://github.com/ilinoisilmi/Luma-Sleep/actions/runs/42980556417), and the owner reported installing and opening it. That result does not validate version 1.3.

The cumulative 1.3 source is checked locally on Linux with Swift 6.2.1. It has not been built with Xcode, rendered in an iOS simulator, signed or installed here. Run the existing cloud workflow after uploading the source update. No new IPA is included.

## Passed locally

- **98 XCTest cases**, zero failures, including 27 new experience tests. Coverage includes schema 4→5 continuity and round trips, mix validation/gain bounds, balanced comparisons, actual-condition grouping, missing/skipped/future reports, DST, current/missing/poor/future sleep-day streaks, per-pet idempotence and permanent looks, timeline clipping/provenance/unknown gaps, and morning-note completion/limits.
- Native Swift syntax parsing passes for **43 shared app/core source files**, with both Basic and `HEALTH_ENABLED` paths, plus widget and twelve native UI test definitions. Parsing does not type-check Apple SDK APIs or execute the native tests.
- The deterministic Xcode project/resource audit passes. The exact structural count is recorded in `Verification/project-audit.txt`; it includes all source paths, schemes, plists, six PCM audio files, the vector companion asset, preserved bundle ID and version 1.3/build 4.
- Four IPA-packaging tests pass on synthetic fixtures. The build shell scripts pass syntax checks. These do not create or validate a real 1.3 device executable.
- The original four-animal/five-stage SVG artwork was rendered to an image and visually inspected for clipping, stage progression and restrained styling. The native sprite cropping and SwiftUI layouts remain unrendered.
- `git diff --check` passes. The remote repository was fetched and still points to original base `bf9a3f38ba4a01558930b2ad9f0362a3598835cc`; local changes have not been pushed.

Actual logs: `Verification/core-tests.txt`, `Verification/project-audit.txt`, `Verification/lotus-1.3-checks.txt`. The Swift Testing runner's separate “0 tests” line is not the XCTest total. Older 1.1/1.2 logs are historical.

## Remaining native acceptance

Xcode compilation of Basic/Health; simulator/UI tests; device install and upgrade; native portrait cropping and accessibility; notification authorization, delivery, cancellation and tap routing; multi-track decoding/synchronization, locked-screen fade/timer and interruption handling; microphone replay; custom-file import/providers; real-world battery and storage behavior. Follow [DEVICE_TESTING.md](DEVICE_TESTING.md).

The questionnaire, caffeine timing buffers, comparisons and rest milestones are transparent product rules, not validated clinical/personality measurements. Audio events never automatically change sleep totals. See [the current update guide](LOTUS_1_3.md).
