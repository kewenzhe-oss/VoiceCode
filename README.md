# 🎙️ VoiceCode

**Voice-to-Code for macOS — Speak, and it types.**

VoiceCode is a lightweight macOS menu-bar app that converts your voice into text and pastes it directly into any active window — editor, terminal, browser, you name it. Powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit) for fully offline transcription, with optional cloud backends for extra speed or accuracy.

---

## ✨ Features

| Feature | Details |
|---|---|
| 🔑 **Global Hotkey** | Press **⌥ Space** (Option + Space) from anywhere to start recording |
| 🎙️ **Two Trigger Modes** | **Hold-to-Talk** (hold key while speaking) or **Click-to-Toggle** (press once to start, again to stop) |
| 📋 **Auto-Paste** | Transcribed text is automatically pasted into your active app (VS Code, Xcode, Terminal, etc.) |
| 🖥️ **Menu Bar App** | Lives quietly in your menu bar — no Dock icon, no clutter |
| 🔒 **Fully Offline Mode** | Uses on-device WhisperKit; nothing leaves your Mac |
| ☁️ **Cloud Backends** | Optional OpenAI Whisper API or Hugging Face Inference API |
| 🧠 **AI Post-Processing** | Optionally clean up results with OpenAI GPT or Google Gemini |
| 🌐 **Multilingual** | Auto-detects language (English, Chinese, and more) |
| 📜 **Transcription History** | Last 20 transcriptions stored and viewable in the app |
| 🔔 **Sound Feedback** | Configurable audio cues for record start, stop, and paste events |

---

## 🚀 Installation

### Option 1: Download Pre-built App *(Recommended)*

1. Go to the [**Releases**](../../releases) page.
2. Download **VoiceCode.zip**.
3. Unzip and drag `VoiceCode.app` to your **Applications** folder.
4. Launch the app.
   > ⚠️ **First Launch**: Since this app isn't notarized yet, right-click the app and choose **"Open"** to bypass Gatekeeper.
5. Grant the following permissions when prompted:
   - **Microphone** — to record your voice
   - **Accessibility** — to paste text into other apps

### Option 2: Build from Source

**Requirements:** macOS 14.0+, Xcode 15+

```bash
git clone https://github.com/kewenzhe-oss/VoiceCode.git
cd VoiceCode
open VoiceCodeApp.xcodeproj
```

In Xcode:
1. Go to **Signing & Capabilities** → set your Personal Team.
2. Press **⌘R** to build and run.

---

## 🛠️ Configuration

Open **Settings** from the menu bar icon (VoiceCode → Settings).

### Transcription Mode

| Mode | Description |
|---|---|
| **Local (WhisperKit)** | 100% offline. First run downloads the model. Fast after warm-up. |
| **OpenAI API** | Cloud-based. Fast and highly accurate. Costs ~$0.006/min. |
| **Hugging Face API** | Cloud-based. Free tier available. |

### Local Model Size

Choose a model that fits your needs. Models are downloaded automatically on first use.

| Model | Size | Speed | Accuracy |
|---|---|---|---|
| Tiny | ~75 MB | ⚡⚡⚡⚡ Fastest | Basic |
| **Base** *(default)* | ~145 MB | ⚡⚡⚡ Fast | Good |
| Small | ~483 MB | ⚡⚡ Medium | Better |
| Medium | ~1.5 GB | ⚡ Slower | Great |
| Large-v3 | ~3 GB | 🐢 Slowest | Best |

### Hotkey

The default hotkey is **⌥ Space**. You can customize the key combination and trigger mode in **Settings → Hotkey**.

### API Keys

Go to **Settings → API Keys** to configure:
- **OpenAI API Key** — required for OpenAI cloud mode and GPT post-processing
- **Hugging Face API Key** — required for Hugging Face cloud mode
- **Google Gemini API Key** — optional, for Gemini-powered post-processing

### AI Post-Processing *(Optional)*

Enable AI cleanup to improve transcription quality — useful for mixed Chinese/English input, fixing speech recognition errors, and preserving code syntax. Supports **OpenAI GPT-4o mini** or **Google Gemini**.

---

## 🏗️ Architecture

```
VoiceCodeApp/
├── VoiceCodeApp.swift          # App entry point, menu bar integration
├── AppDelegate.swift           # Lifecycle, hotkey wiring, settings window
├── Services/
│   ├── HotkeyManager.swift     # Carbon-based global hotkey (hold / toggle)
│   ├── HotkeyPreference.swift  # Hotkey config & display string
│   ├── AudioRecorder.swift     # Microphone capture → WAV file
│   ├── TranscriptionService.swift    # WhisperKit local transcription
│   ├── CloudTranscriptionService.swift # OpenAI / Hugging Face APIs
│   ├── AIPostProcessor.swift   # GPT / Gemini post-processing
│   ├── ClipboardManager.swift  # Save context + auto-paste
│   ├── TranscriptionCoordinator.swift # Orchestrates the full pipeline
│   ├── IndicatorWindow.swift   # Floating recording indicator window
│   └── PermissionService.swift # Microphone & Accessibility checks
└── Views/
    ├── ContentView.swift        # Main menu-bar panel UI
    ├── DesktopIndicatorView.swift # On-screen recording indicator
    ├── SettingsView.swift       # Settings container
    ├── TranscriptionSettingsView.swift
    ├── HotkeySettingsView.swift
    ├── APIKeysSettingsView.swift
    ├── PermissionsSettingsView.swift
    └── AboutSettingsView.swift
```

---

## 🔐 Privacy

- **Local mode:** Audio is processed entirely on-device using WhisperKit. Nothing is sent to any server.
- **Cloud mode:** Audio is sent to OpenAI or Hugging Face over HTTPS. API keys are stored in macOS `UserDefaults` (local to your machine).
- **AI post-processing:** Only the transcribed text (not audio) is sent to the AI provider.

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## 📄 License

[MIT](LICENSE)
