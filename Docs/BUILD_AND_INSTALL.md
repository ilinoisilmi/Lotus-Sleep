# Build, sign, install and update

Updated 10 November 2026 for an iPhone 14 Pro Max running the reported iOS 27.2. The owner has **Windows only**, a regular Apple Account, and no wearable.

## Three different steps

**Build:** Xcode compiles Swift and packages resources into an iOS `.app`. A simulator build is not an iPhone executable. **Sign:** Xcode or a signing tool applies a certificate, App ID, entitlements and a provisioning profile for the intended device. **Install:** an installation tool copies the signed application to the phone. An IPA is a packaging format, not proof of a valid signature or compatible entitlements.

No iOS binary was produced here: the execution environment is Linux and has no Apple SDK, Xcode or signing identity. Only the independent core package could be compiled and tested. Never rename this source ZIP to `.ipa`.

## Recommended for this setup: Windows + hosted Mac build

Follow **[WINDOWS_START_HERE.md](../WINDOWS_START_HERE.md)**. The supplied `.github/workflows/build-ios.yml` runs manually on GitHub's `macos-26` hosted runner, uses its Xcode/iPhoneOS SDK (26 or newer), runs core tests, builds the **LumaBasic** Release device target without signing, and packages `LumaSleep-unsigned.ipa`. The iOS 17 deployment target allows older supported systems; compiling with an iOS 26 SDK does not by itself prevent running on a newer iOS release.

Download the successful run's IPA artifact, then use Sideloadly on Windows to sign and install it with your own Apple Account. The cloud build uses no Apple credentials, certificates or provisioning profiles. GitHub's private-repository Actions allowance and possible overage billing apply. The original 1.0 workflow succeeded and the owner installed it. The 1.3 update still needs its own cloud build and device verification; see [the current guide](LOTUS_1_3.md).

Keep the Basic scheme for the first installation. HealthKit/App Group entitlement preservation requires separate verification with the chosen signing tool. Source compatibility, a successful compile and successful on-device behavior are separate checks.

## Optional route if a Mac becomes available: Xcode + Personal Team

1. Install **Xcode 27.2**, or a later stable Xcode release with device support for your installed iOS. Apple's table currently requires **macOS Tahoe 26.6 or later** for Xcode 27.2. Check your Mac's model and macOS compatibility before upgrading. A newer SDK can still build this project's iOS 17 deployment target.
2. Launch Xcode once, accept its license and install the requested iOS platform components. In **Xcode → Settings → Accounts**, sign in to your Apple Account locally. Never share passwords, private keys or provisioning secrets in chat.
3. Unzip the project and open `LumaSleep.xcodeproj`. Select the `LumaBasic` scheme in Xcode's toolbar.
4. Select the blue project icon, then **Targets → LumaBasic → Signing & Capabilities**. Enable automatic signing and select your Personal Team. Set a unique reverse-domain bundle identifier, such as `com.ilmi.lumasleep.<your-unique-suffix>`.
5. For reproducibility, optionally copy `Config/User.xcconfig.example` to `Config/User.xcconfig`, remove the comment prefix on the two settings, and enter your team identifier and unique `LUMA_BUNDLE_ID`. A team identifier is not a signing secret. This also gives the optional widget a matching bundle prefix.
6. Connect the unlocked iPhone with a cable. Accept the phone's computer-trust prompt. Select it under Xcode's run destinations.
7. If requested, enable **Settings → Privacy & Security → Developer Mode** on the phone, restart and confirm. Xcode may first need to pair with the device before that option appears.
8. Press **Run**. Let automatic signing resolve the profile. If the phone asks you to trust the developer, follow the device's **VPN & Device Management** trust flow for your own account.
9. Open Luma and complete onboarding. Test diary save/relaunch and a short bedtime session before the first overnight use. Complete the alarm and microphone checks in `DEVICE_TESTING.md` separately.

If an SDK API fails to compile, retain the full Xcode diagnostic and fix it before device installation. Source syntax validation performed here cannot establish iOS API type correctness.

## Two app schemes

| Scheme | Features | Provisioning |
| --- | --- | --- |
| `LumaBasic` | Diary, timer, history, calculations, imports, sound events, motion review, reminders, Shortcuts, and AlarmKit where available | Empty custom entitlement file; automatic Personal Team signing is the first route to try |
| `LumaHealth` | All Basic features plus HealthKit and the plan widget | HealthKit entitlement plus one App Group, also assigned to `LumaWidget` |

Both schemes deliberately use the same app bundle ID and storage location. Install only one at a time. Do not use an all-targets build: both app targets produce `LumaSleep.app`. Upgrading from Basic to Health with the same valid signing identity is intended to preserve data; export first and test it on-device.

Apple's current capability table lists **HealthKit and App Groups in the free Apple Developer column**. This project therefore does **not** assume a paid membership is required. Actual capability provisioning remains a device/Xcode acceptance check. If your account, signing service or Xcode rejects an entitlement, keep using Basic while you resolve the exact error; do not remove entitlements and pretend the integration works.

For Health: ensure `LUMA_APP_GROUP` resolves to `group.<your app bundle ID>`, select your team for both `LumaHealth` and `LumaWidget`, and let Xcode create/register the group if offered. Enable the matching group in both targets. Health is read-only; there is no Health write usage string or write permission request. It does not request background Health delivery: sync occurs on connection, foreground entry and manual refresh.

## Renew free signing without deleting data

Apple's Personal Team documentation currently gives profiles a seven-day validity, permits three installed apps per device and limits App IDs and devices. Extensions consume identifiers; actual enforcement is determined by Xcode and Apple's provisioning service.

Before expiry, connect the phone and **Run the same scheme again with the same team and bundle ID**. If it has already expired, the app may no longer open until renewed. Do not delete the app as a refresh step. Deleting an iOS app normally removes its local container. Keep an exported JSON backup somewhere safe.

A free-signed personal app is not a dependable unattended alarm service through provisioning expiry. Renew it before relying on overnight use, and keep a separately configured Clock alarm until your device checks pass. This is a limitation of the selected installation route.

A paid Developer Program account offers broader distribution and profile management. Profile expiry still exists: inspect the actual embedded profile instead of treating membership as permanent signing. This project does not require a subscription for core tracking.

## Updates and data preservation

Export a complete JSON backup. Keep team, bundle ID and App Group consistent. Increment `CURRENT_PROJECT_VERSION`, build and install over the existing app. The schema-5 reader explicitly migrates schemas 1–4; future unknown schemas are rejected without overwriting the original file. Do not downgrade after a schema migration unless a compatible backup is available.

Switching Apple teams or bundle IDs can create a new application container. Use export/restore if that is necessary. Installing through a different signing tool may change identifiers, access groups or entitlements; it is not automatically an in-place update.

## Other Windows signing tools

AltStore Classic is an alternative installer, but the supplied Windows guide uses Sideloadly to keep the initial path consistent. These tools install/re-sign an already compiled IPA; they do not compile Swift source. This project's IPA installation and entitlement preservation have not been verified with either tool. AltStore PAL is a distinct distribution route, not a substitute for compiling and personally signing this project.

## Mac verification commands

```bash
xcodebuild -version
xcodebuild -list -project LumaSleep.xcodeproj
swift test --package-path Core -j 1 -Xswiftc -disable-batch-mode
xcodebuild -project LumaSleep.xcodeproj -scheme LumaBasic \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project LumaSleep.xcodeproj -scheme LumaHealth \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
```

For UI tests, choose an available simulator from the last command:

```bash
xcodebuild -project LumaSleep.xcodeproj -scheme LumaBasic \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' test
```

For physical-device installation, use Xcode Run and automatic signing. If you have an appropriate export-capable distribution profile, archive with the chosen scheme and use Organizer's distribution/export workflow. Do not force an arbitrary `ExportOptions.plist` for a Personal Team: the available export methods depend on the profile.

A signed app can be inspected locally with `codesign -d --entitlements :- /path/to/LumaSleep.app` and its `embedded.mobileprovision` decoded with `security cms -D -i /path/to/LumaSleep.app/embedded.mobileprovision`. Verify identifiers, expiration and entitlements; never paste private signing materials into chat.

Official references are collected in `SOURCES.md`.
