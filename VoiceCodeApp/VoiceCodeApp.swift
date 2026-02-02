import SwiftUI
import Combine

// Shared state singleton
class TranscriptionState: ObservableObject {
    static let shared = TranscriptionState()
    
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var lastTranscription = ""
    @Published var transcriptionHistory: [TranscriptionItem] = []
    @Published var modelDownloadProgress: Double = 0
    @Published var isModelReady = false
    @Published var errorMessage: String?
    
    // Transcription mode (stored in UserDefaults)
    @Published var transcriptionMode: TranscriptionMode {
        didSet {
            UserDefaults.standard.set(transcriptionMode.rawValue, forKey: "transcription_mode")
        }
    }
    
    private init() {
        // Load saved mode or default to local
        let savedMode = UserDefaults.standard.string(forKey: "transcription_mode") ?? "local"
        self.transcriptionMode = TranscriptionMode(rawValue: savedMode) ?? .local
    }
    
    func addTranscription(_ text: String) {
        let item = TranscriptionItem(text: text, timestamp: Date())
        transcriptionHistory.insert(item, at: 0)
        lastTranscription = text
        
        // Keep only last 20 items
        if transcriptionHistory.count > 20 {
            transcriptionHistory = Array(transcriptionHistory.prefix(20))
        }
    }
    
    func reset() {
        isRecording = false
        isTranscribing = false
        errorMessage = nil
    }
}

struct TranscriptionItem: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
}

@main
struct VoiceCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var transcriptionState = TranscriptionState.shared
    
    var body: some Scene {
        MenuBarExtra("VoiceCode", systemImage: transcriptionState.isRecording ? "waveform.circle.fill" : "waveform") {
            ContentView()
                .environmentObject(transcriptionState)
        }
        .menuBarExtraStyle(.window) // Keep this for the main UI
        
        // Removed Settings scene to avoid conflict/double menus
        // Apps with LSUIElement=1 (agent apps) don't need a main WindowGroup
    }
}
