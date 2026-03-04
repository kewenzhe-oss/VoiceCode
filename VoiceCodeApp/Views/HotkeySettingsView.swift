import SwiftUI

struct HotkeySettingsView: View {
    @State private var currentHotkey: HotkeyPreference = HotkeyManager.shared.currentPreference

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shortcut")
                        .font(.headline)

                    HStack(alignment: .center, spacing: 12) {
                        Text("Recording Key")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        Spacer()

                        HStack(spacing: 8) {
                            Text(currentHotkey.displayString)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                currentHotkey = HotkeyPreference.default
                                HotkeyManager.shared.currentPreference = currentHotkey
                                HotkeyManager.shared.savePreference()
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(Text("Reset shortcut"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .frame(width: 220, alignment: .trailing)
                    }
                    
                    Text("Full custom keybind recorder coming in next update.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .center, spacing: 12) {
                        Text("Trigger")
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Picker("Trigger", selection: $currentHotkey.triggerMode) {
                            ForEach(HotkeyTriggerMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 220, alignment: .trailing)
                        .onChange(of: currentHotkey.triggerMode) { _ in
                            HotkeyManager.shared.currentPreference = currentHotkey
                            HotkeyManager.shared.savePreference()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.headline)
                        
                    Text(currentHotkey.triggerMode == .holdToTalk 
                        ? "Hold the shortcut to record, and release it to transcribe."
                        : "Press the shortcut to start recording, press it again to transcribe."
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
        .onAppear {
            currentHotkey = HotkeyManager.shared.currentPreference
        }
    }
}
