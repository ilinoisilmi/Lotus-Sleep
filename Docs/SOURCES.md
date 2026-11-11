# Official sources and implementation decisions

Official documentation was reviewed on **8 November 2026** during implementation and **10 November 2026** for the Windows build/install route. Installation and compatibility must still be checked against the actual build environment, phone and signing profile.

| Topic | Primary source | Decision supported |
| --- | --- | --- |
| iOS release/device support | [Apple security releases](https://support.apple.com/en-us/100100) | User's iOS 27.2 target and supported iPhone family |
| Xcode/macOS/device matrix | [Xcode system requirements](https://developer.apple.com/xcode/system-requirements) | Recommend Xcode 27.2 for this device; minimum deployment target remains iOS 17 |
| Personal Team and renewal | [Developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account) | Free personal-device installation and seven-day provisioning |
| Capability availability | [Supported capabilities for iOS](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) | Current free-account column includes HealthKit and App Groups; actual profiles still need validation |
| Developer Mode | [Enable Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) | Physical-device development setup |
| Health setup | [Setting up HealthKit](https://developer.apple.com/documentation/healthkit/setting-up-healthkit) | Availability guard, entitlement and usage description |
| Health privacy | [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) | Empty reads cannot establish whether access was refused; read-only initial scope |
| Incremental Health changes | [Reading data from HealthKit](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit) | Anchored queries report additions and deletions |
| Motion history | [Historical motion activity query](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/queryactivitystarting(from:to:to:withhandler:)) | At most seven days; delayed events; no screen/unlock inference |
| Motion permission | [CMMotionActivityManager](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager) | Activity availability and motion purpose string |
| Background audio | [AVAudioSession recording category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record) | Audio background mode for locked-screen recording; interruptions still occur; app uses playAndRecord to avoid suppressing unrelated output |
| System alarms | [Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit) | Explicit alarm authorization; fixed schedule; alert-only presentation |
| Alarm OS availability | [Wake up to the AlarmKit API](https://developer.apple.com/videos/play/wwdc2025/230/) | iOS 26 framework and system alarm behavior distinct from notifications |
| Alarm configuration | [Alarm configuration](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration) | Native alarm construction and optional actions |
| Privacy manifest | [Required-reason API purposes](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons) | Local/shared UserDefaults and user-visible low-storage recording checks |
| Sleep duration guidance | [CDC: About Sleep](https://www.cdc.gov/sleep/about/index.html) | Teen 8–10 hours; age-dependent adult guidance; no personal biological-need claim |
| Optional sideloading route | [AltStore Classic getting started](https://faq.altstore.io/altstore-classic/your-altstore) | Refresh behavior; not a native compilation service |
| Sideloading entitlements | [AltStore developer overview](https://developer.altstore.io/) | Classic has limited entitlements; preservation for this app was not verified |
| Windows installation | [Sideloadly](https://sideloadly.io/) and [Windows prerequisites](https://sideloadly.io/index.html) | Sign/install an existing IPA from Windows using a free Apple Account |
| Sideloadly renewal | [Official FAQ](https://sideloadly.io/faq) | Seven-day free signing, app limits, Developer Mode and preserving identity during renewal |
| Hosted Mac build | [GitHub runner images](https://github.com/actions/runner-images) | The macos-26 hosted runner provides a real Apple toolchain |
| Build cost | [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) | Private-repository allowance and potential overage billing |
| Build downloads | [Download workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts) | Obtain the successful run's packaged IPA |
| CI actions | [Checkout](https://github.com/actions/checkout) and [upload-artifact](https://github.com/actions/upload-artifact) | Current documented v7 action usage |

The sleep-shortfall formula, energy curve, source reconciliation policy and habit summaries are **Luma implementation choices**. They are not presented as validated clinical metrics or as Apple/CDC-endorsed algorithms. The energy curve is deliberately labeled an unvalidated planning heuristic.

## Noxli 1.1 guidance, reviewed 11 November 2026

[NIH/NHLBI insomnia treatment](https://www.nhlbi.nih.gov/health/insomnia/treatment) supports the general cool/dark/quiet setting, relaxation and leaving bed when unable to sleep guidance. This app does not implement sleep-restriction treatment or medication advice. Sound labels are engineering heuristics and are not clinically validated measures of wakefulness or sleep stages.


## Lotus 1.2 additions (checked 11 November 2026)

- FDA caffeine reference and individual variability: https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much
- AAP advice that avoiding caffeine is the best choice for children/teens: https://www.healthychildren.org/English/healthy-living/nutrition/Pages/the-effects-of-caffeine-on-kids-a-parents-guide.aspx
- NHLBI healthy sleep habits and caffeine timing: https://www.nhlbi.nih.gov/health/sleep-deprivation/healthy-sleep-habits
- NIMH discussion of self-reported chronotype questionnaires and alarm/shift-work limitations: https://www.nimh.nih.gov/about/advisory-boards-and-groups/namhc/reports/behavioral-assessment-methods-for-rdoc-constructs
- Apple local notification scheduling: https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app
- Apple AVAudioPlayer: https://developer.apple.com/documentation/avfaudio/avaudioplayer

The five reflection questions and rhythm labels are original product heuristics, not the licensed MEQ/MCTQ or clinical tests. The 10-hour caffeine buffer is a conservative app option, not a source-derived universal clearance time. Built-in sounds are generated by Scripts/generate_sleep_sounds.py; no third-party recordings are copied.

Public feature inspiration reviewed: BetterSleep's sound-mixing workflow (https://www.bettersleep.com/support/en/articles/5412939-how-do-i-create-a-mix) and RISE's notification settings (https://help.risescience.com/hc/en-us/articles/40620510022167-How-do-I-customize-my-RISE-notifications). Additional mixing/experiment/recap features await owner approval; no proprietary media, UI, questionnaires or algorithms were copied.

## Lotus 1.3 implementation references

- Apple AVAudioPlayer scheduled playback: https://developer.apple.com/documentation/avfaudio/avaudioplayer/play(attime:)
- Apple audio-device time shared by players: https://developer.apple.com/documentation/avfaudio/avaudioplayer/devicecurrenttime

The streak rules, balanced personal comparison, morning inbox and companion artwork are original product choices. They are not validated clinical instruments. Synchronized player scheduling does not establish that device playback, timers or interruptions passed hardware tests.
