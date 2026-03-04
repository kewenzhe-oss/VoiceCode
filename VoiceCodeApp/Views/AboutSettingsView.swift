import SwiftUI
import AppKit

struct AboutSettingsView: View {
    private var appVersionText: String? {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let shortVersion, let buildVersion, !buildVersion.isEmpty {
            return "\\(shortVersion) (\\(buildVersion))"
        }
        if let shortVersion { return shortVersion }
        if let buildVersion { return buildVersion }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VoiceCode")
                                .font(.headline)
                            Text("Voice-to-Text for Coding")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let version = appVersionText {
                                HStack(spacing: 4) {
                                    Text("Version")
                                    Text(version)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project")
                        .font(.headline)
                    Text("Powered by WhisperKit and OpenAI/HuggingFace APIs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
    }
}
