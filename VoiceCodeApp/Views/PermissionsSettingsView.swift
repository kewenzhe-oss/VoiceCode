import SwiftUI
import AppKit

struct PermissionsSettingsView: View {
    @ObservedObject private var permissionService = PermissionService.shared
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permissions Status")
                        .font(.headline)
                        
                    Text("VoiceCode needs the following permissions to support global hotkeys and voice recording.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    permissionRow(
                        title: "Microphone",
                        description: "Required to capture audio for transcription.",
                        isGranted: permissionService.hasMicrophonePermission,
                        requestAction: {
                            permissionService.requestMicrophonePermission { _ in }
                        },
                        settingsUrl: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                    )
                    
                    Divider()
                    
                    permissionRow(
                        title: "Accessibility",
                        description: "Required to detect global hotkeys and paste text.",
                        isGranted: permissionService.hasAccessibilityPermission,
                        requestAction: {
                            permissionService.requestAccessibilityPermission()
                        },
                        settingsUrl: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
        .onAppear {
            permissionService.checkPermissions()
            // Auto-refresh while looking at this tab
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                permissionService.checkPermissions()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @ViewBuilder
    private func permissionRow(title: String, description: String, isGranted: Bool, requestAction: @escaping () -> Void, settingsUrl: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            statusBadge(isGranted: isGranted)
            
            if !isGranted {
                Button("Request") {
                    requestAction()
                }
                .controlSize(.small)
            }
            
            Button("Settings") {
                if let url = URL(string: settingsUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
    
    private func statusBadge(isGranted: Bool) -> some View {
        Text(isGranted ? "Enabled" : "Disabled")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(isGranted ? Color.green.opacity(0.16) : Color.orange.opacity(0.16))
            )
            .foregroundColor(isGranted ? .green : .orange)
    }
}
