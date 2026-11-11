# Feature status and capability matrix

**Implemented** below means source is present and connected to a real native control. It does not mean an iOS build or hardware behavior was verified. Core calculations have executable regression coverage; all Apple-framework behavior still needs Mac/device acceptance.

See [Lotus 1.3 changes and installation](LOTUS_1_3.md) for the current update.

## Tracking methods

| Method | Hardware / permission | Background and lifecycle | Battery / storage | Implementation and verification |
| --- | --- | --- | --- | --- |
| Apple Health | iPhone Health store; sleep-read consent; HealthKit-signed scheme | Foreground anchored queries; processes additions and deletions; wearable delivery can be delayed; no continuous/background query promise | Low, incremental pages; full local JSON commits | Real HealthKit adapter; no live Health store tested. Read refusal cannot be distinguished from absent data. Third-party route is wearable app → Apple Health → Lotus |
| Quick duration / wake-ups | No additional permission | Persisted live wake-up; retrospective log; explicit morning review | Low | Quick duration editor, reason-based guidance, history of disturbances; migration and interval logic covered by core tests |
| Manual diary | Any supported iPhone; no permission | Offline; atomic persistent storage; revision history and undo | Low | Full editor, dates, awakenings, naps, quality, notes and tags; core model tested, native controls unrun |
| Bedtime session | Any supported iPhone; no permission | Persisted start timestamp survives termination; foreground display derives elapsed time; morning review needed | Very low while idle | Start/end, nap timer, stale-session discard and review; serialization recovery tested |
| Motion-assisted review | Supported motion coprocessor; Motion & Fitness consent | Queries at most seven days of stored activity; no overnight stream; last event is not extrapolated | Low, a foreground query | Real Core Motion adapter; suggestions are unconfirmed in-bed evidence until reviewed; no mattress mode; untested on hardware |
| Sound events | Microphone consent; explicit start; audio background mode | Screen lock supported by the chosen session type; interruption/route change stops; termination cannot restart recording | Continuous microphone costs battery; event-only by default; opt-in full AAC recording, 12h / 400MB limits | Real AVAudioEngine + room-calibrated adaptive RMS event detection, live waveform and in-app event replay; no snore classifier. Device lifecycle, energy and storage behavior unverified |
| CSV / JSON | Files access through document picker | Foreground preview and atomic import | Up to 10 MB / 20,000 rows per import | Parser, offset checks, timezone validation, duplicates, conflict rejection, examples and exports; core regression tests pass |

## Product features

| Area | Status |
| --- | --- |
| Five destinations, midnight/light themes, app icon | Implemented. Icon visually inspected; native screens not rendered |
| History and corrections | Seven-day cards and explained duration/quality labels, previous/next week navigation; source detail; corrections and hidden-entry restoration; immutable original diary revisions |
| Overlaps and source priority | Interval sweep counts sleep once; corrections always first, user priority next; same-source awake outranks sleep; unknown gaps excluded |
| Stage timeline | Only actual or explicitly imported stage categories; diary stays unspecified; unknown future Health categories skipped |
| Efficiency | Shown only with bed evidence containing every counted sleep segment; no assumed bedtime |
| Shortfall | Sum of nonnegative daily deficits over 14 days with data; missing days excluded; naps counted once; extra hours never mechanically repay another day |
| Energy curve | Explicitly preliminary planning heuristic after three recorded days; no scientific validation or physiological measurement claim |
| Habit comparisons | At least three tagged and three untagged main-sleep diary entries; sample sizes; association only; split-sleep confounding disclosed |
| Planning | Weekday/weekend wake times, wind-down and settling; fixed-date alternative for irregular schedules |
| Reminders | Wind-down, bedtime, optional caffeine cutoff and one habit notification; permission status, 5-second test, next delivery preview and schedule-change notice; Apply after schedule/profile changes; Focus/silent limits explained |
| Morning inbox | Practical editable notes, due/upcoming/completed lists, optional generic or text-preview notifications, tap routing; denied permission preserves notes; complete/delete/edit cancels old reminders; device delivery pending |
| Night Rewind | Filterable chronological evidence, manual wakes, unknown gaps and sound events with direct retained-audio replay; sources remain distinct |
| Sleep experiments | Balanced 14-morning plan; actual-condition logging, skip/edit/archive, sample sizes, averages gated at three ratings per option; unknown sleep excluded; association only |
| Rest streak & companions | Four selectable original vector animals, five permanent appearance stages at 0/3/7/14/30-day streaks, one pet award per sleep day, optional Today visibility; core-tested, native layout unverified |
| Sleep sounds | Six original generated textures; offline MP3/M4A/WAV imports; single sounds or saved mixes of up to three layers, looping, volume, fade-out timer; interruptions stop playback; device verification pending |
| Personal profile | Five-part original questionnaire; self-reported wind-down style and schedule midpoint; age/context-aware caffeine guidance, optional chosen cap and logs; core-tested, not a validated personality/chronotype test |
| Wake alarm | AlarmKit on iOS 26+; fixed alarm, no countdown UI or smart wake. Older OS directs user to Clock. No alarm delivery tested |
| Shortcuts | Start bedtime, end with morning review, log estimated nap; deliberately opens app; not promised to run silently when locked |
| Widget | LumaHealth only; matching App Group; opt-in target and wind-down sharing; no health history or notes; device refresh cadence unverified |
| Privacy / backups | Offline local container; iOS file protection; excluded automatic backup; explicit JSON/CSV export, restore preview, pre-restore rollback file, deletion controls |
| Demo | Separate in-memory snapshot, conspicuous banner; Health/motion/microphone/import/scheduling actions blocked; explicit built-in sound playback is available |
| Architecture | Feature folders; pure core package; source/storage/clock interfaces; deterministic Xcode generator; worked future-feature example |

## Deliberately unavailable / remaining work

- No watch app, direct wearable-vendor authentication, cloud sync, account system or remote coaching.
- No raw motion mattress mode, unlock-history access, smart light-sleep wake, snoring classifier, apnea detection or fabricated sleep stages.
- Apple Health ZIP/XML export parsing is not implemented. The CSV and JSON formats work independently.
- Retained audio is a full bounded session, not automatically selected clips. Event summaries remain after raw retention expires. Cleanup occurs when the app next runs, not on a guaranteed background schedule.
- Dedicated caffeine time/amount logs are included. No personalized safe-dose calculation, measured metabolism, caffeine clearance curve or exposure-adjusted statistical analysis is claimed.
- One fixed AlarmKit alarm is managed at a time; recurring wake alarms and snooze can be future features. Ordinary reminders are not an alarm fallback.
- Health samples without timezone metadata use the timezone at import; the original timezone cannot be reconstructed. Health records do not reliably label naps: classify a window through a local correction if needed.
- Source conflict resolution is deterministic, not a guarantee that the chosen source is more accurate. Very long overlapping imported records may make a day's correction affect portions on adjacent days; the editor explicitly warns about the whole selected records.
- Persistence uses atomic JSON snapshots, suitable for personal-scale history. Large histories may need a database and paged UI; safety limits prevent unbounded imports.
- The 1.0 Basic cloud build passed and the owner opened it. Version 1.3 native compilation, simulator rendering, VoiceOver, Dynamic Type, device battery and permission/interruption behavior remain unverified. See `DEVICE_TESTING.md`.
