import Cocoa
import Carbon

class HotKeyService {
    static let shared = HotKeyService()
    
    private var eventHotKeyRef: EventHotKeyRef?
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    
    // Track state to avoid repeated triggers
    private var isPressed = false
    
    private init() {}
    
    func registerHotkey() {
        unregisterHotkey()
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(1954115685) // 'tcod' -> VoiceCode
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Install Release handler as well
        var releaseEventType = EventTypeSpec()
        releaseEventType.eventClass = OSType(kEventClassKeyboard)
        releaseEventType.eventKind = OSType(kEventHotKeyReleased)
        
        // Install Event Handler
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let event = theEvent else { return noErr }
            
            var kind: UInt32 = 0
            kind = GetEventKind(event)
            
            if kind == kEventHotKeyPressed {
                HotKeyService.shared.handleKeyDown()
            } else if kind == kEventHotKeyReleased {
                HotKeyService.shared.handleKeyUp()
            }
            
            return noErr
        }, 2, [eventType, releaseEventType], nil, nil)
        
        // Register Option + Space (Keycode 49, Modifier optionKey)
        // cmdKey=256, shiftKey=512, optionKey=2048, controlKey=4096
        let modifiers = UInt32(optionKey)
        let keycode = UInt32(kVK_Space)
        
        let status = RegisterEventHotKey(keycode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &eventHotKeyRef)
        
        if status == noErr {
            print("✅ Carbon HotKey Registered: Option + Space")
        } else {
            print("❌ Failed to register Carbon HotKey: \(status)")
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
            print("🎹 Hotkey DOWN")
            DispatchQueue.main.async {
                self.onKeyDown?()
            }
        }
    }
    
    private func handleKeyUp() {
        if isPressed {
            isPressed = false
            print("🎹 Hotkey UP")
            DispatchQueue.main.async {
                self.onKeyUp?()
            }
        }
    }
}
