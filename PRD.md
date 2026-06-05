# Hermes Native — Product Requirements Document

A native iOS/iPadOS app that exposes the full Hermes Agent experience with a proper surface area for power use. Telegram becomes a notification/escalation channel; the native app becomes the primary interface.

**Author:** Valerie (hermes-agent, Nous Research)
**For:** Senul Mapa
**Target platforms:** iOS 17+ / iPadOS 17+ / macOS 14+ (Universal)
**Stack:** Swift 5.10 / SwiftUI / SwiftData / Observation framework / BackgroundTasks

---

## 1. Product Principles

1. **Terminal-grade, mobile-shaped.** No feature should be a watered-down version of what works in a real terminal. Full ANSI, full PTY, full keyboard, no compromises.
2. **Local-first.** Everything the user can read or do without a network roundtrip should be instant. Network is for sync, not blocking.
3. **Single device state.** iPhone, iPad, Mac share state via iCloud + CloudKit. Open on iPhone, pick up on Mac.
4. **The Telegram escape hatch is always there.** For one-shot quick messages and notifications, never replace the existing Telegram surface — augment it.

---

## 2. Core Architecture

### 2.1 Multi-agent surface

Hermes isn't a single agent. It's a routed system. The app surfaces all of them as first-class entities.

| Agent | Role | UI treatment |
|---|---|---|
| **Valerie** | Primary peer, default first contact | Avatar + name in every session, top of inbox |
| **Maya** | Coding sub-agent (autonomous) | Distinct avatar, "in progress" badges, PR/commit previews |
| **Vigil** | Security auditor | Read-only badge, can be summoned inline on any message |
| **Thursday** | Cron lead-hunter (and any future cron) | Background-only, never surfaces as chat unless user explicitly asks |

**Routing rules:**
- coding tasks → Maya (with Valerie supervising)
- security/code-review tasks → Vigil
- everything else → Valerie
- user can force-route by `@maya build the thing` / `@vigil review this diff`

### 2.2 Session model

- Each session = a conversation tree with branching
- Sessions are persisted locally (SwiftData) and synced via CloudKit
- Resume any session from any device, mid-stream
- Sessions have metadata: title, model, total tokens, total cost, started/updated, git branch (if applicable), tags

### 2.3 Models / Providers

- User configures providers (Anthropic, OpenAI, xAI, OpenRouter, custom)
- Per-session model override
- Cost tracker with running totals per session / per day / per month
- Model catalog shows context window, price/M input, price/M output, capability badges (vision, code, fast)

---

## 3. Chat / Conversation Features

### 3.1 Message composition

- **Multi-modal input:** text, voice (transcribed), images (multi-select, auto-compressed), files, code snippets
- **Voice input:** long-press to record, transcribed via on-device Speech framework, optional cloud re-transcription for accuracy
- **Camera capture:** inline, with annotation (arrows, highlights) before sending
- **File picker:** any iOS document provider
- **Clipboard paste detection:** if user copies a URL, image, or code, offer to send it
- **Quote/reply:** swipe a message → reply with quote
- **Mention:** `@valerie` `@maya` `@vigil` to route
- **Drafts:** persistent across sessions, never lose work

### 3.2 Message rendering

- **Markdown:** GitHub-flavored, rendered live as stream arrives
- **Code blocks:** syntax-highlighted (highlight.js or Splash), tap to expand, copy button, "open in editor" if user has an SSH session
- **Tables:** rendered as actual tables (Telegram is famously bad at this; here they're real)
- **LaTeX / KaTeX:** inline math rendered
- **Mermaid diagrams:** rendered as interactive SVG, tap nodes for details
- **Diff blocks:** side-by-side or unified, line numbers, syntax-highlighted
- **Tool call cards:** collapsible, shows tool name, args, result, timing
- **Sub-agent invocations:** shown as nested cards with the child agent's avatar and result
- **Streaming:** character-by-character (not word-by-word) with a stable scroll position
- **Stop button:** cancels mid-stream, shows partial
- **Regenerate:** rerun the last turn with same or different model
- **Edit & re-run:** edit user message, rerun the turn from that point
- **Branch:** at any user message, fork the conversation into a new session

### 3.3 Reactions / feedback

- Thumbs up / down on any assistant message
- On thumbs-down: optional quick feedback ("wrong", "too long", "off-topic", "good but redo")
- Stats tracked per session for self-improvement
- Long-press to copy raw markdown

### 3.4 Search

- Full-text search across all sessions
- Filters: date range, agent, model, has code blocks, has images
- Cmd-K / ⌘F shortcut on iPad/Mac
- On iPhone: pull-down search

### 3.5 Memory

- Visual representation of the user's memory file
- User can add/edit/delete entries
- Version history
- "What does Hermes remember about me?" prompt that shows curated view

---

## 4. Built-in SSH Terminal

This is the killer feature. Full PTY, not a crippled Mosh.

### 4.1 Connection management

- **Host list:** name, host, port, user, auth method, tags, last-seen
- **Auth methods:** password, key file (iOS Keychain-stored), agent forwarding
- **Config import:** `~/.ssh/config` parsing (with file picker import)
- **Multiple sessions per host:** tab/grid layout on iPad/Mac
- **Tailscale / WireGuard / SSH-over-TLS:** explicit support, no App Store restrictions because we use standard SSH protocol
- **Connection profiles:** `dev`, `prod`, `nas`, etc. with environment variables, default working dir, post-connect commands

### 4.2 Terminal emulator

- **Full xterm-256color support**
- **ANSI:** 16 colors, 256 colors, true color
- **Cursor modes:** block / underline / bar (configurable)
- **Scrollback:** 10,000+ lines, smooth scrolling
- **Mouse reporting:** click, drag, scroll wheel
- **Bracketed paste mode**
- **Resize:** dynamic, propagates `SIGWINCH`
- **Font:** SF Mono, JetBrains Mono, Fira Code, Cascadia Code, Menlo, custom .ttf import
- **Font size:** pinch-to-zoom or `⌘+/-`
- **Cursor blink:** on/off, rate
- **Bell:** visual flash, sound, none
- **Clipboard:** select-and-copy, paste on long-press
- **Selection modes:** normal, block, line
- **Keybindings:** full customization (Home, End, PgUp, PgDn, arrows, modifier chords)
- **Hardware keyboard:** iPad/Mac gets the full keyboard experience including Esc, F-keys, modifiers

### 4.3 TUI / visual app support

- **TUI rendering:** vim, htop, lazygit, btop, k9s — all work because we have a real PTY
- **Image protocol support:** iTerm2 / Sixel — so apps like `tiv`, `viu`, or `catimg` can show images inline
- **Hyperlinks:** OSC 8 — clickable URLs that work without breaking scroll
- **Status bar:** custom shell prompt at the bottom showing hostname, cwd, git branch, exit code

### 4.4 Tab / split / grid management

- **Tabs:** multiple sessions per window
- **Splits:** horizontal and vertical, drag-to-resize dividers
- **Grid:** 2x2, 3x3 layouts for sysadmin-style monitoring
- **Save layouts:** named configurations
- **Quick switch:** swipe between tabs, or keyboard shortcut

### 4.5 Pairing with chat

- **"Run command" button on any bash/code block in chat:** executes in user's selected SSH session
- **"Share to chat" from terminal:** pipe output into a chat message
- **"Ask Valerie about this" from terminal:** sends last N lines as context
- **"Open in editor" from chat:** opens file in connected SSH session's editor
- **Status indicator:** in the chat, show which SSH session is "active" so context is clear

---

## 5. Tools & Tool Use

### 5.1 Visible tool calls

- When Valerie uses a tool, the user sees a card with:
  - Tool icon (folder, terminal, browser, etc.)
  - Tool name and args (formatted JSON or readable form)
  - Result preview
  - Time taken
  - Tap to expand full output
  - "Rerun" button for tools that are safe to repeat
  - "Allow / Deny" for tools that need confirmation (file deletion, system commands, etc.)

### 5.2 Approval gates

- Per-tool-class permissions: "always allow read", "always allow network", "ask before file delete", "ask before exec"
- Per-host approval for SSH commands
- Dangerous actions (rm -rf, dd, mkfs, anything matching a blocklist) require explicit tap-to-approve even if user has "always allow" enabled
- All approvals are reversible during the same session

### 5.3 Tool categories (all surfaced in UI)

- **Filesystem:** read, write, edit, list, search
- **Terminal:** bash, with output streaming
- **Browser:** screenshots, click, fill, navigate, scroll, with back-button
- **Web:** search, fetch, extract
- **Image gen / vision:** view, generate, edit
- **Code:** execute, lint, format
- **Calendar / email / contacts:** Google, Outlook, iCloud integration
- **Spotify / HomeAssistant / Hue / Tailscale:** smart-home and music
- **Cron / scheduled tasks:** create, list, pause, resume, delete, run-now

### 5.4 Sub-agents (Maya / Vigil)

- When a sub-agent is spawned, user sees a live card: "Maya is working on..."
- Real-time progress (file edits, test runs, command output)
- Option to "ask Maya a question" mid-task
- Cancel button
- Final result lands as a card in the parent session

---

## 6. Cron / Scheduled Tasks

### 6.1 List view

- All scheduled jobs, with: name, schedule, next run, last run status, last output preview
- Group by: project, frequency, status
- Filter: enabled / paused / failed

### 6.2 Create flow

- Plain-English schedule ("every morning at 9am", "first of every month")
- Or cron expression with human-readable preview
- Pick delivery target: in-app, Telegram, iOS push, email, local file
- Pick model
- Test run (one-shot)
- Save

### 6.3 Execution

- Job runs on the user's machine, not on a server
- Output captured, saved
- Failure → push notification with retry options
- Long-running jobs show progress card in app

---

## 7. Skills System

### 7.1 Skill library

- Browse all installed skills
- Read SKILL.md content inline (rendered markdown)
- View usage stats (last used, times used, success rate)
- Pin / unpin
- Update / patch directly from inside the app (file editor with markdown preview)

### 7.2 Skill creation

- "Create new skill" wizard: name, description, trigger conditions, body
- Templates for common skill types (cron, file ops, web fetch, sub-agent)
- Test in a sandbox before saving
- Share/export as a .zip

### 7.3 Skill discovery

- Suggest skills based on recurring tasks in chat
- Community skills (optional) with ratings

---

## 8. Projects

### 8.1 Project metadata

- Name, path (local or remote SSH), git remote, primary model
- Per-project memory
- Per-project skills
- Per-project cron
- Per-project cost tracking

### 8.2 Project views

- **Files:** browsable file tree, in-app editor (with syntax highlighting, find/replace)
- **Terminal:** dedicated SSH session tied to project
- **Chat:** scoped chat, only sees project context
- **Tasks:** running jobs, scheduled, completed
- **Memory:** what Hermes knows about this project
- **Git:** branch, status, recent commits, can ask Valerie to commit / PR
- **Cost:** tokens used, dollars spent

### 8.3 Multi-device project state

- Open on iPhone, pick up on Mac
- Active SSH session roams between devices
- Editor cursor position syncs
- Pending tool approvals appear on all devices, approve from any

---

## 9. File Operations

### 9.1 In-app file browser

- Browse local (Files app integration) and remote (SSH SFTP)
- Multi-select, batch operations
- Inline preview: text, code, markdown, images, PDFs, video, audio
- Quick Look integration
- Drag-and-drop to/from other apps

### 9.2 Editor

- Syntax-highlighted code editor (replace Textastic / Code editors for SSH files)
- Monospace font, configurable
- Find/replace (single file, multi-file)
- Auto-save
- Diff against previous version
- "Ask Valerie to refactor" inline button

### 9.3 Transfer

- Drag file from iCloud Drive → SSH session
- Drag from SSH session → iCloud Drive
- Background uploads/downloads with progress
- Resume on connection drop

---

## 10. Browser / Web Automation

When Valerie uses the browser tool, the user sees:

- A live browser view: "Valerie is browsing..."
- Mini-map of current URL, page title
- Take-over: "let me drive" — user can interact with the browser themselves, then hand back
- Screenshot preview inline in chat
- All actions (clicks, fills, scrolls) replayable as a step list

---

## 11. Vision / Images

- **Image send:** from camera, photo library, drag-drop, paste
- **Image view:** inline in chat, full-screen pinch-to-zoom
- **Image generation:** kick off DALL-E / Stable Diffusion, get results inline
- **Vision analyze:** "what's in this image?" inline tool
- **Image edit:** crop, annotate, redact, share

---

## 12. Audio / Voice

### 12.1 Voice input

- Push-to-talk or always-listening (with permission)
- Real-time transcription
- Voice commands ("Valerie, send a message to Maya")

### 12.2 Voice output (TTS)

- Valerie can speak long responses for hands-free consumption
- Configurable voice, speed, pitch
- Auto-play vs on-demand
- Background audio support (continues when phone locked)

### 12.3 Audio messages

- Receive audio from Telegram or other channels
- Transcribe on receipt
- Store with timestamps

---

## 13. Notifications

- **Push:** new message, cron job result, sub-agent finished, system alert
- **In-app inbox:** all notifications, mark read, filter
- **Critical alerts:** opt-in for things that shouldn't be silenced (security events, build failures)
- **Snooze:** mute a thread for X hours

---

## 14. Sync / Backup

- **iCloud:** all sessions, memory, project metadata sync via CloudKit
- **End-to-end encryption:** for sensitive content (memory file, custom skills)
- **Export:** full archive as .zip, including all sessions as JSON+attachments
- **Import:** from JSON archive, from Telegram export

---

## 15. Settings

### 15.1 Account / Auth

- Hermes account (for cross-device sync)
- Provider keys: Anthropic, OpenAI, etc. (stored in iOS Keychain)
- API keys for integrations: GitHub, Tailscale, Spotify, Google, etc.

### 15.2 Models

- Default model per session type
- Cost limits (daily / monthly) with hard stops
- "Auto" mode (let Valerie pick the best model for the task)

### 15.3 Privacy

- What Hermes can remember: list, edit, clear
- What tools are enabled
- Tool-approval levels
- Analytics opt-in/out
- Delete all data

### 15.4 Appearance

- Theme: system / light / dark / true black
- Accent color
- Font: system / serif / mono
- Density: compact / comfortable
- Animations: on / reduced / off

### 15.5 SSH

- Default key, default user
- Keep-alive interval
- Compression on/off
- Agent forwarding
- Known hosts management

### 15.6 Telegram bridge

- Connected: yes/no
- Mode: receive-only / bidirectional / off
- Specific chats to bridge

---

## 16. Onboarding

- First-launch wizard
- SSH key generation (ed25519 by default), export as .pub, copy to clipboard
- Connect to a host in 3 taps
- Try a sample session
- Optional: connect Telegram, link account

---

## 17. iPad-Specific Features

- **Multi-window:** open 2-3 chat sessions side by side
- **Stage Manager:** drag windows around
- **Sidebar:** collapsible nav
- **Keyboard shortcuts:** full ⌘-palette
- **Pointer support:** hover states, right-click menus
- **External display:** full screen on second monitor
- **Drag-and-drop from other iPad apps:** Files, Safari, Photos

---

## 18. Mac (Catalyst or native) Features

- Menu bar app: quick chat input, status
- Global hotkey: open chat window from anywhere
- Spotlight integration: "Hermes: ..."
- Share extension: send to Hermes from any app
- Quick Look preview of sessions
- Touch Bar support (legacy)
- Multiple windows, tabs

---

## 19. Apple Watch (stretch)

- Quick voice: "send to Valerie"
- Notification glance
- Glanceable cron results

---

## 20. Accessibility

- Full VoiceOver support
- Dynamic Type (all text scales)
- High-contrast mode
- Reduce motion respect
- Switch Control
- All actions keyboard-accessible

---

## 21. Security

- **Local encryption:** SQLite database encrypted at rest using iOS Data Protection (Complete)
- **Keychain:** all secrets in Keychain, never in plaintext
- **TLS everywhere:** all Hermes server traffic over TLS 1.3
- **SSH host key pinning:** first-connect stores, subsequent compares
- **Biometric gates:** approve high-risk tools with Face ID / Touch ID
- **Audit log:** every tool call, every approval, every denial — searchable
- **Remote wipe:** if device is reported lost, kill the session sync token

---

## 22. Performance Targets

- **Cold launch to chat:** < 1 second
- **Message stream first-token:** < 300ms
- **SSH connect (LAN):** < 500ms
- **Search results:** < 200ms for sessions, < 1s for full-text
- **Memory footprint:** < 200MB idle, < 500MB with 10k messages cached

---

## 23. Open Questions for the User

1. **iOS only, or iOS + Mac via Catalyst / native?**
   - Catalyst is faster to ship but uglier. Native SwiftUI multiplatform is the long-term right answer but doubles work.
2. **Tailscale integration: do you want it built-in or rely on system VPN profile?**
   - Built-in: smoother but requires Tailscale SDK or their iOS app's network extension sharing.
3. **iCloud sync vs custom sync server?**
   - iCloud is free and works, but you don't control it. Custom server = more flexibility, more ops burden.
4. **Pricing model?**
   - Free + paid tiers? One-time purchase? Subscription? Open source + self-host?
5. **App Store or TestFlight only?**
   - App Store has review friction but discoverability. TestFlight = you control distribution, no review.
6. **Background tasks: do cron jobs run on the device, or on a server?**
   - On device = no server cost, but iOS throttles background. On server = always-on but you need infra.

---

## 24. Phasing

**V1 (MVP, 4-6 weeks):**
- Chat with streaming, markdown, code blocks, images
- SSH terminal with full PTY
- Single host, single key
- iPhone + iPad
- iCloud sync
- Telegram bridge (bidirectional)

**V2 (1-2 months after V1):**
- Sub-agents (Maya, Vigil) with live progress
- Skills system (browse, create, edit)
- Cron management
- Projects
- macOS native
- In-app file browser + editor

**V3 (3+ months):**
- Browser automation view
- Voice I/O
- Tailscale integration
- Apple Watch
- App Store launch

---

## 25. Cost / Build Estimate (for a Swift dev)

- **V1:** 4-6 weeks full-time
- **V2:** 1-2 months full-time
- **V3:** 2-3 months full-time
- **Ongoing:** 0.5-1 FTE for maintenance + new features

this assumes the dev is comfortable with SwiftUI, SwiftData, Network.framework (for SSH), and iOS background execution limits. SSH terminal emulator is the most technically demanding piece — getting TUI apps to render correctly takes real work.

---

end of PRD.
