import SwiftUI

struct TranscriptionSettingsView: View {
    @EnvironmentObject var state: TranscriptionState
    @AppStorage("playFeedbackSounds") private var playFeedbackSounds = true
    @AppStorage("preferredLanguage") private var preferredLanguage = "auto"

    private var modeDescription: String {
        switch state.transcriptionMode {
        case .local: return "Runs locally. First run slow, then fast. Works offline."
        case .openai: return "Uses OpenAI API (~$0.006/min). Fast and accurate."
        case .huggingface: return "Uses Hugging Face API. Free tier available."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcription Mode")
                        .font(.headline)

                    Picker("Mode", selection: $state.transcriptionMode) {
                        ForEach(TranscriptionMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 240, alignment: .leading)
                    .onChange(of: state.transcriptionMode) { _ in
                        NotificationCenter.default.post(name: Notification.Name("TranscriptionModeChanged"), object: nil)
                    }

                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                    if state.transcriptionMode == .local {
                        Divider()
                        
                        Text("Local Model Size")
                            .font(.subheadline.weight(.medium))

                        Picker("Model", selection: $state.modelSize) {
                            ForEach(WhisperModelSize.allCases) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 240, alignment: .leading)
                        .onChange(of: state.modelSize) { _ in
                            NotificationCenter.default.post(name: Notification.Name("ModelSizeChanged"), object: nil)
                        }

                        Text("Larger models are more accurate but slower to load.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Language & Behavior")
                        .font(.headline)

                    HStack {
                        Text("Preferred Language")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Preferred", selection: $preferredLanguage) {
                            Text("Auto-detect").tag("auto")
                            Text("English").tag("en")
                            Text("Chinese (中文)").tag("zh")
                            Text("Japanese").tag("ja")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 200, alignment: .trailing)
                    }

                    HStack {
                        Text("Play feedback sounds")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $playFeedbackSounds)
                            .toggleStyle(.switch)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
    }
}
