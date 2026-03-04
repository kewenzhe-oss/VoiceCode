import Foundation
import AppKit
import AVFoundation
import Combine

class PermissionService: ObservableObject {
    static let shared = PermissionService()
    
    @Published var hasMicrophonePermission = false
    @Published var hasAccessibilityPermission = false
    
    private init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        // Microphone
        hasMicrophonePermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        
        // Accessibility
        let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.hasMicrophonePermission = granted
                completion(granted)
            }
        }
    }
    
    func requestAccessibilityPermission() {
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
        hasAccessibilityPermission = trusted
        
        if !trusted {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
