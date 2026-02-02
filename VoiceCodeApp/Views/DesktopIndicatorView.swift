import SwiftUI
import Combine

struct DesktopIndicatorView: View {
    @ObservedObject var state: TranscriptionState
    
    // Animation state
    @State private var phase: CGFloat = 0
    @State private var waveHeight: CGFloat = 0.5
    
    var body: some View {
        HStack(spacing: 12) {
            // Visual Indicator
            if state.isRecording {
                // Recording Icon (Pulse)
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1 + waveHeight * 0.3)
                    .opacity(0.8 + waveHeight * 0.2)
                
                // Text
                Text("Listening...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                // Waveform simulation
                HStack(spacing: 2) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 2, height: 8 + (CGFloat(i) * 3 * waveHeight))
                            .animation(.easeInOut(duration: 0.1).delay(Double(i) * 0.05), value: waveHeight)
                    }
                }
            } else if state.isTranscribing {
                // Processing Animation
                ProgressView()
                    .controlSize(.small)
                    .colorInvert()
                    .brightness(1)
                
                Text("Turning thought into text...")
                    .font(.system(size: 15, weight: .medium, design: .rounded)) // Larger font
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 24) // More padding
        .padding(.vertical, 14)
        .background {
            Capsule()
                .fill(.regularMaterial) // Slightly thicker approach for better readability over Dock
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 5)
        }
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1) // Apple-style border
        )
        // Removed Activity Glow ("fur") as per user request
        .opacity((state.isRecording || state.isTranscribing) ? 1 : 0)
        .scaleEffect((state.isRecording || state.isTranscribing) ? 1 : 0.8)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.isRecording)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.isTranscribing)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if state.isRecording {
                waveHeight = CGFloat.random(in: 0.2...1.0)
            } else {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    phase -= 1
                }
            }
        }
    }
}
