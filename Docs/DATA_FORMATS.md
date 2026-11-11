# Sleep-log imports and backups

## CSV and JSON sleep logs

Files must be UTF-8 and at most 10 MB, with at most 20,000 records. Use **Track → Import a sleep log**. Lotus previews accepted rows, duplicates and rejected rows before the valid records are committed. Rejected records are not silently repaired. The example files in `Examples/` are downloadable with this project; the app can export examples too.

The exact CSV header and order are:

```csv
id,source_id,source_name,start,end,timezone,stage,kind
```

| Field | Required value |
| --- | --- |
| `id` | Nonblank stable identifier, unique within this source; keep it stable on repeated exports |
| `source_id` | Nonblank stable source identifier, for example `diary-export` |
| `source_name` | Nonblank display name; CSV quoting handles commas and newlines |
| `start` / `end` | ISO 8601 timestamps with `Z` or explicit `±HH:MM` offset; fractional seconds accepted on input; end must be later than start |
| `timezone` | Valid IANA timezone, such as `Europe/Skopje`; retained as provenance |
| `stage` | One of `inBed`, `awake`, `asleep`, `core`, `deep`, `rem` |
| `kind` | One of `main`, `nap`, `unspecified` |

Each record spans at most 48 elapsed hours. Multiple records can describe split sleep or stages. `asleep` means unspecified asleep; never synthesize deep/REM stages if the source did not supply them. In-bed rows are separate from asleep rows. Known awake intervals override generic asleep records within a source. Gaps are unknown.

JSON uses the same field names, all as strings, inside this envelope:

```json
{
  "formatVersion": 1,
  "records": [
    {
      "id": "night-001",
      "source_id": "diary-export",
      "source_name": "My diary",
      "start": "2026-11-01T23:00:00+01:00",
      "end": "2026-11-02T07:30:00+01:00",
      "timezone": "Europe/Skopje",
      "stage": "asleep",
      "kind": "main"
    }
  ]
}
```

The explicit offsets determine absolute instants. The IANA zone preserves context; duration is not computed by subtracting wall-clock strings. This handles midnight, travel and daylight-saving transitions. A timezone label without an offset cannot disambiguate a repeated local clock time and is rejected.

Lotus namespaces file source IDs with `file:`. The stored record ID combines that source and the external record ID. Reimporting the same ID and interval is skipped; changing time/stage/kind under an existing ID is rejected for review. An identical source/start/end/stage/kind row under a different ID is also skipped. Imported records keep reported provenance, not a numerical confidence percentage.

The in-app preview numbers data rows starting at 2 for both formats (CSV-header convention). A CSV export contains the current effective record projection, not revision history. A file-import → CSV-export → file-import round trip preserves canonical rows; importing a diary/Health CSV creates a separate file source. Overlap reconciliation still prevents double counting. Use a complete JSON backup to preserve original identity, corrections and settings.

## Complete JSON backups

Use **Settings → Export, restore & delete → Export complete JSON backup**. This format uses `schemaVersion`, not `formatVersion`, and must be opened with **Restore**, not the sleep-log importer.

Schema 5 stores `records`, `deletedSourceIDs`, `diaries` with all `versions` and the `activeVersionID`, `corrections`, `activeSession`, `checkIns`, `audioSessions`, `disturbances`, `caffeineEntries`, `customSounds`, `soundBlends`, `experiments`, `companions`, `morningTasks`, optional `profile`, and `preferences`, with optional Health metadata. The portable export clears the Health anchor. Dates are UTC ISO strings at whole-second precision; sound-event replay offsets and durations preserve subsecond precision independently of wall-clock timestamps. Microphone recordings and imported sound files are excluded. A snapshot may not exceed 50 MB. Corrupt fields, duplicate collection identifiers, unsupported versions and unsafe audio filenames are rejected.

The v1 migration keeps records and compatible preferences, supplies missing collections and new preference defaults, then migrates to schema 5 and validates it. `Examples/migration-v1.json` is a minimal fixture. Later schema versions must add explicit migration steps; do not rely on default Swift property values to accept missing Codable keys.

Restore replaces the current snapshot after a preview and preserves a local pre-restore copy when the current data is readable. It resets the device-specific Health anchor, disables reminder/widget settings, stops playback/monitoring and removes retained recordings and imported custom sound copies. The restored custom-sound list is cleared; reimport originals from Files. It does not resume an imported microphone session. A separately scheduled fixed wake alarm is independent and is not replaced by a backup; review it in Planning. Previously exported files and Apple Health source data are outside Lotus's deletion scope.

Backup files contain sensitive notes and are **not encrypted** by the export format. Choose their destination deliberately. Protect exported audio separately. Device Data Protection applies to Lotus's local container, not arbitrary exported copies.

Schema 2 backups migrate to schema 3 by adding an empty disturbances array. Schema 3 preserves live and completed wake-up logs. Sound events may carry recordingOffset in seconds for frame-aligned replay; older events without it use their timestamp relative to the recording start. Old app versions reject schema 3 rather than silently dropping the new logs. The on-device filename stays sleep-v2.json to preserve the existing storage location.

Quick-duration diaries set includesInBedEvidence to false, so they contribute estimated sleep without inventing time in bed or a 100% efficiency score. Legacy diaries omit the optional flag and retain their original behavior. Wake-up intervals must be at least one second because wall-clock backup dates use whole-second precision.


Schema 4 migration accepts backups from versions 1, 2 and 3. It initializes empty caffeine and custom-sound collections without inventing profile answers. Optional notification options preserve decoding of earlier preference objects. The existing bundle ID, data directory and sleep-v2.json path stay unchanged. Older app versions reject schema 4; retain the pre-update backup for a rollback.

Profiles contain usual main-sleep clock times, work-day count, alarm/shift flags, five original reflection answers, a goal and optional caffeine context/cap. They contain no name or date of birth. Caffeine entries store time, declared milligrams and a short label. Day totals use midnight-to-midnight in the reporting timezone. These are not sleep records and cannot change sleep totals.

Custom sound metadata uses a UUID-matching filename with an MP3, M4A or WAV extension, a title and duration. The library limit is 50 files; individual import limits are 100 MB and 1 second–2 hours. File copies use iOS Data Protection and are excluded from device backups. They are not embedded in JSON. Deletion removes the app's copy, not the original file selected by the user.

## Schema 5 additions

Versions 1–4 migrate explicitly to schema 5 with empty sound blends, experiments, morning notes and companion awards. An optional `showCompanion` preference defaults to visible in the UI. The schema migration itself grants no progress; opening the app evaluates the current verified streak.

- `soundBlends`: UUID, name, 1–3 unique built-in/custom sound references with finite 0–1 gains, timer and loop flag. Up to 100. Missing custom references remain as metadata after a restore so the UI can ask for replacements; they do not authorize a filesystem path.
- `experiments`: UUID, title, two distinct option labels, local first-morning date, IANA zone, boundary hour, up to 14 uniquely indexed actual-condition/rested-rating/notes reports, archive flag. One active and at most 100 total. Missing and skipped reports do not enter rating averages.
- `companions`: selected pet and uniquely keyed sleep-day awards with pet, streak and earned time. Appearance derives from the highest awarded streak for each pet; recalculating history never deletes an award. The current streak is calculated from sleep evidence, not the award ledger.
- `morningTasks`: UUID, text, created/due/completed dates, notification-scheduled flag and explicit text-preview choice. At most 1,000 notes and 20 scheduled morning reminders. Completion requires cancellation; restore clears every scheduled flag and does not recreate system notifications. Exported notes and experiment text are unencrypted, just like diary notes.

Mix metadata survives restore, but custom media does not. Reimport original audio and edit any affected mixes. Installing an in-place update preserves the existing media folder; it is distinct from explicitly restoring a JSON backup.
