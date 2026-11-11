# Mac and physical-device acceptance checklist

These are **remaining checks**, not completed results. Start with a backup and synthetic diary data. Fill in the device, iOS build, Xcode version, signing scheme, date and outcome for each run. Recommended matrix: iPhone 14 Pro Max / iOS 27.2; iOS 26 for AlarmKit; iOS 17 or 18 for the fallback path; a small supported iPhone such as SE (3rd generation) or its simulator.

## Build and first launch

- [ ] Build LumaBasic and LumaHealth in Xcode without signing for Simulator; fix every compiler error.
- [ ] Run the core package tests and native UI smoke tests.
- [ ] Provision Basic with the user's Personal Team and install on the iPhone.
- [ ] Provision Health + Widget with the exact same App Group; verify entitlements in the signed products.
- [ ] Fresh launch shows onboarding, correct age guidance and honest empty states.
- [ ] Open all five tabs with no history; no fake metrics or missing-control crashes.
- [ ] Basic Health/widget controls explain availability. iOS 17/18 wake-alarm control directs the user to Clock.

## Tracking and data

- [ ] Save, edit and undo a diary entry spanning midnight; relaunch and confirm it remains.
- [ ] Enter overlapping awakenings, a nap, split sleep and a daylight-saving interval; check totals against known elapsed times.
- [ ] Start bedtime, background, lock, force terminate and relaunch. The saved start time survives and elapsed time derives from it.
- [ ] End a bedside session: the bedside cover dismisses and the morning review opens once.
- [ ] Cancel the morning review: the unconfirmed interval remains time in bed, with no invented sleep.
- [ ] A stale timer longer than 48 hours offers discard instead of silently recording excessive sleep.
- [ ] Import example CSV/JSON, repeat it and verify duplicate reporting; rejected example produces one valid and one rejected row.
- [ ] Export a JSON backup, modify data, restore and check original records/revisions. Export and inspect the pre-restore rollback copy.
- [ ] Feed a malformed/future-schema backup; original data remains intact. A corrupt local file opens Recovery, not an empty database.
- [ ] Enter/exit demo; real records remain unchanged and no sensor, Health query or scheduled notification/alarm action occurs.

## Health and motion

- [ ] Grant Health reading with no data; copy stays neutral about permission versus missing records.
- [ ] Grant reading with real samples; stage/source/time metadata match Health. No write permission is requested.
- [ ] Import from two sources with overlaps, reorder priority and verify both originals remain visible.
- [ ] Delete a test source record in Health, foreground Luma and check its tombstone and changed total; repeat refresh without duplicates.
- [ ] Revoke or restrict reading; errors/empty results do not falsely report read denial. Cached history remains until the user deletes it.
- [ ] Test a third-party wearable only through the records its own app actually writes; document absent stages.
- [ ] Request and deny Motion & Fitness; appropriate state appears. Grant and query history, then confirm a suggestion manually.
- [ ] Leave the phone stationary while awake: Luma must not automatically count that interval as sleep.

## Audio

- [ ] Deny microphone, then grant it in Settings; starting works and errors are understandable.
- [ ] In default mode, inspect the app container and verify no raw recording file is created.
- [ ] Record a short controlled session, then lock the screen and background for at least 15 minutes; timestamps/events persist.
- [ ] Test a phone call, audio-route change and media-service interruption. Status says interrupted and a new start is required.
- [ ] Force terminate during monitoring; relaunch shows an interrupted session with unknown exact end, never an active microphone indicator.
- [ ] Opt into retention; verify playback/export, Data Protection while locked, low-storage refusal, duration/file limits and storage-error stop.
- [ ] Change retention to one day; with an expired fixture, relaunch and verify raw-file cleanup while event summaries remain.
- [ ] Delete an individual recording/events, restore a backup and delete all app data; retained files should not remain orphaned.
- [ ] Measure overnight battery impact with event-only and retained modes; do not publish a battery claim without measurements.

## Alarms, reminders, Shortcuts and widget

- [ ] Schedule an AlarmKit alarm a few minutes ahead on iOS 26+; test unlocked, locked, backgrounded and terminated.
- [ ] Repeat with Focus and silent mode, then revoke alarm permission and verify clear failure feedback.
- [ ] Replace the fixed alarm and confirm only the intended alarm remains; cancel it, relaunch and verify state from AlarmManager.
- [ ] Test a reboot, first unlock and free-provisioning expiration/renewal before treating Luma as a reliable wake mechanism.
- [ ] Enable reminders, deny/revoke notification permission, and test Focus restrictions. UI must never promise an ordinary notification will wake you.
- [ ] Change weekday/weekend times, explicitly Apply, and inspect all seven weekdays including reminders on the preceding day.
- [ ] Test timezone/DST changes: repeating reminder timezone is explicit, fixed alarms remain absolute instants; reapply schedules as needed.
- [ ] Run each Shortcut; the app opens, duplicate bedtime start fails cleanly, end opens review and nap bounds are enforced.
- [ ] Add widget, enable/disable sharing and confirm only target/wind-down are shared; allow for system-controlled refresh delays.

## Appearance and accessibility

- [ ] Light and midnight mode on both small and large phones: no clipped controls, unreadable labels or horizontal overflow.
- [ ] Largest accessibility text size; long notes/tags/source names; calendar and editor remain usable.
- [ ] VoiceOver order, button names, chart summaries, errors, permission controls and sleep-stage distinctions.
- [ ] Reduce Motion and increased contrast; no essential state communicated only by color.
- [ ] Interactive chart selection and dates in the chosen reporting timezone; source detail explains local display versus source metadata.
- [ ] Device screen captures of every destination, empty states, bedside mode and a failed permission flow; fix layout issues before release.

## Update and release decision

- [ ] Install an updated build over the same team/bundle ID; diary, active timer and settings survive.
- [ ] Renew Personal Team provisioning without deleting the app; check behavior around expiration.
- [ ] Switch Basic to Health with a backup and matching identity; verify data and widget settings.
- [ ] Mark every enabled hardware-dependent feature as passed or document its specific failure. Disable unresolved experiments before relying on nightly use.

## Noxli 1.1 additional acceptance

Follow the five-minute checks in [the update guide](NOXLI_1_1.md), then test a full night. Verify an in-place 1.0 → 1.1 upgrade keeps diaries and recordings, live wake-up persistence and morning merging, all seven day labels, VoiceOver/large text, waveform with Reduce Motion, event-offset replay and its stop boundary, no replay when retention was off, recording while locked, call/route interruptions, low-storage stop and retention deletion. The first five seconds calibrate; a loud continuous background can mask quieter sounds. Never treat a quiet microphone interval as proven sleep.


## Lotus Sleep 1.2 acceptance

- Install over either 1.0 or 1.1 with the same signing account/bundle settings. Check preserved history, wake logs, settings and sound-event replay.
- Settings → Notifications: verify no permission prompt on opening, denied/granted states, a 5-second test while foregrounded and while locked, next-trigger dates, cancellation, and the schedule-change notice. Change weekday/weekend times, timezone and caffeine sensitivity, then reapply. Test near DST and across midnight. Check Focus and Silent Mode separately.
- Complete and edit the five-part profile; relaunch to confirm saved answers. Verify teen guidance does not offer an adult dose; unknown/medical adult context requests individual advice. Free-day alarms, shift work and seven work days must suppress adjusted chronotype labels.
- Log a known caffeine label, verify a reporting-timezone day boundary, cap warnings, deletion and JSON round trip. Confirm caffeine logs do not alter sleep hours.
- Play each bundled sound at low volume, listen across the 30-second loop boundary, lock the phone, and test a timer through fade-out. Test a phone call and a headphone route change; playback must stop without automatically resuming.
- Import a legal MP3 from local Files and iCloud, then M4A/WAV; restart and replay, loop, delete and reimport. Verify corrupt/unsupported files and files over 100 MB or two hours are rejected cleanly. Keep original files before testing backup restore; imported audio copies are intentionally removed by restore.
- Try starting microphone monitoring while sleep audio plays and vice versa: the app must explain the conflict and prevent simultaneous playback/recording. Replay a microphone event after stopping audio.
- Eight native UI smoke tests are supplied. None were run in this Linux environment. Inspect all new screens on the iPhone 14 Pro Max, a smaller phone, large text, VoiceOver, light/dark mode and Reduce Motion.

## Lotus Sleep 1.3 acceptance

- [ ] In-place 1.0/1.1/1.2 → 1.3 upgrade preserves diary versions, preferences, wake-up logs, retained microphone files and custom audio. Do not use Restore to install an update.
- [ ] Morning inbox: save with notifications off; edit; mark done; reopen; relaunch; delete. Deny notification permission after entering a note and verify it is saved once, with a useful error. Retry without duplicating the note. Test generic/text-preview notifications while locked and tap each to open the inbox, including cold launch and leaving demo mode.
- [ ] Edit/delete/complete a pending morning note and verify the old notification is removed. Reopening must not silently reinstall it. Turn off all reminders, restore a JSON backup, or delete data: pending morning notifications and their flags must clear while a restore preserves note text. Attempt a twenty-first pending morning reminder and verify the note saves without a scheduled notification.
- [ ] Night Rewind: open a recorded day; filter, page and replay the exact event, including one crossing a reporting boundary. Verify no replay when retention was off, after expiry/deletion, or while monitoring. Check end-of-clip, leaving the view, background, a call and route change all stop replay. Gaps remain unknown even when sound events exist there.
- [ ] Mixes: create rain + brown noise; balance/save/relaunch; edit/remove a layer; delete the preset. Try an imported MP3 layer and three simultaneous layers. Check master/per-layer volume, all-zero rejection, synchronized start, looping vs individually ending tracks, locked-screen timer/fade, calls and headphone changes. Missing files must fail the whole mix clearly. Recording and playback remain mutually exclusive.
- [ ] Experiments: create a future first morning in the reporting timezone. Future log buttons are disabled. Save/correct an actual A/B report; skip a day; confirm averages require three ratings per option. Archive/reopen/delete. Only one active experiment is allowed. Test DST and a later reporting-timezone change; original experiment dates must stay stable.
- [ ] Streaks: create three consecutive good days; verify the selected pet changes to stage two exactly once. Relaunch and switch pets without crediting the same day again. Verify a new qualifying day credits the newly selected pet. Test quality 2/5, an unlogged completed day, an unfinished current day, future records and naps. Earned appearance remains after a later bad night. Hide/show the Today card.
- [ ] Render all four pets and all five stages without adjacent sprite tiles leaking into the portrait. Inspect portrait cropping, adaptive grids, long note text and all new screens in light/dark, large Dynamic Type and VoiceOver on a small phone and iPhone 14 Pro Max. These are optional companions, with no hearts, floating decorations or punitive pet mechanics.
- [ ] Export and restore schema 5: notes, comparisons, awards and mixes survive; system reminders stay off; custom sound references explain missing files until replaced. Preserve original media files before intentionally restoring.

Twelve native UI smoke tests are now supplied, including note persistence, companion selection, mix creation and experiment setup. They have been syntax-parsed only in this Linux environment, not executed on a simulator.
