# Mac App Store submission

This file walks through everything I cannot do for you because it requires
your Apple ID, your Developer Program account, and decisions only you can
make (app description, screenshots, pricing, privacy policy URL).

The Swift Package + `build.sh` flow stays usable for local development. MAS
distribution requires a separate Xcode project with proper signing, which is
what `project.yml` is for.

---

## 1. One-time account setup

- Enroll in the **Apple Developer Program** ($99/year) at
  https://developer.apple.com/programs — you need this before anything else
  works.
- In Xcode → Settings → Accounts, add the Apple ID tied to that membership
  and confirm the team is listed.
- In **App Store Connect** (https://appstoreconnect.apple.com) → My Apps →
  "+" → New App, register the bundle ID `com.alluxi.timetomeet` (or change
  it first if it's taken). Pick a unique app name, primary category (likely
  *Productivity*), and set up a privacy policy URL.

## 2. Generate the Xcode project

```bash
brew install xcodegen   # one-time
xcodegen generate       # reads project.yml, writes TimeToMeet.xcodeproj
```

Open `TimeToMeet.xcodeproj` in Xcode.

## 3. Configure signing in Xcode

In the TimeToMeet target → Signing & Capabilities:

- **Team**: select your developer team (this updates `DEVELOPMENT_TEAM`).
- **Signing certificate**: leave Automatic. For App Store distribution, Xcode
  will create/download a *Mac App Distribution* cert and a *Mac
  Installer Distribution* cert under your team.
- **App Sandbox**: confirm it's enabled and that **Calendar** is checked
  under "App Data". The entitlements file at `Resources/TimeToMeet.entitlements`
  already declares both, but Xcode mirrors this in the UI.
- **Hardened Runtime**: Xcode enables this automatically for archives.

## 4. Add an asset catalog (recommended for review)

App Review prefers an Asset Catalog `AppIcon` over a loose `.icns`. Either:

- (Easy) Keep the current `Resources/AppIcon.icns` — Xcode picks it up via
  `CFBundleIconFile` in `Info.plist`. This passes review but App Store
  Connect won't auto-show your marketing icon.
- (Recommended) In Xcode, add an Asset Catalog `Assets.xcassets`, drag the
  generated PNGs into `AppIcon`, set
  `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon` and remove
  `CFBundleIconFile` from `Info.plist`. Run `tools/make_icon.swift` once and
  use `sips` to produce the standard icon sizes (16, 32, 64, 128, 256, 512,
  1024).

## 5. Prep App Store Connect listing

Before you can upload a build, the App Store Connect record needs:

- **App name** and **subtitle**.
- **Description** and **keywords**.
- **Support URL**.
- **Privacy policy URL** (required because we read calendar data — even
  though we don't transmit it anywhere).
- **Screenshots** for the Mac (at least one 1280×800 or 1440×900).
- **App icon** (1024×1024, no transparency, no rounded corners).

In **App Privacy** → declare what data you collect. For this app the honest
answer is **none** — we only read EventKit data locally and never send it
off-device.

## 6. Archive and upload

From the project root, with the Xcode project generated:

```bash
xcodebuild -scheme TimeToMeet \
           -configuration Release \
           -archivePath build/TimeToMeet.xcarchive \
           archive

xcodebuild -exportArchive \
           -archivePath build/TimeToMeet.xcarchive \
           -exportPath build/TimeToMeet-export \
           -exportOptionsPlist ExportOptions.plist
```

You'll need a small `ExportOptions.plist` (also gitignored) — the simplest
version:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key><string>upload</string>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

Or upload the resulting `.pkg` from `build/TimeToMeet-export/` via
**Transporter** (Mac App Store) — drag the package in, click Deliver.

## 7. Submit for review

In App Store Connect → your app → version → "Add for Review". Apple's
review usually takes 1–3 days for a small app. They will exercise the
fullscreen overlay; if review pushes back on it, the rationale to lead with
is "user-initiated meeting reminder, dismissable, only triggers from the
user's own calendar events with explicit calendar consent."

---

## What might bite you under sandbox

- The screen-saver-level window across all spaces: works under sandbox; no
  entitlement needed. Tested locally.
- Calendar access: works with the entitlement above; user still sees a TCC
  prompt the first time.
- Opening meeting links: `NSWorkspace.open(url)` works under sandbox without
  the network-client entitlement because the URL is handed to the default
  browser via launch services.
- Login items: not wired up yet. If you add "open at login", do it via
  `SMAppService.mainApp.register()` rather than the deprecated
  `LSSharedFileList` — App Review rejects the latter.
