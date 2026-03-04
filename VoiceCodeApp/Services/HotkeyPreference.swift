import Foundation
import Carbon

enum HotkeyTriggerMode: String, Codable, CaseIterable {
    case holdToTalk = "holdToTalk"
    case toggle = "toggle"
    
    var displayName: String {
        switch self {
        case .holdToTalk: return "Press and Hold"
        case .toggle: return "Click to Toggle"
        }
    }
}

struct HotkeyPreference: Codable, Equatable {
    var keyCode: Int
    var modifiers: Int // Carbon modifiers like optionKey
    var triggerMode: HotkeyTriggerMode
    
    // Default: Option + Space, Hold to Talk
    static let `default` = HotkeyPreference(
        keyCode: kVK_Space,
        modifiers: optionKey,
        triggerMode: .holdToTalk
    )
    
    // Convert to human readable string, e.g. "⌥ Space"
    var displayString: String {
        var result = ""
        
        if modifiers & cmdKey != 0 { result += "⌘" }
        if modifiers & optionKey != 0 { result += "⌥" }
        if modifiers & controlKey != 0 { result += "⌃" }
        if modifiers & shiftKey != 0 { result += "⇧" }
        
        // Basic mapping for common keys
        switch keyCode {
        case kVK_Space: result += "Space"
        case kVK_Return: result += "Return"
        case kVK_Tab: result += "Tab"
        case kVK_Escape: result += "Esc"
        case 0...49:
            // Just return a placeholder for alphabet keys for now to simplify
            result += String(Character(UnicodeScalar(97 + keyCode) ?? "a")).uppercased()
        default: result += "Key"
        }
        
        return result.isEmpty ? "Not mapped" : result
    }
}
