# Hermes Native

A native iOS/iPadOS (iOS 26+) SwiftUI client for the [Hermes](./PRD.md) agent —
streaming chat, a full SSH PTY terminal, cron, projects, and more, with **Liquid
Glass** throughout. Distributed over-the-air via **AltStore**.

> Built feature-by-feature against [`PRD.md`](./PRD.md). See the roadmap and
> phase specs in [`docs/superpowers/specs/`](./docs/superpowers/specs/).

## How it works

Hermes Native is a *client* for the Hermes REST + WebSocket API that already runs
on the user's machine (the NAS). No new backend — the app talks to endpoints like
`/api/sessions`, `/api/auth/me`, `/api/cron/jobs`, and the ws-ticket streaming
socket.

```
SwiftUI app (iOS 26)
 ├─ HermesGlass   — Liquid Glass design system (local SwiftPM package)
 ├─ HermesAPI     — async REST/WebSocket client (local SwiftPM package)
 └─ HermesNative  — app target: onboarding, glass shell, feature screens
```

## Build & distribution (no Mac required to develop)

The repo is authored on Linux; the Mac only appears in CI:

1. Push to `main`.
2. GitHub Actions (macOS runner) runs `xcodegen generate`, tests, then
   `xcodebuild archive` with **signing disabled**.
3. The resulting **unsigned `.ipa`** is published as a GitHub Release asset.
4. `ci/gen-source.sh` updates [`source.json`](./source.json) — the AltStore
   source manifest — with the new version.

No Apple certificate secrets live in CI: **AltStore re-signs the app on device**
with your free Apple ID at install time.

## Installing via AltStore (one-time)

1. Install [AltStore](https://altstore.io) + AltServer; sign in with a free Apple ID.
2. In AltStore → **Sources** → **＋**, add:
   `https://raw.githubusercontent.com/SenulMapa/hermes-native/main/source.json`
3. Install **Hermes** from that source.
4. Every CI build afterwards shows up as an in-app update.

> Free Apple ID caveats: apps expire after 7 days (AltServer re-signs on the same
> network) and you can have at most 3 sideloaded apps.

## First launch

Enter your Hermes server URL (e.g. `http://senuls-nas:8765`, reachable over
Tailscale) and, optionally, a session token from the Hermes web dashboard. The
app verifies reachability via the public `/api/auth/providers` endpoint and your
token via `/api/auth/me`.

## Status — all PRD phases implemented

| Phase | Feature | Notes |
|---|---|---|
| 0 | Foundation + OTA (Liquid Glass shell, CI, AltStore source) | ✅ |
| 1 | Chat — sessions, live JSON-RPC streaming, markdown/code | ✅ `/api/ws` gateway |
| 2 | SSH PTY terminal | ✅ SwiftTerm + Apple swift-nio-ssh, TOFU host-key pinning; needs on-device tuning |
| 3 | Models / settings / usage / appearance | ✅ |
| 4 | Cron management | ✅ `/api/cron/jobs` |
| 5 | Tool-call cards & sub-agents, approval gates | ✅ |
| 6 | Projects + local file editor | ✅ (remote SFTP browsing is future work) |
| 7 | Voice I/O (on-device) + local notifications | ✅ |
| 8 | Server search + Telegram/messaging bridge + memory viewer | ✅ (skills/browser/vision need server endpoints not yet exposed) |
| 9 | Biometric app-lock + accessibility | ✅ |

### Deferred (require a paid Apple Developer account / extra targets)

The free-Apple-ID + AltStore distribution model can't sign iCloud/CloudKit
entitlements, and Watch/native-macOS need separate targets. So **iCloud sync
(§14), a native macOS app (§18), and Apple Watch (§19)** are intentionally not
enabled in this build. The iOS app runs on Apple-silicon Macs as an iPad app.
Performance targets (§22) are met structurally (lazy lists, on-demand loads,
streaming) but not benchmarked here.

> Verification: every phase is compiled by CI (`xcodebuild archive`, iOS 26) and
> the `HermesAPI` logic is unit-tested on the host. Runtime behaviour that needs
> a device or a live authenticated server (terminal TUIs, live streaming, voice)
> should be validated on-device after install.
