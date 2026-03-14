# Slate

A minimalist daily journal for macOS. One entry per day. No cloud, no accounts, no distractions.

---

## Features

- Clean, distraction-free writing — monospace font, minimal chrome
- Auto-saves as you type
- **Slash commands** — type `/` at the start of a line to insert:
  - To-do checkboxes (click to check/uncheck, strikethrough on complete)
  - Bullet points
- **Bullet list continuation** — press Return to continue a list, double Return to exit
- **Past Documents** — browse and reopen previous entries (`⌘⇧H`)
- **Open** any `.md`, `.txt`, `.rtf`, or `.html` file into today's entry (`⌘O`)
- **Save As** — export to `.txt`, `.md`, `.rtf`, or `.html` (`⌘⇧S`)
- Appearance: System Default / Light / Dark (`Slate → Appearance`)
- All data stored locally in `~/Library/Application Support/Slate/`

---

## Download

Go to [Releases](../../releases) and download **Slate.dmg**.

### Install

1. Open the DMG and drag **Slate.app** into Applications
2. First launch: right-click → **Open** → click **Open** when macOS prompts

> This app is unsigned (no Apple Developer account). The right-click → Open step is a one-time bypass for macOS Gatekeeper.

---

## Build from Source

Requires Xcode 15+ and macOS 14+.

```bash
git clone https://github.com/vipinmeena1468/slate.git
cd slate/swift-app
open Slate.xcodeproj
```

Then press `⌘R` to build and run.

---

## Tech Stack

- Swift + SwiftUI
- AppKit (NSTextView, NSTextStorage, NSTextAttachment)
- RTFD format for rich text persistence with attachment support
