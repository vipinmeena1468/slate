# Slate

A minimalist writing app for macOS. Dark background, monospace font, no distractions.

---

## Features

- Clean, distraction-free writing experience
- Monospace font (IBM Plex Mono)
- Dark and light mode toggle
- Dash bullet lists — type `- ` at the start of a line
- Dot bullet lists — type `/` and select Bullet Point
- To-do checkboxes — type `/` and select To-Do
- Auto-saves to local storage
- Native macOS window with traffic light controls

## Download

Go to [Releases](../../releases) and download the DMG for your Mac:

- `Slate-0.1.0-arm64.dmg` — Apple Silicon (M1/M2/M3/M4)
- `Slate-0.1.0.dmg` — Intel

### Install

1. Open the DMG and drag **Slate.app** into Applications
2. First launch: right-click → **Open** → **Open** (macOS Gatekeeper bypass, one-time only)

---

## Build from Source

Requires Node.js 18+.

```bash
git clone https://github.com/YOUR_USERNAME/slate.git
cd slate
npm install
npm run dist
```

The DMG will be in the `release/` folder.

For development:

```bash
npm run dev        # browser only (localhost:5173)
npm run dev:electron  # native Electron window
```

---

## Tech Stack

- [Electron](https://www.electronjs.org/) — native macOS window
- [React](https://react.dev/) + [Vite](https://vitejs.dev/) — UI
- [Tiptap](https://tiptap.dev/) — rich text editor (ProseMirror-based)
- [Tippy.js](https://atomiks.github.io/tippyjs/) — slash command popup
