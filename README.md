# 🎙️ VoiceCode

**Voice-to-Code Assistant for macOS.**  
Turn your voice into code instantly with global hotkeys and AI-powered transcription. Designed for developers who want to speed up their workflow or code hands-free.

## ✨ Features

*   **Global Hotkey**: Press **Option + Space** anywhere to start listening.
*   **Auto-Paste**: Transcription is automatically typed into your active editor (VS Code, Xcode, Notes, etc.).
*   **"Island" UI**: A beautiful, unobtrusive floating indicator that sits on your Dock.
*   **Privacy First**: Uses local/cloud OpenAI Whisper API (configurable).
*   **Native & Fast**: Built with Swift, SwiftUI, and AppKit. Clean, lightweight, and battery-friendly.

## 🚀 Installation

### Option 1: Download Pre-built App (Recommended)
1.  Go to the [Releases](../../releases) page.
2.  Download **VoiceCode.zip**.
3.  Unzip and drag `VoiceCode.app` to your **Applications** folder.
4.  Launch the app.
    *   *Note: Since this app is not signed by Apple Developer ID (yet), you may need to right-click and select "Open" for the first time.*
5.  **Permissions**:
    *   Grant **Accessibility** access when prompted (to paste text).
    *   Grant **Microphone** access (to hear you).

### Option 2: Build from Source
Requirements: macOS 14.0+, Xcode 15+.
1.  Clone this repository:
    ```bash
    git clone https://github.com/kewenzhe-oss/VoiceCode.git
    ```
2.  Open `VoiceCodeApp.xcodeproj` in Xcode.
3.  Ensure Signing Team is set to your Personal Team in Project Settings.
4.  Build and Run (Cmd + R).

## 🛠️ Configuration

VoiceCode works out of the box.
*   **Change API Key**: Go to Menu Bar -> VoiceCode -> Settings to configure your OpenAI Key if using cloud mode.
*   **Local Mode**: (Coming soon) Toggle complete offline processing for maximum privacy.

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## 📄 License

[MIT](LICENSE)
