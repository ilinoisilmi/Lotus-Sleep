# Noxli Sleep 1.1 — archived update guide

Superseded by [Lotus Sleep 1.2](LOTUS_1_2.md). Use the current cumulative package, which includes the 1.1 changes.

Prepared 11 November 2026 for Ilmi's existing Windows → GitHub Actions → Sideloadly installation.

## What changed

- **Noxli Sleep** is the new visible working name, including onboarding, settings, alerts, permission descriptions and Shortcuts. Version is 1.1, build 2. An initial name search did not surface an exact Noxli Sleep listing; this is a working brand, not a claim of worldwide name availability.
- **History opens to the last seven days**, with a bar chart, average across logged days, data coverage and individual daily cards. Previous/next seven-day buttons replace the calendar. Good/mixed/needs-attention labels explain their duration and self-rated-quality rules; missing data is never scored as a poor night.
- **Nighttime help** lets you log a wake-up immediately or retrospectively, choose a reason, add notes and get brief general sleep guidance. It persists across relaunches. Returning to rest keeps the bedtime timer running. Ending the night closes an attached wake-up log, including when ended through Shortcuts.
- **Morning review** offers an explicit button to include logged wake-up intervals. Overlaps are merged and intervals are clipped to your estimated sleep window. Return-to-rest timestamps are estimates to review, not detected sleep onset.
- **Quick duration logging** adds another way to record roughly continuous sleep or a nap, with a wake time and quality rating. It does not infer time in bed or sleep efficiency. Use the detailed diary for awakenings and split sleep.
- **Live sound waveform** shows actual microphone loudness on the bedside and Sound journal screens. Reduce Motion uses a simple level meter.
- **Sound events** use a five-second room calibration and an adaptive loudness threshold, detect sounds lasting at least about 0.3 seconds, and break long events into roughly 30-second sections. They cannot reliably identify the source, snoring, wakefulness or sleep stages.
- **Replay**: enable Save audio for replay before starting. The app retains a full local AAC recording, and an event's Replay button seeks to that event with brief context. With replay off, only event timestamps and levels are saved. Full-recording playback and export are also available after monitoring stops. Legacy recordings use timestamp-based seek positions.

## Install this update from Windows

1. In your currently installed app, export a complete JSON backup before updating.
2. Download and extract `Noxli_Sleep_1.1_Update.zip` on Windows. This ZIP contains changed/new source files, not an IPA.
3. Open [your repository](https://github.com/ilinoisilmi/Luma-Sleep), choose **Add file → Upload files**, and drag in the **contents** of the extracted folder. Keep `App`, `Config`, `Core`, `Docs`, `Tests`, `Widget` and `LumaSleep.xcodeproj` at the repository root. Commit the upload to `main`. Existing files at those paths are replaced; the rest of your project stays present.
4. Open [the existing build workflow](https://github.com/ilinoisilmi/Luma-Sleep/actions/workflows/build-ios.yml), choose **Run workflow → main → Run workflow**. Its current name is still **Build Luma for iPhone**. This update does not require replacing the hidden `.github` folder.
5. After a green run, download **LumaSleep-unsigned-ipa** under Artifacts and extract its ZIP once. The binary filename remains `LumaSleep-unsigned.ipa`; its installed display name is **Noxli Sleep**.
6. Install through Sideloadly with the **same Apple Account and bundle-ID settings** as before. Install over the existing app; do not delete it. No new Apple signing setup or paid account is required by this source update.

The target, bundle identifier, URL scheme and on-device data directory intentionally retain their original identifiers so the upgrade can preserve your installation. The JSON schema migrates from versions 1/2 to version 3; older app versions reject the new schema. Keep the pre-update backup if you might roll back.

## Five-minute acceptance check

1. Open Noxli Sleep and confirm your old history remains. History should show seven daily cards and no calendar; unlogged days should have no score.
2. Use Quick duration to add an estimate, check it in History, and hide that test diary afterward if desired.
3. Start bedtime. Tap **I woke up · help me settle**, choose a reason, close the screen and relaunch the app. Reopen the wake-up, select **Try sleeping again**, then end the night. In the diary review, enable **Estimate time asleep**, set an estimated sleep window that includes the wake-up, and use **Include logged wake-ups**. Confirm that changing the interval changes your sleep estimate. Hide this test diary afterward if needed.
4. Enable **Save audio for replay**, start monitoring, stay quiet for the first five seconds, then speak or make a sound for a second. Check that the waveform responds. Wait a few seconds, stop monitoring, open Sound journal and replay the event. It should play the right section, then stop. Test a recording with retention disabled too: it should offer no audio replay.
5. Start another short recording, lock the phone for a minute, unlock it, stop and replay. Test interruption by a phone call separately before relying on an overnight session. Confirm deletion removes the recording and events.

This environment cannot run Xcode or an iPhone. Local core tests and syntax checks do not establish that the updated app compiles with Apple's SDK or that microphone behavior works on your phone. A green 1.1 cloud build and the checks above are still required.

## Audio and guidance boundaries

Record only where people nearby agree. Recordings stay on-device unless exported. Event-only mode is the default. Retained audio expires on the next cleanup after the configured 1–30 day retention period; it is not included in JSON backups. Sessions stop at 12 hours, 400 MB, low storage, or roughly 6,000 events, and may stop on calls, route changes or force-quitting.

Sound events never automatically alter your sleep totals. Advice is short, offline, reason-based general guidance, not an AI diagnosis or a treatment program. It follows [NIH sleep guidance](https://www.nhlbi.nih.gov/health/insomnia/treatment); the app does not prescribe medication, supplements or sleep restriction.

## Suggested next features — not included in 1.1

1. A morning recap combining your reviewed sleep, wake-ups, sound-event timeline and how rested you feel.
2. Dedicated caffeine amount/time and training-time logs, compared with your own nights after enough data, with clear separation between association and cause.
3. Manual sound labels such as talking, coughing, snoring or room noise, with a keep/delete choice for each event.
4. A gentle recurring wake schedule and optional snooze, with explicit alarm testing and a fallback to the iPhone Clock app.
5. A shareable weekly report of your diary and disturbances for your own review or a healthcare appointment.
