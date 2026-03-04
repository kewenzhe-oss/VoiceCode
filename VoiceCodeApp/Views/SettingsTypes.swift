import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case transcription
    case apiKeys
    case hotkey
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transcription: return "Transcription"
        case .apiKeys: return "API Keys"
        case .hotkey: return "Hotkey"
        case .permissions: return "Permissions"
        case .about: return "About"
        }
    }

    var iconName: String {
        switch self {
        case .transcription: return "waveform"
        case .apiKeys: return "key"
        case .hotkey: return "keyboard"
        case .permissions: return "checkmark.shield"
        case .about: return "info.circle"
        }
    }
}
