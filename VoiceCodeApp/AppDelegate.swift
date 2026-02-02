import Cocoa
import SwiftUI
import AVFoundation
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var audioRecorder: AudioRecorder?
    private var transcriptionService: TranscriptionService?
    private var cloudTranscriptionService: CloudTranscriptionService?
    private var clipboardManager: ClipboardManager?
    // private var keyEventMonitor: KeyEventMonitor? // Removed in favor of HotKeyService
    private var indicatorWindow: IndicatorWindow?
    private var settingsWindow: NSWindow?
    
    private var transcriptionState: TranscriptionState {
        TranscriptionState.shared
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 VoiceCode starting...")
        
        checkPermissions()
        setupServices()
        
        // Notifications
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: Notification.Name("OpenSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleModeChange), name: Notification.Name("TranscriptionModeChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleModelChange), name: Notification.Name("ModelSizeChanged"), object: nil)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        // Load model ONLY if starting in local mode
        if transcriptionState.transcriptionMode == .local {
            // Apply saved model size first
            transcriptionService?.modelSize = transcriptionState.modelSize
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task { await self.initializeWhisperModel() }
            }
        }
        
        print("✅ VoiceCode ready")
    }
    
    @objc private func handleModeChange() {
        Task { @MainActor in
            switch transcriptionState.transcriptionMode {
            case .local:
                print("🔄 Switched to Local - Loading Model")
                if !transcriptionState.isModelReady {
                    await initializeWhisperModel()
                }
            case .openai, .huggingface:
                print("🔄 Switched to Cloud - Unloading Model")
                transcriptionService?.unload()
                transcriptionState.isModelReady = false
            }
        }
    }
    
    @objc private func handleModelChange() {
        guard transcriptionState.transcriptionMode == .local else { return }
        
        print("🔄 Model size changed to \(transcriptionState.modelSize.displayName) - Reloading...")
        
        Task { @MainActor in
            // Unload current
            transcriptionService?.unload()
            transcriptionState.isModelReady = false
            
            // Update service preference
            transcriptionService?.modelSize = transcriptionState.modelSize
            
            // Reload
            await initializeWhisperModel()
        }
    }
    
    private func setupServices() {
        clipboardManager = ClipboardManager()
        audioRecorder = AudioRecorder()
        transcriptionService = TranscriptionService()
        cloudTranscriptionService = CloudTranscriptionService()
        
        // Setup Desktop Indicator
        DispatchQueue.main.async {
            self.indicatorWindow = IndicatorWindow()
            self.indicatorWindow?.orderFront(nil) // Show it
        }
        
        // Setup Hotkey (Option + Space) using standard Carbon API
        HotKeyService.shared.onKeyDown = { [weak self] in
            self?.startRecording()
        }
        HotKeyService.shared.onKeyUp = { [weak self] in
            self?.stopRecordingAndTranscribe()
        }
        HotKeyService.shared.registerHotkey()
    }
    
    private func checkPermissions() {
        // Microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print(granted ? "✅ Mic granted" : "❌ Mic denied")
            }
        case .authorized:
            print("✅ Mic OK")
        default:
            print("❌ Mic not available")
        }
        
        // Accessibility - Critical for Hotkeys
        // First check without prompting to avoid double alerts
        let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)
        
        if trusted {
            print("✅ Accessibility OK")
        } else {
            print("⚠️ Need Accessibility permission")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "Permission Required"
                alert.informativeText = "VoiceCode needs 'Accessibility' permission to detect the Option+Space hotkey and paste text.\n\nPlease grant access in System Settings > Privacy & Security > Accessibility, then restart the app."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    // Trigger system prompt now so it registers in the list
                    let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                    AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
                    
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
    }
    
    private func initializeWhisperModel() async {
        guard let service = transcriptionService, !transcriptionState.isModelReady else { return }
        
        print("📦 Loading Whisper model...")
        await MainActor.run {
            transcriptionState.isModelReady = false
            transcriptionState.modelDownloadProgress = 0
        }
        
        do {
            try await service.initialize { progress in
                Task { @MainActor in
                    self.transcriptionState.modelDownloadProgress = progress
                }
            }
            await MainActor.run {
                transcriptionState.isModelReady = true
                transcriptionState.modelDownloadProgress = 1.0
            }
            print("✅ Model loaded")
        } catch {
            await MainActor.run {
                transcriptionState.errorMessage = "Model failed: \(error.localizedDescription)"
            }
            print("❌ Model error: \(error)")
        }
    }
    
    private func startRecording() {
        print("🎙️ Option+Space pressed - start recording")
        // 1. Save app context first (before we potentially steal focus)
        clipboardManager?.saveFrontmostApp()
        
        // 2. Ensure app is visible (since we hide it after pasting)
        DispatchQueue.main.async {
            if NSApp.isHidden {
                NSApp.unhide(nil)
            }
            self.indicatorWindow?.orderFront(nil)
            
            self.transcriptionState.isRecording = true
            self.transcriptionState.errorMessage = nil
        }

        do {
            try audioRecorder?.startRecording()
            NSSound(named: "Tink")?.play()
            print("🎙️ Recording")
        } catch {
            print("❌ Record error: \(error)")
            NSSound(named: "Basso")?.play()
        }
    }
    
    private func stopRecordingAndTranscribe() {
        print("🎙️ Option+Space released - stop recording")
        
        guard let audioURL = audioRecorder?.stopRecording() else {
            print("⚠️ No audio")
            DispatchQueue.main.async {
                self.transcriptionState.isRecording = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.transcriptionState.isRecording = false
            self.transcriptionState.isTranscribing = true
        }
        
        NSSound(named: "Pop")?.play()
        print("🎙️ Transcribing...")
        
        Task {
            do {
                let text: String
                switch transcriptionState.transcriptionMode {
                case .local:
                    text = try await transcribeLocal(audioURL)
                case .openai, .huggingface:
                    text = try await transcribeCloud(audioURL, transcriptionState.transcriptionMode)
                }
                
                await MainActor.run {
                    self.transcriptionState.isTranscribing = false
                    self.transcriptionState.addTranscription(text)
                    self.clipboardManager?.copyAndPaste(text)
                }
                
                try? FileManager.default.removeItem(at: audioURL)
                NSSound(named: "Glass")?.play()
                showNotification("✅ Done", text)
                
            } catch {
                await MainActor.run {
                    self.transcriptionState.isTranscribing = false
                    self.transcriptionState.errorMessage = error.localizedDescription
                }
                print("❌ Transcription error: \(error)")
                NSSound(named: "Basso")?.play()
            }
        }
    }
    
    private func transcribeLocal(_ url: URL) async throws -> String {
        if !transcriptionState.isModelReady {
            await initializeWhisperModel()
        }
        guard let service = transcriptionService, transcriptionState.isModelReady else {
            throw TranscriptionError.notInitialized
        }
        return try await service.transcribe(audioURL: url)
    }
    
    private func transcribeCloud(_ url: URL, _ mode: TranscriptionMode) async throws -> String {
        guard let service = cloudTranscriptionService else {
            throw CloudTranscriptionError.invalidProvider
        }
        return try await service.transcribe(audioURL: url, provider: mode, language: nil)
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView().environmentObject(transcriptionState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.center()
            window.contentView = NSHostingView(rootView: settingsView)
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func showNotification(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(body.prefix(100))
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
