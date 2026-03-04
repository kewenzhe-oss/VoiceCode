import AppKit
import SwiftUI
import AVFoundation
import UserNotifications
import Combine

@MainActor
class TranscriptionCoordinator: ObservableObject {
    private var audioRecorder: AudioRecorder?
    private var transcriptionService: TranscriptionService?
    private var cloudTranscriptionService: CloudTranscriptionService?
    private var clipboardManager: ClipboardManager?
    private var indicatorWindow: IndicatorWindow?
    
    private var modelInitializationTask: Task<Void, Never>?
    
    private var transcriptionState: TranscriptionState {
        TranscriptionState.shared
    }
    
    init() {
        clipboardManager = ClipboardManager()
        audioRecorder = AudioRecorder()
        transcriptionService = TranscriptionService()
        cloudTranscriptionService = CloudTranscriptionService()
    }
    
    func start() {
        // Setup Desktop Indicator
        DispatchQueue.main.async {
            self.indicatorWindow = IndicatorWindow()
            self.indicatorWindow?.orderFront(nil) // Show it
        }
        
        // Register notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleModeChange), name: Notification.Name("TranscriptionModeChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleModelChange), name: Notification.Name("ModelSizeChanged"), object: nil)
    }
    
    func checkAndWarmupModel() {
        if transcriptionState.transcriptionMode == .local {
            reloadLocalModel()
        }
    }
    
    @objc private func handleModeChange() {
        Task { @MainActor in
            switch transcriptionState.transcriptionMode {
            case .local:
                print("🔄 Switched to Local - Loading Model")
                reloadLocalModel()
            case .openai, .huggingface:
                print("🔄 Switched to Cloud - Unloading Model")
                modelInitializationTask?.cancel()
                transcriptionService?.unload()
                transcriptionState.modelState = .notReady
            }
        }
    }
    
    @objc private func handleModelChange() {
        guard transcriptionState.transcriptionMode == .local else { return }
        reloadLocalModel()
    }
    
    private func reloadLocalModel() {
        guard transcriptionState.transcriptionMode == .local else { return }
        let targetSize = transcriptionState.modelSize
        
        print("🔄 Model Initialization Triggered -> Target: \\(targetSize.displayName)")
        
        // Cancel any ongoing model loading to prevent duplicate initials
        modelInitializationTask?.cancel()
        
        modelInitializationTask = Task { @MainActor in
            // Instantly clear out old models and set state to warming
            transcriptionService?.unload()
            transcriptionState.modelState = .warming
            transcriptionState.modelDownloadProgress = 0
            transcriptionService?.modelSize = targetSize
            
            print("📦 Loading Whisper model (\\(targetSize.modelName))...")
            
            do {
                guard let service = transcriptionService else { return }
                try await service.initialize { progress in
                    Task { @MainActor in
                        self.transcriptionState.modelDownloadProgress = Float(progress)
                    }
                }
                
                // Catch cancellation edge cases right before registering as .ready
                try Task.checkCancellation()
                
                transcriptionState.modelState = .ready
                transcriptionState.modelDownloadProgress = 1.0
                print("✅ Model loaded successfully: \\(targetSize.modelName)")
                
            } catch is CancellationError {
                print("⚠️ Model loading cancelled for \\(targetSize.modelName), newer request likely taking over.")
            } catch {
                if !Task.isCancelled {
                    transcriptionState.modelState = .error
                    transcriptionState.showError("Model load failed: \\(error.localizedDescription)")
                    print("❌ Model error: \\(error)")
                }
            }
        }
    }
    
    func beginRecording() {
        print("🎙️ Event triggered - start recording")
        // Save app context first (before we potentially steal focus)
        clipboardManager?.saveFrontmostApp()
        
        // Ensure app is visible (since we hide it after pasting)
        DispatchQueue.main.async {
            if NSApp.isHidden {
                NSApp.unhide(nil)
            }
            self.indicatorWindow?.orderFront(nil)
            
            self.transcriptionState.isRecording = true
            self.transcriptionState.clearError()
            
            // Re-trigger visual indicator immediately
            NotificationCenter.default.post(name: NSNotification.Name("RecordStarted"), object: nil)
        }

        do {
            try audioRecorder?.startRecording()
            if UserDefaults.standard.bool(forKey: "playFeedbackSounds") {
                NSSound(named: "Tink")?.play()
            }
            print("🎙️ Recording")
        } catch {
            print("❌ Record error: \\(error)")
            if UserDefaults.standard.bool(forKey: "playFeedbackSounds") {
                NSSound(named: "Basso")?.play()
            }
        }
    }
    
    func stopRecordingAndTranscribe() {
        print("🎙️ Event triggered - stop recording")
        
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
        
        if UserDefaults.standard.bool(forKey: "playFeedbackSounds") {
            NSSound(named: "Pop")?.play()
        }
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
                }
                
                let pasted = await self.clipboardManager?.copyAndPaste(text) ?? false
                
                try? FileManager.default.removeItem(at: audioURL)
                
                if pasted {
                    if UserDefaults.standard.bool(forKey: "playFeedbackSounds") {
                        NSSound(named: "Glass")?.play()
                    }
                    showNotification("✅ Done", text)
                } else {
                    if UserDefaults.standard.bool(forKey: "playFeedbackSounds") {
                        NSSound(named: "Basso")?.play()
                    }
                    showNotification("⚠️ Pasting Failed", "Text stored in clipboard: \\(text)")
                }
                
            } catch {
                await MainActor.run {
                    self.transcriptionState.isTranscribing = false
                    self.transcriptionState.showError(error.localizedDescription)
                }
                print("❌ Transcription error: \\(error)")
                if UserDefaults.standard.bool(forKey: "playFeedbackSounds") {
                    NSSound(named: "Basso")?.play()
                }
            }
        }
    }
    
    private func transcribeLocal(_ url: URL) async throws -> String {
        if !transcriptionState.isModelReady {
            reloadLocalModel()
            // Wait for it to finish initializing
            if let task = modelInitializationTask {
                _ = await task.result
            }
        }
        guard let service = transcriptionService, transcriptionState.isModelReady else {
            throw TranscriptionError.notInitialized
        }
        print("🎙️ Starting inference with local model: \\(service.modelSize.modelName)")
        return try await service.transcribe(audioURL: url)
    }
    
    private func transcribeCloud(_ url: URL, _ mode: TranscriptionMode) async throws -> String {
        guard let service = cloudTranscriptionService else {
            throw CloudTranscriptionError.invalidProvider
        }
        return try await service.transcribe(audioURL: url, provider: mode, language: nil)
    }
    
    private func showNotification(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(body.prefix(100))
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
