# Time to Meet

Time to Meet is a native macOS menu-bar companion that turns upcoming
calendar events into timely meeting reminders. It reads EventKit calendars
locally, recognizes common conferencing links, and avoids interrupting an
active microphone or camera session.

## Features

- Menu-bar countdown for upcoming selected meetings
- Full-screen, dismissible reminders near meeting start
- Zoom, Google Meet, Teams, Webex, Whereby, and Around link recognition
- Per-series alert preferences and per-occurrence dismissals
- Active-call suppression based on local microphone and camera state
- Sandboxed calendar access; calendar contents are not transmitted

## Requirements

- macOS 13 or newer
- Xcode 15 or a Swift 5.9-compatible macOS toolchain
- Calendar permission for normal app operation

## Build and test

```bash
swift build
swift test
```

The `MeetingCore` library contains Foundation-only URL parsing and platform
detection. Its XCTest suite covers supported providers, candidate priority,
punctuation handling, generic calendar-URL fallback, missing meeting paths,
and deceptive look-alike hosts.

The package declares macOS as its platform because the application target uses
SwiftUI, EventKit, CoreAudio, and CoreMediaIO. Run the full build and test suite
on macOS; CI uses a macOS runner.

For a signed app bundle, use `./build.sh`. For Mac App Store preparation and
XcodeGen instructions, see [MAS_SUBMISSION.md](MAS_SUBMISSION.md).

## Architecture

- `Sources/MeetingCore/` — pure meeting-link parsing and platform naming
- `Sources/TimeToMeet/` — SwiftUI menu app, calendar polling, reminders, and
  active-call detection
- `Resources/` — sandbox entitlements, app metadata, and icon resources
- `Tests/MeetingCoreTests/` — deterministic XCTest coverage for the core
- `project.yml` — XcodeGen definition for signed distribution builds

## Privacy and security

Calendar data and device-activity checks remain on the Mac. The app does not
upload event titles, notes, attendee data, or join URLs. See
[SECURITY.md](SECURITY.md) for private vulnerability reporting and
[CONTRIBUTING.md](CONTRIBUTING.md) for the change workflow.
