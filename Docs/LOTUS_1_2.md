> Historical 1.2 release notes. For the current cumulative update, use [Lotus 1.3](LOTUS_1_3.md). The three ideas below were approved and implemented in 1.3.

# Lotus Sleep 1.2 — cumulative update

Prepared 11 November 2026 for the existing Windows → GitHub Actions → Sideloadly installation. This package includes the previous 1.1 changes; you can update directly from the original Luma Sleep installation.

## What is included

- **Lotus Sleep** is the installed display name. Version 1.2, build 3. Internal project names, signing identifiers and the existing data directory remain unchanged for upgrade continuity.
- **Notifications:** individual wind-down, bedtime and optional caffeine-cutoff switches; current iOS permission status; an explicit test in five seconds; upcoming delivery times; and a notice when schedule/profile edits need reapplying. An existing one-off habit reminder is retained. The app requests notification permission only after a scheduling/test action.
- **Relaxing sounds:** six original generated textures (white, pink and brown noise, rain-like, ocean-like and fan). These are original audio textures rather than field recordings. They play offline, one at a time, with looping, adjustable volume and a 15/30/45/60/90/120-minute timer or “until stopped.” The timer fades during the final ten seconds.
- **Your sounds:** import MP3, M4A and WAV from Files, including downloaded files from iCloud. The private library holds up to 50 files, each 1 second–2 hours and at most 100 MB. Copies remain on-device for future playback; deleting one does not remove the original. Protected or undecodable files are rejected.
- **A five-part sleep questionnaire:** goals, age band, work/free-day sleep times, five original reflection questions, caffeine sensitivity/context, and an editable summary. No name, date of birth, weight or account is required. Saving a profile can optionally apply its wake times to the Monday–Friday/Saturday–Sunday plan.
- **Body-clock estimate:** reported free-day midpoint, a correction for extra free-day sleep, and an early/middle/late schedule tendency with the calculation shown. Free-day alarms, no free days and shift work suppress the adjusted label. This is not a validated personality test, a melatonin measurement, a diagnosis or an exact sleep-need calculation.
- **Caffeine:** consumed-amount/time logs, totals by reporting-timezone calendar day, bedtime-based cutoff, and age/context-aware guidance. Adult users without the listed concerns may choose a tracking cap; it is not a personalized safe dose. Teen profiles receive avoidance guidance and no recommended dose. The app uses an eight-hour buffer for usual sensitivity and a conservative ten-hour option for sensitive/uncertain responses; it does not measure metabolism.
- **Earlier changes included:** seven-day history, transparent good/mixed/needs-attention labels, wake-up logs and general settling advice, quick duration/nap logging, live microphone levels and optional retained-audio replay.

## Find the features

- **Settings → Notifications:** choose types, then **Apply selected reminders**. Use **Send a test in 5 seconds** to check your iPhone. You can also reach it from Plan.
- **Today or Track → Relaxing sounds & your MP3s:** pick a sound or import from Files. Set the timer/loop option before starting; volume stays adjustable during playback. Playback continues when this screen closes or the phone locks, subject to iOS interruptions. Stop is in the sound player; ending bedtime also stops it.
- **Settings → My sleep profile & questionnaire:** complete the five parts or retake/edit them later.
- **Today or Settings → Caffeine guidance & log:** log what you already consumed and review timing. Set the optional caffeine notification separately.
- **History:** the seven-day sleep summary and individual days.

Sleep sounds and microphone monitoring are mutually exclusive. The speaker would otherwise be captured as a sound event. Stop the current mode before starting the other. Microphone-event replay also stops relaxing audio. A phone call, audio-route change or force-quit can stop playback/monitoring; it does not resume without an explicit action.

Notifications are local and work without an internet connection after scheduling. Focus, Silent Mode and notification settings affect delivery; they are not substitutes for a wake alarm. Weekly times follow the reporting timezone. Reapply after schedule, timezone or caffeine-profile edits.

## Update from Windows

1. Export a complete JSON backup from the installed app. Keep original imported sound files separately; JSON contains metadata, not media.
2. Extract `Lotus_Sleep_1.2_Update.zip`. It contains cumulative changed/new **source files**, not an IPA.
3. Open https://github.com/ilinoisilmi/Luma-Sleep → **Add file → Upload files**. Drag the extracted contents into the repository root, keeping folders such as `App`, `Core`, `Config` and `LumaSleep.xcodeproj` directly at that root. Commit to `main`.
4. The existing hidden `.github` workflow does not need replacement. Open https://github.com/ilinoisilmi/Luma-Sleep/actions/workflows/build-ios.yml and select **Run workflow → main → Run workflow**. Its name remains **Build Luma for iPhone**.
5. After a green run, download the **LumaSleep-unsigned-ipa** artifact and extract it. The internal IPA filename remains `LumaSleep-unsigned.ipa`; the installed app says Lotus Sleep.
6. Use Sideloadly with the **same Apple Account and bundle-ID settings**. Install over the existing app without deleting it. Open Lotus and verify your old history before trying the new features.

The source targets iOS 17+. The local environment is Linux: no 1.2 Xcode build, native UI rendering, signing or actual iPhone delivery/playback has been verified here. Run the cloud build and the device checklist before relying on overnight playback, notifications or alarms.

## Data and rollback

Schema 4 migrates from schema 1, 2 or 3 while preserving the existing sleep history. Older versions reject schema 4; keep the pre-update backup if a rollback is needed. The filename `sleep-v2.json` and application identifiers are retained for compatibility.

Profile answers, caffeine logs and audio metadata are included in JSON exports. Actual recordings and imported sound files are not. A deliberate JSON restore replaces local data and removes old media copies after the in-app preview; reimport your original MP3/M4A/WAV files afterward. Installing this update over the app does not perform a restore or intentionally delete its media.

## Quick acceptance check

1. Confirm the new display name and preserved history. Test notifications while foregrounded and locked, then turn them off and verify the pending list clears.
2. Complete the profile; relaunch and edit it. Check the teen/adult caffeine wording and the shift-work/free-day-alarm limitations. Log a small test entry, verify the day total, then delete it.
3. Play every sound quietly. Listen through the 30-second loop boundary. Lock the phone, test the fade-out timer and interrupt it with a phone call/headphone change.
4. Import a supported audio file, relaunch, replay, loop and delete it. Try a corrupt file and confirm a useful error. Download iCloud files in Files first if the provider has not made them available offline.
5. Confirm that recording cannot start over a playing sleep sound, and that sleep sounds cannot start during monitoring. Recheck microphone waveform and event replay from 1.1.

See DEVICE_TESTING.md and TEST_RESULTS.md for the full verification record.

## Extra ideas awaiting your choice — not implemented

- **Night rewind:** a single morning timeline combining your confirmed sleep, logged wake-ups and replayable sound events, with uncertainty shown.
- **Personal sleep experiments:** choose one change, such as a sound versus silence, compare enough nights and your own morning ratings, and show sample sizes without claiming causation.
- **Saved sound blends:** independently balance two or three Lotus sounds or your own audio, then save the mix and timer as a preset.

Public sound-mixing and reminder patterns inspired some ideas; Lotus uses original code, wording and generated audio rather than copied app assets.
