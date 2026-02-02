import Foundation
import AVFoundation

/// Handles audio recording from the system microphone (macOS)
class AudioRecorder: NSObject {
    
    // MARK: - Properties
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    
    // Recording settings optimized for Whisper
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000.0,  // Whisper expects 16kHz
        AVNumberOfChannelsKey: 1,   // Mono
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupRecordingDirectory()
    }
    
    // MARK: - Public Methods
    
    /// Start recording audio
    /// - Throws: RecordingError if recording cannot be started
    func startRecording() throws {
        // Ensure directory exists (macOS might clean tmp)
        setupRecordingDirectory()
        
        // Generate unique filename
        let filename = "voicecode_\(Date().timeIntervalSince1970).wav"
        let recordingURL = getRecordingDirectory().appendingPathComponent(filename)
        currentRecordingURL = recordingURL
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = false // Disable metering to save resources (UI uses simulated waves)
            
            if audioRecorder?.prepareToRecord() == true {
                audioRecorder?.record()
                print("🎙️ Recording started: \(recordingURL.lastPathComponent)")
            } else {
                throw RecordingError.failedToStartRecording
            }
        } catch {
            print("❌ Failed to create audio recorder: \(error)")
            throw RecordingError.failedToStartRecording
        }
    }
    
    /// Stop recording and return the audio file URL
    /// - Returns: URL of the recorded audio file, or nil if no recording
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return nil
        }
        
        recorder.stop()
        print("🎙️ Recording stopped")
        
        let url = currentRecordingURL
        audioRecorder = nil
        
        // Verify file size (ignore empty/silent recordings < 1KB)
        if let attr = try? FileManager.default.attributesOfItem(atPath: url?.path ?? ""),
           let size = attr[.size] as? UInt64,
           size < 1024 {
            print("⚠️ Audio file too small (\(size) bytes) - Discarding")
            return nil
        }
        
        return url
    }
    
    /// Check if currently recording
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    /// Get audio level (for visualization)
    var audioLevel: Float {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return 0
        }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }
    
    // MARK: - Private Methods
    
    private func getRecordingDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("VoiceCode", isDirectory: true)
    }
    
    private func setupRecordingDirectory() {
        let directory = getRecordingDirectory()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    /// Clean up old recordings
    func cleanupOldRecordings() {
        let directory = getRecordingDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        for file in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("⚠️ Recording finished unsuccessfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("❌ Recording encode error: \(error)")
        }
    }
}

// MARK: - Errors
enum RecordingError: LocalizedError {
    case microphonePermissionDenied
    case failedToStartRecording
    case noRecordingInProgress
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required for recording."
        case .failedToStartRecording:
            return "Failed to start audio recording."
        case .noRecordingInProgress:
            return "No recording is currently in progress."
        }
    }
}
