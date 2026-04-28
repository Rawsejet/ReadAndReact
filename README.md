# ReadAndReact

A macOS desktop application that captures screenshots of a user-defined screen region at configurable intervals and sends them to a local LLM server for analysis.

## Features

- **Transparent Overlay Window** — A draggable, resizable floating panel with a green dashed border. Position it over any area of the screen to define the capture region. The interior is click-through so you can interact with apps underneath.
- **Timed Screenshot Capture** — Automatically captures screenshots at a configurable interval (in seconds). Screenshots are saved as `SS_1.png`, `SS_2.png`, etc. to a directory of your choice.
- **LLM Integration** — Send captured screenshots with a text prompt to a local vLLM server (OpenAI-compatible API). Responses are displayed in a selectable text area for easy copy/paste.
- **Control Panel** — A SwiftUI window with play/stop controls, save path browser, screenshot thumbnail preview, LLM endpoint/model/prompt configuration, and status indicators.

## Requirements

- macOS 26.0+
- Xcode 26+
- **Screen Recording** permission (System Settings > Privacy & Security > Screen Recording)

## Setup

1. Clone the repository
2. Open `ReadAndReact.xcodeproj` in Xcode
3. Build and run (Cmd+R)
4. Grant screen recording permission when prompted, then restart the app

## Usage

1. **Position the overlay** — Drag the green-bordered overlay window over the screen region you want to capture. Resize using the corner handles.
2. **Configure capture** — Set the interval (seconds) and output directory in the control panel.
3. **Start capturing** — Click the Play button. Screenshots are saved automatically.
4. **Send to LLM** — Enter your vLLM endpoint (e.g. `http://192.168.1.154:8085`), model name (e.g. `gemma-4-31b-it`), and a prompt. Click "Send to LLM" to analyze the captured screenshots.

## Architecture

| File | Purpose |
|------|---------|
| `ReadAndReactApp.swift` | SwiftUI App entry point |
| `AppDelegate.swift` | NSApplicationDelegate — creates overlay, requests permissions |
| `OverlayPanel.swift` | Custom NSPanel with click-through interior, drag, and resize |
| `CaptureState.swift` | Shared ObservableObject state model |
| `ScreenshotService.swift` | ScreenCaptureKit-based screenshot capture |
| `LLMService.swift` | HTTP client for vLLM OpenAI-compatible API |
| `ControlPanelView.swift` | SwiftUI control panel UI |

## LLM Server

This app is designed to work with [vLLM](https://docs.vllm.ai/) serving a vision-capable model. Example:

```bash
python -m vllm.entrypoints.openai.api_server \
    --model google/gemma-4-31b-it \
    --port 8085
```

The app sends screenshots as base64-encoded images via the `/v1/chat/completions` endpoint.

## License

MIT
