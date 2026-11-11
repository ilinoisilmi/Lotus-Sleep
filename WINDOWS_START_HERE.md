# Windows → build → sideload Lotus Sleep

**Already installed?** Use [the Lotus 1.3 update guide](Docs/LOTUS_1_3.md). The original 1.0 build and installation succeeded. Version 1.3 is a source update that still needs a new cloud build and device checks. The setup instructions below are for a first installation.

Prepared 10 November 2026 for an iPhone 14 Pro Max, the reported iOS 27.2, a Windows PC, a regular Apple Account, and no wearable. You do not need to own a Mac. GitHub's hosted Mac compiles the app; Sideloadly on your PC signs and installs it.

**Current source verification:** see [TEST_RESULTS.md](Docs/TEST_RESULTS.md). The existing GitHub workflow builds the new IPA after you upload the update.

## 1. What to have ready

- Your Windows PC and unlocked iPhone, plus a Lightning USB **data** cable.
- A [GitHub account](https://github.com/signup).
- Your own Apple Account and access to its verification prompts. A paid Apple Developer membership is not required for the Basic sideload route.
- The latest `LumaSleep_Source.zip`. Use **Extract All**, then open its `LumaSleep` folder.

You do not need Xcode, Swift or Python installed on Windows. The build uses a hosted Mac with Xcode and no signing secrets. The app's iOS deployment target is 17.0; a phone running a newer iOS version does not require an identical SDK version just to run this device build. AlarmKit features require iOS 26+ and permission. Compatibility across supported versions still needs device testing.

## 2. Put the source in your private GitHub repository

1. On GitHub, click **+ → New repository**. Name it `luma-sleep`, select **Private**, enable **Add a README**, then create it.
2. Choose **Add file → Upload files**.
3. Open the extracted `LumaSleep` folder in File Explorer. Drag **its contents** into GitHub, including `.github`, `App`, `Config`, `Core`, `Scripts`, and `LumaSleep.xcodeproj`. Upload the files/folders, not the original ZIP or an extra enclosing `LumaSleep` folder. Replace the initial README with the supplied one.
4. Commit the upload to the default branch, normally `main`.
5. Check that `.github/workflows/build-ios.yml` and `LumaSleep.xcodeproj/project.pbxproj` exist at those exact paths from the repository root. If the workflow folder was omitted, use **Add file → Create new file**, enter `.github/workflows/build-ios.yml`, paste the contents of the supplied workflow file, and commit it.

Private repositories have an included Actions allowance; usage beyond your allowance can be billable if billing is enabled. Check [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions). This workflow runs only when you click Run, times out after 35 minutes, and deletes IPA artifacts after three days. No Apple Account secrets belong in GitHub.

## 3. Build the iPhone IPA

1. Open the repository's **Actions** tab. If asked, enable Actions for this repository.
2. Select **Build Luma for iPhone** on the left.
3. Click **Run workflow**, leave the default branch selected, then click the green **Run workflow** button.
4. Open the new run. Wait for a green success check. The hosted Mac runs core tests and a real Release iPhone build of **LumaBasic**.
5. In the completed run's summary, scroll to **Artifacts** and download **LumaSleep-unsigned-ipa**. Download within three days.
6. Extract that downloaded ZIP once. Inside is **LumaSleep-unsigned.ipa**. Keep the `.ipa` intact; do not extract it or rename the source ZIP to `.ipa`.

The result is intentionally unsigned. Sideloadly supplies the device-specific signature next. No signing certificate, paid Apple subscription or Apple password is needed for the cloud build.

If the run is red, open its failed step and copy the **first actual error**, or download **LumaSleep-build-logs**. Bring the error/log here; do not keep rerunning an unchanged compile failure. A GitHub billing/quota error must be resolved in GitHub before a build can start. If the workflow is missing, recheck step 2's exact folder paths and default branch.

## 4. Prepare Windows while the build runs

1. Get the Windows 64-bit installer from [Sideloadly's official website](https://sideloadly.io/) for a typical 64-bit Windows PC. Use the appropriate download if your Windows edition differs.
2. Follow that site's **Before you install** instructions for the required **web versions of iTunes and iCloud**. Its Windows instructions distinguish these from the Microsoft Store versions. Use its official component links.
3. Install and open Sideloadly. Connect the iPhone by USB, unlock it, and tap **Trust This Computer** if asked. Keep it connected for the first install.
4. Confirm your iPhone appears in Sideloadly's device selector. If not, check the cable, trust prompt and Apple driver installation before continuing.

## 5. Sign and install

1. In Sideloadly, select your iPhone and drag in **LumaSleep-unsigned.ipa**.
2. Enter your Apple Account email, keep the default Apple-ID signing method, and click **Start**.
3. Enter the account password and complete any verification only in the local Sideloadly/Apple flow. Do not send credentials in chat or add them to GitHub. Sideloadly is a third-party signing tool; use its official installer.
4. Follow any device instructions. On iPhone, enable **Settings → Privacy & Security → Developer Mode** if requested, restart, and confirm. This setting may appear only after an initial installation attempt; retry installation afterward if necessary.
5. If opening the app shows **Untrusted Developer**, go to **Settings → General → VPN & Device Management**, select your developer profile, and trust it. Follow any restart/verification prompt shown by your iOS version.
6. Open **Luma Sleep** and finish onboarding.

Use **LumaBasic** first. It includes the diary, bedtime timer, history, imports, motion review, optional sound monitoring and reminders. The HealthKit import and home-screen widget belong to the separate Health scheme and are not included in this workflow; their entitlements have not been validated with Sideloadly. Do not enable arbitrary advanced signing options to work around an unexplained error.

## 6. Before your first night

Start a short bedtime session, end it, review/save it, close and reopen Luma, and confirm the entry remains. Give microphone, motion, notification or alarm permission only when enabling the relevant feature. Test any alarm or sound-monitoring feature while awake before overnight use; keep your usual Clock alarm until those checks pass. The complete checklist is in [DEVICE_TESTING.md](Docs/DEVICE_TESTING.md).

## 7. Keep it working

With a free Apple Account, sideloaded apps normally need refreshing within **seven days**; there is generally a three-app limit. Re-sign/install over Luma using the **same Apple Account and bundle identifier**. Do not uninstall it to refresh it. Keep the downloaded IPA and periodically export a JSON backup from Luma.

Sideloadly also offers automatic refresh when its daemon and required computer/device connection are available. If the PC is off or unavailable, do not assume renewal happened. See the [official FAQ](https://sideloadly.io/faq).

For a source update: replace the changed repository files, run the workflow again, download the new IPA, back up your data, and install over the existing app with the same signing identity. No cloud rebuild is needed just to refresh an unchanged IPA.

## Quick troubleshooting

| What you see | What to do |
| --- | --- |
| No Run workflow button | Confirm `.github/workflows/build-ios.yml` is on the default branch and Actions is enabled |
| Red cloud build | Open the failed step; send the first compile error or build-logs artifact |
| No IPA artifact | The build/package step must succeed; source files are not an IPA |
| Phone not detected | Unlock, trust, check a data-capable cable and the official Windows Apple components |
| Developer Mode / trust error | Follow step 5 on the iPhone; retry after the required restart |
| Too many apps | Free signing has limits; preserve data before removing any existing sideloaded app |
| App stops launching after a week | Refresh the existing app using the same Apple Account and bundle identifier |

For optional direct Mac installation and the Health scheme, see [BUILD_AND_INSTALL.md](Docs/BUILD_AND_INSTALL.md).
