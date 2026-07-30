# Contributing

## Development workflow

1. Create a focused branch from `main`.
2. Use a macOS 13+ machine with a Swift 5.9-compatible toolchain.
3. Keep platform-independent URL logic in `Sources/MeetingCore`.
4. Add or update XCTest cases for every parsing or provider change.
5. Run `swift build` and `swift test` before opening a pull request.

Pull requests should describe user-visible behavior, privacy or entitlement
changes, and the verification performed. Keep EventKit and device-permission
work in the app target so `MeetingCore` remains deterministic and easy to test.

Never commit signing identities, provisioning profiles, exported calendar
data, screenshots containing personal events, or Apple account credentials.
