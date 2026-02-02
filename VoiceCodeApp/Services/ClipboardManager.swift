import Foundation
import AppKit
import ApplicationServices

/// Clipboard manager - adapted from Hex app's PasteboardClient
class ClipboardManager {
    
    private let pasteboard = NSPasteboard.general
    private var history: [ClipboardItem] = []
    private var previousApp: NSRunningApplication?
    
    // MARK: - Public
    
    func saveFrontmostApp() {
        guard let current = NSWorkspace.shared.frontmostApplication else { return }
        
        // Don't save ourself as the previous app
        if current.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("📌 Ignoring self (VoiceCode) in saveFrontmostApp")
            return
        }
        
        previousApp = current
        print("📌 Saved: \(previousApp?.localizedName ?? "nil")")
    }
    
    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        history.insert(ClipboardItem(text: text, timestamp: Date()), at: 0)
        if history.count > 20 { history = Array(history.prefix(20)) }
        print("📋 Copied: \(text.prefix(40))...")
    }
    
    @MainActor
    func copyAndPaste(_ text: String) {
        copy(text)
        
        Task { @MainActor in
            // 1. Hide VoiceCode to force OS to activate the previous app naturally
            // This works even if we failed to capture the specific previousApp
            NSApp.hide(nil)
            
            // Also try explicit activation if we have it (Double safety)
            if let app = previousApp, !app.isActive {
                print("🔄 Switching to: \(app.localizedName ?? "app")")
                if #available(macOS 14.0, *) {
                    app.activate()
                } else {
                    app.activate(options: .activateIgnoringOtherApps)
                }
            }
            
            // 2. Wait for focus (increased to 0.6s for reliability)
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            // 3. Paste
            print("📋 Pasting now...")
            await self.paste(text)
        }
    }
    
    func getHistory() -> [ClipboardItem] { history }
    func clearHistory() { history.removeAll() }
    
    // MARK: - Paste (from Hex)
    
    @MainActor
    private func paste(_ text: String) async {
        // Try CGEvent first
        if postCmdV() {
            print("✅ Paste via CGEvent")
            return
        }
        
        // Try menu click
        if pasteViaMenu() {
            print("✅ Paste via Menu")
            return
        }
        
        // Try AX insert
        if insertTextAtCursor(text) {
            print("✅ Paste via AX")
            return
        }
        
        print("⚠️ Paste failed - use ⌘V manually")
    }
    
    // MARK: - Method 1: CGEvent (from Hex)
    
    @MainActor
    private func postCmdV() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let cmdKey: CGKeyCode = 55
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        vUp?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        
        return true
    }
    
    // MARK: - Method 2: Menu Click (from Hex)
    
    private func pasteViaMenu() -> Bool {
        let script = """
        if application "System Events" is not running then
            tell application "System Events" to launch
            delay 0.1
        end if
        tell application "System Events"
            tell process (name of first application process whose frontmost is true)
                tell (menu item "Paste" of menu "Edit" of menu bar item "Edit" of menu bar 1)
                    if exists then
                        if enabled then
                            click it
                            return true
                        end if
                    end if
                end tell
            end tell
        end tell
        return false
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if error == nil { return result.booleanValue }
        }
        return false
    }
    
    // MARK: - Method 3: AX Insert (from Hex)
    
    private func insertTextAtCursor(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success else {
            return false
        }
        
        let focused = focusedRef as! AXUIElement
        let result = AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }
}

// MARK: - ClipboardItem

struct ClipboardItem: Identifiable, Codable {
    var id = UUID()
    let text: String
    let timestamp: Date
    
    var preview: String {
        text.count <= 50 ? text : String(text.prefix(50)) + "..."
    }
}
