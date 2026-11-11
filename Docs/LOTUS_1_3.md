# Lotus Sleep 1.3 — cumulative source update

Prepared 11 November 2026. Version **1.3 / build 4**. This update includes every 1.1 and 1.2 change and can be applied directly to the original Luma Sleep repository. The design is for everyday adults: a calm sleep utility with optional, understated companions.

## New features

| Feature | Where to find it | What it does |
| --- | --- | --- |
| Morning inbox | Today, Settings, or Nighttime help | Save practical notes such as “take the charger” or “bring the documents”; choose a date/time; optionally receive a local notification; edit, complete, reopen or delete. No quotes or motivational messages. |
| Night Rewind | A History day, or Today’s latest recorded night | Chronological sleep evidence, logged wake-ups, room sounds and unknown gaps. Replay a retained sound directly in the timeline. Filter event types and browse 30 items per page. |
| Sleep experiments | Today or Settings | Compare two comfortable routines over 14 mornings. The plan assigns seven A and seven B nights; log the option actually used, a rested rating and context. Skip nights when needed. Averages appear after three rated mornings per option. |
| Saved sound blends | Sleep sounds → Saved sound blends | Combine up to three built-in or imported tracks; adjust each layer and master volume; save a name, looping preference and timer. |
| Good-rest streak & companions | Today or Settings | Choose Mochi the rabbit, Ember the fox, Pebble the otter or Clover the cat. Five original vector looks develop at 0, 3, 7, 14 and 30-day streak milestones. Hide the companion card on Today if preferred. |

Earlier features remain: Lotus branding, seven-day history, quality/duration labels, wake-up logging and settling guidance, quick sleep/nap entry, live microphone waveform and optional replay, six relaxing sounds, MP3/M4A/WAV import, notification controls, the five-part sleep profile and age-aware caffeine guidance.

## Practical details

**Morning inbox:** notes remain readable and editable before their due time. A reminder is optional and requests iOS permission only when saved with notification enabled. Notes save before the permission request; denial preserves the note and shows an error explaining that no reminder was scheduled. Notification bodies are generic unless you explicitly choose to show the note text. Tapping a notification opens the inbox. Completing, deleting or editing a note cancels its old reminder. Reopening a completed note does not silently reschedule it: edit and save a new future reminder. Up to 1,000 notes and 20 pending morning reminders are supported. No automatic motivational messages are generated.

**Night Rewind:** sounds never establish wakefulness, sleep stages or who made the sound. Your manual wake-up log remains distinct from measured/imported evidence until included in a diary review. Gaps remain unknown. Replay requires audio retention to have been enabled before recording and the local recording to still exist; JSON backups do not contain audio. End monitoring before replaying. Replay stops on leaving the timeline or backgrounding, and on calls/route changes.

**Experiments:** one active comparison at a time, up to 100 stored comparisons. Morning dates retain the original reporting timezone and sleep-day boundary. Future mornings cannot be logged. Reports can be corrected; finished comparisons can be archived or reopened. Ratings group by the option actually tried, not just the plan. Missing/skipped ratings are excluded. Sleep-day averages include confirmed naps and exclude unknown days. Results describe a small personal sample; they do not establish cause or prescribe medication/sleep restriction.

**Blends:** up to 100 saved mixes. Layer gains are normalized under the master volume to avoid an automatic loudness jump. Each loop follows its file’s own duration; with looping off, tracks finish individually. Timers offer 15, 30, 45, 60, 90 or 120 minutes, or until stopped, with a final ten-second fade. Missing imported tracks cause a clear error rather than a silently incomplete mix. Edit the mix to choose a replacement. Microphone monitoring and sleep-sound playback remain mutually exclusive.

**Streaks:** a good-rest day reaches at least the chosen duration target minus 30 minutes and, if rated, has a main-sleep quality rating of at least 4/5. This matches History; naps contribute to the day’s duration. An unfinished current day preserves the prior run. A completed day with no sleep data means the run is unverified until logged, not a bad night. Mixed/needs-attention days break the current run. Best streak is calculated over the latest 366 sleep days. One sleep day awards progress to one selected pet; switching pets or relaunching cannot reuse that day. Earned looks remain available even after later poor nights or diary corrections. Companions do not need feeding and never become sad or penalize the user. These milestones are diary feedback, not a clinical sleep score.

## Install the update from Windows

1. In the installed app, export a complete JSON backup. Keep original imported sound files separately.
2. Extract **Lotus_Sleep_1.3_Update.zip**. It contains changed/new source files, not an IPA.
3. Open [your repository](https://github.com/ilinoisilmi/Luma-Sleep) → **Add file → Upload files**. Drag the extracted contents into the repository root. `App`, `Core`, `Config`, `Design`, `Scripts`, `Docs`, `Tests` and `LumaSleep.xcodeproj` belong directly at that root, with the supplied root documents alongside them. Commit to `main`. Do not upload the ZIP or an extra enclosing folder.
4. The existing hidden `.github` workflow stays unchanged. Open [the build workflow](https://github.com/ilinoisilmi/Luma-Sleep/actions/workflows/build-ios.yml) → **Run workflow → main → Run workflow**. The workflow is still named **Build Luma for iPhone**.
5. After a green run, download **LumaSleep-unsigned-ipa**, extract it and use the contained **LumaSleep-unsigned.ipa** in Sideloadly.
6. Use the **same Apple Account and bundle-ID settings** as before. Install over the existing app without deleting it. The visible name is Lotus Sleep. Check that your old history is present before trying the new features.

The bundle ID, project/scheme names, data directory and existing workflow intentionally retain their internal Luma names. You do not need your own Mac: the existing GitHub workflow builds on its hosted Mac. This package has not been pushed to GitHub or installed on your phone.

## Verification and compatibility

The source targets **iOS 17+**. Local Linux checks pass: **98 core tests**, native Swift syntax parsing in Basic/Health configurations, structural project/resource checks and packaging tests. The four companions and twenty vector stages were visually inspected. Native screens, Apple-framework type checking, Xcode compilation, signing, real notifications, background audio and device behavior remain unverified here. The original 1.0 cloud build was successful; that does not validate 1.3. Follow [the device checklist](DEVICE_TESTING.md) after the new cloud build. See [the actual verification record](TEST_RESULTS.md).

## Data continuity

Schema **5** explicitly migrates schemas 1–4 while preserving existing sleep history and settings. New collections start empty. The on-device filename remains `sleep-v2.json`. Older builds reject schema 5; keep the pre-update backup for rollback.

JSON exports now include morning notes, experiment ratings/notes, sound-blend settings and companion awards. Exports are unencrypted. Actual microphone recordings and imported audio files remain excluded. A deliberate restore disables all reminder flags, preserves the notes, removes old audio copies, and clears custom-sound metadata. Saved blends remain, but custom layers need reimporting/replacing. An ordinary in-place app update does not perform this destructive restore.
