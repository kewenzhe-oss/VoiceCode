import SwiftUI

struct APIKeysSettingsView: View {
    @State private var openaiKey = ""
    @State private var huggingfaceKey = ""
    private let cloudService = CloudTranscriptionService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("OpenAI API")
                        .font(.headline)

                    SecureField("API Key (sk-...)", text: $openaiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)

                    HStack {
                        Button("Save") {
                            cloudService.setOpenAIKey(openaiKey)
                        }
                        .controlSize(.small)
                        .disabled(openaiKey.isEmpty)

                        if cloudService.isOpenAIConfigured {
                            Text("✓ Saved")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Link("Get Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hugging Face API")
                        .font(.headline)

                    SecureField("API Key (hf_...)", text: $huggingfaceKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)

                    HStack {
                        Button("Save") {
                            cloudService.setHuggingFaceKey(huggingfaceKey)
                        }
                        .controlSize(.small)
                        .disabled(huggingfaceKey.isEmpty)

                        if cloudService.isHuggingFaceConfigured {
                            Text("✓ Saved")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Link("Get Key", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
        .onAppear {
            openaiKey = cloudService.getMaskedOpenAIKey() ?? ""
            huggingfaceKey = cloudService.getMaskedHuggingFaceKey() ?? ""
        }
    }
}
