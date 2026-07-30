# Security policy

## Reporting

Please use GitHub's private vulnerability reporting for this repository rather
than opening a public issue. Include affected versions, reproduction steps,
impact, and any proposed mitigation. Reports are acknowledged within five
business days and coordinated disclosure occurs after a fix is available.

## Sensitive areas

- Calendar event titles, notes, locations, and URLs must remain on-device.
- Join links must be accepted only from exact provider domains or their real
  subdomains; look-alike hosts must not be treated as trusted providers.
- Changes to sandbox entitlements or Calendar, microphone, and camera access
  require explicit privacy review.
- Release signing material and Apple Developer credentials must never enter
  the repository.

The supported security branch is the current `main` branch.
