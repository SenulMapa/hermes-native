# Hermes Native — Phase 0: Foundation & First OTA Install (Design)

**Date:** 2026-06-06
**Author:** Claude (with Senul Mapa)
**Status:** Draft for review
**Parent product:** [PRD.md](../../../PRD.md) — Hermes Native
**Phase:** 0 of 9 (see Roadmap below)

---

## 1. Context

Hermes Native is a native SwiftUI client for the **Hermes Agent**, whose backend
already runs on the NAS (`senuls-nas`) and exposes a mature REST + WebSocket API
(the existing web dashboard consumes it). Discovered surface includes:

- `GET /api/status`, `GET /api/system/stats` — health / system info
- `GET /api/sessions`, `/api/sessions/{id}`, `/api/sessions/{id}/messages`,
  `/api/sessions/search` — chat history
- `POST /api/auth/ws-ticket` → WebSocket upgrade with `?ticket=` (30s single-use
  TTL) — live streaming transport
- `/api/model/*`, `/api/config/*`, `/api/env`, `/api/providers/*`,
  `/api/cron/jobs/*`, `/api/audio/*`, `/api/messaging/platforms` — models,
  settings, cron, voice, Telegram bridge

**Therefore the app is a client, not a new backend.** Most later phases are
"native view over an existing endpoint." The two genuinely hard, client-side
pieces are the SSH PTY terminal (PRD §4) and Liquid Glass polish.

This document specifies **Phase 0 only** — the foundation that makes every later
phase installable and auto-updating.

## 2. Goal

A real, sideloadable, **auto-updating** Liquid Glass app that connects to the
Hermes backend and proves the full loop end-to-end:

> Push to GitHub → CI builds an unsigned `.ipa` → publishes it + bumps an
> AltStore `source.json` → AltStore offers the update → app installs, connects to
> the NAS over Tailscale, and shows a live "Connected to Hermes" state.

When Phase 0 is done, shipping any later feature is just `git push`.

## 3. Scope

### In scope (Phase 0)
- SwiftUI app project, iOS 26+ deployment target, single iOS app target.
- Liquid Glass design-system module (tokens + core components).
- App shell: glass tab/sidebar navigation with placeholder destinations
  (Inbox · Terminal · Cron · Projects · Settings).
- Onboarding: enter Hermes server base URL, persist to Keychain.
- `HermesAPIClient` skeleton + `GET /api/status` connectivity check with a live
  status indicator.
- GitHub Actions CI: build → unsigned `.ipa` → GitHub Release → regenerate
  `source.json` (AltStore source).
- A minimal XCTest target (so CI has something to run and the harness is proven).

### Out of scope (later phases)
- Real chat/streaming, SSH terminal, cron UI, model config, projects, voice,
  iCloud sync, macOS/Watch targets. (Placeholders only in Phase 0.)
- Apple Developer **paid** signing in CI (free Apple ID re-signs on device).
- Authentication beyond what `/api/status` needs (full ws-ticket auth lands in
  Phase 1 with chat).

## 4. Constraints & key decisions

| Decision | Choice | Rationale |
|---|---|---|
| Platform | iOS 26+ only | Real Liquid Glass (`.glassEffect`, `GlassEffectContainer`) — user choice |
| Distribution | AltStore Source (OTA) | User choice; no App Store review |
| Signing | Free Apple ID | User choice; AltStore re-signs on device → **no Apple secrets in CI** |
| Build host | GitHub Actions macOS runner (Xcode 26) | This dev box is Linux; cannot compile Swift |
| Repo | New **public** GitHub repo `hermes-native` | Free macOS Actions minutes; no secrets stored |
| State | `@Observable` (Observation) + SwiftData | PRD §0 stack; SwiftData for offline cache (Phase 1+) |
| Secrets at rest | iOS Keychain | Server URL / tokens never in the repo or plaintext |
| OTA artifact host | GitHub Releases | CI already on GitHub; `source.json` points at release assets |

**Hard constraint — no local Swift build.** This Linux box has no Swift/iOS
toolchain. All compile/type/test verification happens in CI. No "it builds"
claim is made without a green Actions run.

## 5. Architecture

```
┌─────────────────────────── iOS app (SwiftUI, iOS 26) ───────────────────────────┐
│  App shell (glass TabView / NavigationSplitView)                                  │
│   ├── Inbox*      ├── Terminal*   ├── Cron*   ├── Projects*   └── Settings        │
│   (* placeholder in Phase 0)                                  └── Onboarding flow │
│                                                                                    │
│  Design system: Glass module  ── tokens (color/type/space/density) + components   │
│        GlassCard · GlassBar · GlassButton · StatusPill                            │
│                                                                                    │
│  Services:                                                                         │
│    HermesAPIClient (async/await, URLSession)  ──►  GET /api/status                │
│    KeychainStore (server URL, future tokens)                                      │
│    AppSettings (@Observable)  ── base URL, connection state                       │
└───────────────────────────────────────┬──────────────────────────────────────────┘
                                         │  HTTPS over Tailscale
                                         ▼
                         Hermes web server on senuls-nas (existing)
```

### 5.1 Module / file layout (Swift Package + app target)

```
hermes-native/
├─ HermesNative.xcodeproj
├─ HermesNative/                 # app target
│   ├─ HermesNativeApp.swift     # @main, root scene
│   ├─ AppShell.swift            # glass nav container + placeholders
│   ├─ Onboarding/               # ConnectView, server-URL entry
│   ├─ Settings/                 # SettingsView (server URL, status)
│   └─ Assets.xcassets
├─ Packages/
│   ├─ HermesGlass/              # design system (SwiftPM local package)
│   │   └─ Sources/HermesGlass/  # Tokens.swift, GlassCard.swift, ...
│   └─ HermesAPI/                # networking (SwiftPM local package)
│       └─ Sources/HermesAPI/    # HermesAPIClient.swift, Models.swift, KeychainStore.swift
├─ HermesNativeTests/            # XCTest
├─ ci/
│   ├─ make-ipa.sh               # archive → unsigned .ipa
│   └─ gen-source.sh             # regenerate AltStore source.json
├─ source.json                   # AltStore source manifest (committed, CI-updated)
├─ .github/workflows/build.yml
├─ PRD.md
└─ docs/superpowers/specs/...
```

Splitting `HermesGlass` and `HermesAPI` into local SwiftPM packages keeps each
unit independently testable and small enough to reason about — and lets later
phases (and a future macOS target) reuse them without touching the app target.

### 5.2 Component contracts

**`HermesGlass` (design system)**
- `Theme` — tokens: colors (accent, surfaces), typography ramp, spacing, density,
  corner radii. Driven by `@Environment`.
- `GlassCard`, `GlassBar`, `GlassButton`, `StatusPill` — wrap iOS 26
  `.glassEffect()` / `GlassEffectContainer`; expose plain SwiftUI APIs so callers
  never touch raw glass modifiers. *What it does:* consistent Liquid Glass look.
  *How you use it:* `GlassCard { ... }`. *Depends on:* SwiftUI only.

**`HermesAPI` (networking)**
- `HermesAPIClient(baseURL:)` with `func status() async throws -> ServerStatus`.
- `ServerStatus: Decodable` — mapped from `GET /api/status`.
- `KeychainStore` — `save(serverURL:)`, `serverURL() -> URL?`. *Depends on:*
  Foundation + Security. No UI.
- `HermesError` — typed errors (`.notConfigured`, `.network`, `.decoding`,
  `.http(status:)`).

**App target**
- `AppSettings: @Observable` — holds `baseURL` and `connection: ConnectionState`
  (`.unconfigured | .connecting | .online(ServerStatus) | .offline(HermesError)`).
- `ConnectView` — first-run: text field for server URL, "Connect" → validates via
  `status()` → on success persists to Keychain and routes to `AppShell`.
- `AppShell` — glass `TabView` (iPhone) / `NavigationSplitView` (iPad) with the
  five destinations; only Settings is functional in Phase 0.

## 6. Data flow (Phase 0)

1. Launch → `AppSettings` reads `KeychainStore.serverURL()`.
2. If nil → `ConnectView`. User enters URL → `HermesAPIClient.status()`.
   - Success → persist URL, `connection = .online`, show `AppShell`.
   - Failure → inline error, stay on `ConnectView`.
3. If present → go straight to `AppShell`; a background `status()` refresh sets the
   `StatusPill` (green online / red offline) in Settings.
4. Settings lets the user change the server URL (re-runs the validation flow).

## 7. Error handling

- All network failures surface as typed `HermesError`, rendered as human text in
  the UI — never silently swallowed. (Aligns with the "no silent failure"
  principle: a failed `status()` shows an offline pill + reason, never a fake
  "connected".)
- Onboarding never persists a URL that failed validation.
- Timeouts: 10s connect for `status()`; offline state is a first-class UI state,
  not an error dialog.

## 8. CI / OTA pipeline

**Workflow `build.yml` (on push to `main` + manual dispatch):**
1. `runs-on: macos-15` (or `macos-26` when available); select Xcode 26.
2. Resolve SwiftPM deps; run `xcodebuild test` (XCTest) on a simulator.
3. `xcodebuild archive ... CODE_SIGNING_ALLOWED=NO` → `.xcarchive`.
4. `ci/make-ipa.sh`: copy `.app` into `Payload/`, zip → `HermesNative.ipa`
   (unsigned — AltStore signs on device).
5. Derive version from `git` (tag or `0.0.<run_number>`); create a GitHub Release
   and upload the `.ipa` as an asset.
6. `ci/gen-source.sh`: regenerate `source.json` (AltStore schema: app name,
   bundleID, localized name, versions[] with `version`, `date`, `downloadURL`
   → release asset URL, `size`, `minOSVersion: "26.0"`); commit `source.json`
   back to `main`. The AltStore source URL is the raw GitHub URL of that file
   (`raw.githubusercontent.com/SenulMapa/hermes-native/main/source.json`) — no
   GitHub Pages setup needed.

**AltStore side (one-time, manual by user):** add that raw `source.json` URL as a
source in AltStore → install → thereafter each CI run shows an in-app update.

**No secrets** are required in the repo or Actions for the free-Apple-ID path.

## 9. Testing & verification strategy

- **Unit (CI):** `HermesAPI` — decode a fixture `ServerStatus`; `KeychainStore`
  round-trip; `HermesError` mapping. `HermesGlass` — token/contract smoke tests.
- **Build (CI):** archive must succeed; `.ipa` artifact must be produced.
- **Manual (user, on device):** sideload via AltStore, enter NAS URL over
  Tailscale, confirm green "Connected to Hermes" pill; push a trivial change and
  confirm the OTA update prompt appears.
- **Definition of done (Phase 0):** all of the above green, and the app is
  installed on the user's device receiving OTA updates.

## 10. Risks & open questions

1. **Xcode 26 on GitHub-hosted runners** — must confirm the runner image ships
   Xcode 26 (iOS 26 SDK). Mitigation: pin image/Xcode version; fall back to
   self-hosted Mac runner if unavailable. *(Verify during Phase 0 build.)*
2. **Hermes web server reachability from the phone** — which port the web/API
   server listens on, and the Tailscale hostname the app should default to.
   *(Confirm the base URL during onboarding implementation.)*
3. **`/api/status` auth** — whether it's reachable unauthenticated or already
   needs a ticket/token. If gated, Phase 0 onboarding may need a minimal token
   step earlier than Phase 1. *(Probe before building onboarding.)*
4. **AltStore free-account limits** — 3-app cap, 7-day expiry, AltServer refresh
   on same network. Accepted (user chose free Apple ID).
5. **Bundle identifier** — pick a stable reverse-DNS ID (e.g.
   `com.senulmapa.hermesnative`) now; changing it later re-registers the app.

## 11. Roadmap context (for reference, not this spec)

Phase 0 Foundation → 1 Chat → 2 SSH Terminal → 3 Models/Settings → 4 Cron →
5 Tool-cards/Sub-agents → 6 Projects/Files → 7 Voice/Notifications →
8 Search/Memory/Skills/Telegram/Browser/Vision → 9 Sync/macOS/Watch/A11y/Security.
Each is its own spec → plan → build → sideload cycle.
