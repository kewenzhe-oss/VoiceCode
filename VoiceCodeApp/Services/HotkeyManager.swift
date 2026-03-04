import Cocoa
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventHotKeyRef: EventHotKeyRef?
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    
    private var isPressed = false
    
    var currentPreference: HotkeyPreference = .default {
        didSet {
            // Re-register if changed
            registerHotkey()
        }
    }
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: "hotkeyPreference"),
           let pref = try? JSONDecoder().decode(HotkeyPreference.self, from: data) {
            self.currentPreference = pref
        }
    }
    
    func savePreference() {
        if let data = try? JSONEncoder().encode(currentPreference) {
            UserDefaults.standard.set(data, forKey: "hotkeyPreference")
        }
    }
    
    func registerHotkey() {
        unregisterHotkey()
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(1954115685) // 'tcod' -> VoiceCode
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        var releaseEventType = EventTypeSpec()
        releaseEventType.eventClass = OSType(kEventClassKeyboard)
        releaseEventType.eventKind = OSType(kEventHotKeyReleased)
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let event = theEvent else { return noErr }
            
            let kind = GetEventKind(event)
            
            if kind == kEventHotKeyPressed {
                HotkeyManager.shared.handleKeyDown()
            } else if kind == kEventHotKeyReleased {
                HotkeyManager.shared.handleKeyUp()
            }
            
            return noErr
        }, 2, [eventType, releaseEventType], nil, nil)
        
        let status = RegisterEventHotKey(UInt32(currentPreference.keyCode), UInt32(currentPreference.modifiers), hotKeyID, GetApplicationEventTarget(), 0, &eventHotKeyRef)
        
        if status == noErr {
            print("✅ Carbon HotKey Registered: \\(currentPreference.displayString)")
        } else {
            print("❌ Failed to register Carbon HotKey: \\(status)")
        }
    }
    
    func unregisterHotkey() {
        if let ref = eventHotKeyRef {
            UnregisterEventHotKey(ref)
            eventHotKeyRef = nil
        }
    }
    
    private func handleKeyDown() {
        if !isPressed {
            isPressed = true
            
            if currentPreference.triggerMode == .holdToTalk {
                DispatchQueue.main.async {
                    self.onKeyDown?()
                }
            } else {
                // Toggle mode: toggle state on key down
                DispatchQueue.main.async {
                    if TranscriptionState.shared.isRecording {
                        self.onKeyUp?() 
                    } else {
                        self.onKeyDown?()
                    }
                }
            }
        }
    }
    
    private func handleKeyUp() {
        if isPressed {
            isPressed = false
            
            if currentPreference.triggerMode == .holdToTalk {
                DispatchQueue.main.async {
                    self.onKeyUp?()
                }
            }
            // If toggle mode, we do nothing on key up.
        }
    }
}
