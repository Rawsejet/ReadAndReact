# CLAUDE.md — ReadAndReact

## Project Overview

ReadAndReact is a **macOS desktop application** that captures screenshots of a user-defined screen region at configurable intervals and sends them to a local LLM server (vLLM) for analysis. It uses a hybrid **SwiftUI + AppKit** architecture.

## Architecture

### Two-Window Design
1. **Overlay Panel** (`OverlayPanel.swift`) — A transparent, borderless, floating `NSPanel` with a green dashed border. Click-through interior so the user interacts with apps underneath. Draggable via edges, resizable via corner handles. Defines the screen capture region.
2. **Control Panel** (`ControlPanelView.swift`) — A SwiftUI window with all controls: interval, play/stop, save path, thumbnail preview, LLM configuration, and response display.

### Key Files
| File | Purpose |
|------|---------|
| `ReadAndReactApp.swift` | `@main` SwiftUI App entry point, manages `CaptureState` and panel connection |
| `AppDelegate.swift` | `NSApplicationDelegate` — creates overlay panel, requests screen capture permission |
| `OverlayPanel.swift` | Custom `NSPanel` + `OverlayContentView` (`NSView`) with hit-testing, drag, and resize |
| `CaptureState.swift` | `@MainActor ObservableObject` shared state — capture settings, timer, LLM config |
| `ScreenshotService.swift` | Screenshot capture using `SCScreenshotManager` (ScreenCaptureKit) |
| `LLMService.swift` | HTTP client for vLLM OpenAI-compatible `/v1/chat/completions` API |
| `ControlPanelView.swift` | SwiftUI view with all user-facing controls and status display |
| `Info.plist` | Contains `NSScreenCaptureUsageDescription` for screen recording permission |

### Dependencies & Frameworks
- **SwiftUI** — Control panel UI
- **AppKit** — Overlay panel (NSPanel, NSView)
- **ScreenCaptureKit** — Screenshot capture (`SCScreenshotManager.captureImage(in:)`)
- **Combine** — Required for `@Published` property wrappers in `ObservableObject`
- **Foundation** — Networking (`URLSession`), file I/O, timers

No third-party dependencies. No Swift packages.

## Build & Run

- **Platform**: macOS 26.0+
- **Xcode**: Open `ReadAndReact.xcodeproj`, select the `ReadAndReact` scheme, build and run
- **Sandbox**: Disabled (required for `CGWindowListCreateImage`/ScreenCaptureKit and arbitrary file writes)
- **Hardened Runtime**: Enabled
- **Signing**: "Apple Development" (local signing)
- **Default actor isolation**: `MainActor` (set via `SWIFT_DEFAULT_ACTOR_ISOLATION` build setting)

### Permissions
The app requires **Screen Recording** permission in System Settings > Privacy & Security. Without it, screenshots will only capture the desktop wallpaper. The app calls `CGRequestScreenCaptureAccess()` on first launch.

## Code Patterns

### Concurrency
- All UI state is `@MainActor`-isolated via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- Screenshot capture and LLM calls use `async/await`
- Timer-based capture dispatches to `Task { @MainActor in ... }`
- Avoid Combine — use Swift async/await instead

### Overlay Panel Mechanics
- `hitTest(_:)` returns `nil` for interior (click-through), `self` for border zone
- Corner zones → resize drag; edge zones → move drag
- Panel hides itself before screenshot capture, re-shows after (to exclude from capture)
- AppKit coordinate system (bottom-left origin) → CG coordinate system (top-left origin) conversion in `ScreenshotService`

### LLM Integration
- OpenAI-compatible `/v1/chat/completions` endpoint
- Screenshots sent as base64-encoded PNG data URIs in `image_url` content items
- Authorization header: `Bearer EMPTY` (vLLM default)
- Model name configurable in UI (e.g., `gemma-4-31b`)

### Panel Connection Timing
`AppDelegate` has an `onPanelReady` callback to handle the race between `applicationDidFinishLaunching` and SwiftUI's `onAppear`. `ReadAndReactApp.connectPanel()` tries immediate connection first, falls back to callback.

## Code Style
- **Naming**: PascalCase for types, camelCase for properties/methods
- **Properties**: `@State private var` for SwiftUI state, `let` for constants
- **Formatting**: 4-space indentation
- **Imports**: Minimal imports at top of file
- **Architecture**: SwiftUI views + `@EnvironmentObject` for shared state
- **Testing**: Use the Testing framework for unit tests, XCUIAutomation for UI tests

## Known Issues / TODOs
- `sendToLLM()` is fully implemented but requires a running vLLM server with a chat-template-compatible model (e.g., `gemma-4-31b-it` or base model with `--chat-template` flag)
- Screenshot naming: `SS_1.png`, `SS_2.png`, etc. — counter resets each session
- No persistence of settings between launches
