# FanzyZones

A native macOS window-zone snapping tool — like Microsoft PowerToys' FancyZones, built
in Swift for macOS. Define zone layouts, then snap windows into them by dragging or with
keyboard shortcuts. Lives in the menu bar.

![menu bar app](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-6-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **7 built-in layouts** — Two/Three Panes, Ultrawide variants, Quarters, 3×3 Grid, Priority.
- **Visual menu** — each layout is a live mini-diagram; click a pane to snap the focused
  window there, click the name to make it the active layout.
- **Drag to snap** — hold a modifier (Shift by default) and drag a window to snap it into a
  zone, with a live overlay. Or enable **auto-snap** on any window drag.
- **Keyboard shortcuts** — `⌃⌥←/→` cycle zones, `⌃⌥1…9` snap to a specific zone.
- **Custom layout editor** — draw, move, resize, and split panes on a screen-shaped canvas;
  save named layouts.
- **Per-display layouts** — assign a different layout to each monitor.
- **Configurable** — modifier keys, inter-zone gap, outer padding, overlay color/opacity,
  zone numbers, launch-at-login.

Settings and layouts are stored as JSON in `~/Library/Application Support/FanzyZones/`.

## Install

### Homebrew (tap)

```sh
brew install --cask benwbooth/fanzyzones/fanzyzones
```

> FanzyZones is signed but not notarized. On first launch, right-click the app →
> **Open**, or allow it in **System Settings → Privacy & Security**.

### Download

Grab the latest `FanzyZones.dmg` from the [Releases](https://github.com/benwbooth/fanzyzones/releases)
page, open it, and drag **FanzyZones** to Applications.

### Build from source

Requires Xcode (full) and Swift 6.

```sh
git clone https://github.com/benwbooth/fanzyzones.git
cd fanzyzones
make app          # builds FanzyZones.app and code-signs it
open ./FanzyZones.app
```

## Permissions

FanzyZones needs **Accessibility** permission to move other apps' windows. On first launch
it prompts you; enable **FanzyZones** in System Settings → Privacy & Security → Accessibility.

For local development, rebuilds change the app's code signature (ad-hoc), which makes macOS
re-prompt for Accessibility every build. To make the grant stick, create a stable self-signed
identity once:

```sh
./scripts/make-signing-cert.sh      # creates a "FanzyZones Dev" code-signing identity
make app                            # signs with it from now on
```

If a permission grant gets into a confused state, reset it with:

```sh
tccutil reset Accessibility com.fanzyzones.app
```

## Usage

1. Click the menu-bar icon (three rectangles).
2. Pick a layout (click its **name** to make it active for drag/keyboard snapping).
3. **Snap** a window by clicking a pane in the menu, holding Shift while dragging it, or with
   the keyboard shortcuts.
4. **Settings…** to change the modifier, gap/padding, overlay appearance, and shortcuts.
5. **Create Custom Layout…** to design your own.

## Architecture

A menu-bar agent (`LSUIElement`) in Swift + SwiftUI (editor/settings) + AppKit (status item,
overlay, window control).

| Area | Files |
| --- | --- |
| Window control (Accessibility API) | `Sources/FanzyZones/Window/` |
| Coordinate math (Cocoa ↔ AX, normalized↔pixel) | `Display/Geometry.swift` |
| Drag detection (`CGEventTap`) | `Drag/DragMonitor.swift` |
| Zone overlay (`NSWindow` per display) | `Overlay/` |
| Visual menu | `Menu/` |
| Custom layout editor (SwiftUI) | `Editor/` |
| Settings, About | `Settings/`, `About/` |
| Models + JSON persistence | `Models/`, `Store/` |
| Global hotkeys (Carbon) | `Input/HotkeyManager.swift` |

## License

[MIT](LICENSE) © Ben Booth
