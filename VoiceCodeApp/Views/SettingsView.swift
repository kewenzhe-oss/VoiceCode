import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: TranscriptionState
    @AppStorage("playFeedbackSounds") private var playFeedbackSounds = true
    @AppStorage("preferredLanguage") private var preferredLanguage = "auto"
    
    @State private var openaiKey = ""
    @State private var huggingfaceKey = ""
    
    private let cloudService = CloudTranscriptionService()
    
    var body: some View {
        TabView {
            transcriptionTab
                .tabItem { Label("Transcription", systemImage: "waveform") }
            
            apiKeysTab
                .tabItem { Label("API Keys", systemImage: "key") }
            
            hotkeyTab
                .tabItem { Label("Hotkey", systemImage: "keyboard") }
            
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 380)
        .onAppear { loadAPIKeys() }
    }
    
    // MARK: - Transcription Tab
    
    private var transcriptionTab: some View {
        Form {
            Section("Transcription Mode") {
                Picker("Mode", selection: $state.transcriptionMode) {
                    ForEach(TranscriptionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(modeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Language") {
                Picker("Preferred", selection: $preferredLanguage) {
                    Text("Auto-detect").tag("auto")
                    Text("English").tag("en")
                    Text("Chinese (中文)").tag("zh")
                    Text("Japanese").tag("ja")
                }
            }
            
            Section("Behavior") {
                Toggle("Play feedback sounds", isOn: $playFeedbackSounds)
            }
        }
        .formStyle(.grouped)
    }
    
    private var modeDescription: String {
        switch state.transcriptionMode {
        case .local: return "Runs locally. First run slow, then fast. Works offline."
        case .openai: return "Uses OpenAI API (~$0.006/min). Fast and accurate."
        case .huggingface: return "Uses Hugging Face API. Free tier available."
        }
    }
    
    // MARK: - API Keys Tab
    
    private var apiKeysTab: some View {
        Form {
            Section("OpenAI") {
                SecureField("API Key (sk-...)", text: $openaiKey)
                HStack {
                    Button("Save") { cloudService.setOpenAIKey(openaiKey) }
                        .disabled(openaiKey.isEmpty)
                    if cloudService.isOpenAIConfigured {
                        Text("✓ Saved").foregroundColor(.green)
                    }
                    Spacer()
                    Link("Get Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                }
            }
            
            Section("Hugging Face") {
                SecureField("API Key (hf_...)", text: $huggingfaceKey)
                HStack {
                    Button("Save") { cloudService.setHuggingFaceKey(huggingfaceKey) }
                        .disabled(huggingfaceKey.isEmpty)
                    if cloudService.isHuggingFaceConfigured {
                        Text("✓ Saved").foregroundColor(.green)
                    }
                    Spacer()
                    Link("Get Key", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func loadAPIKeys() {
        openaiKey = cloudService.getMaskedOpenAIKey() ?? ""
        huggingfaceKey = cloudService.getMaskedHuggingFaceKey() ?? ""
    }
    
    // MARK: - Hotkey Tab
    
    private var hotkeyTab: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Recording") {
                    Text("⌥ Space")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .padding(6)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            
            Section("Usage") {
                LabeledContent("Hold ⌥Space", value: "Start recording")
                LabeledContent("Release", value: "Transcribe & paste")
            }
            
            Section("Permissions") {
                Text("Hotkeys & Auto-paste require Accessibility permission")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            Text("VoiceCode").font(.title2.bold())
            Text("Voice-to-Text for Coding").foregroundColor(.secondary)
            Text("v1.0.0").font(.caption).foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TranscriptionState.shared)
}
