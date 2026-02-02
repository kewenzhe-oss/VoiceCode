import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: TranscriptionState
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView
            
            Divider()
            
            // Status
            statusView
            
            // Last transcription
            if !state.lastTranscription.isEmpty {
                lastTranscriptionView
            }
            
            Divider()
            
            // History or empty state
            if state.transcriptionHistory.isEmpty {
                emptyStateView
            } else {
                historyView
            }
            
            Divider()
            
            // Footer actions
            footerView
        }
        .padding()
        .frame(width: 320, height: 400)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text("VoiceCode")
                .font(.headline)
            
            Spacer()
            
            Button(action: { 
                NotificationCenter.default.post(name: Notification.Name("OpenSettings"), object: nil)
            }) {
                Image(systemName: "gear")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var statusView: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .animation(.easeInOut(duration: 0.3), value: state.isRecording)
            
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Model status
            if !state.isModelReady {
                ProgressView()
                    .scaleEffect(0.7)
                Text("\(Int(state.modelDownloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        if state.isRecording {
            return .red
        } else if state.isTranscribing {
            return .orange
        } else if state.isModelReady {
            return .green
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if state.isRecording {
            return "Recording... (Release to transcribe)"
        } else if state.isTranscribing {
            return "Transcribing..."
        } else if !state.isModelReady {
            return "Loading model..."
        } else {
            return "Ready - Hold ⌥Space to record"
        }
    }
    
    private var lastTranscriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: copyLastTranscription) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
            
            Text(state.lastTranscription)
                .font(.system(.body, design: .rounded))
                .lineLimit(3)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No transcriptions yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Press ⌥Space and speak")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var historyView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("History")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(state.transcriptionHistory.prefix(10)) { item in
                        HistoryItemView(item: item)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    private var footerView: some View {
        HStack {
            Button("Clear History") {
                state.transcriptionHistory.removeAll()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(state.transcriptionHistory.isEmpty)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .font(.caption)
    }
    
    // MARK: - Actions
    
    private func copyLastTranscription() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.lastTranscription, forType: .string)
    }
}

// MARK: - History Item View
struct HistoryItemView: View {
    let item: TranscriptionItem
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(.callout, design: .rounded))
                    .lineLimit(2)
                
                Text(formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isHovered {
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.timestamp, relativeTo: Date())
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }
}

#Preview {
    ContentView()
        .environmentObject(TranscriptionState.shared)
}
