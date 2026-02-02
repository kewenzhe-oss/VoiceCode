import Foundation
import WhisperKit
import CoreML

/// Service for transcribing audio using WhisperKit
class TranscriptionService {
    
    // MARK: - Properties
    private var whisperKit: WhisperKit?
    private var isInitialized = false
    
    // User preferences
    var preferredLanguage: String? = nil  // nil = auto-detect
    var modelSize: WhisperModelSize = .large
    
    // MARK: - Initialization
    
    /// Initialize the WhisperKit model
    /// - Parameter progressCallback: Called with download/load progress (0.0 to 1.0)
    func initialize(progressCallback: @escaping (Double) -> Void) async throws {
        guard !isInitialized else { return }
        
        let modelName = modelSize.modelName
        
        do {
            // Initialize WhisperKit with the selected model
            whisperKit = try await WhisperKit(
                model: modelName,
                downloadBase: getModelDirectory(),
                computeOptions: getComputeOptions(),
                verbose: false
            )
            
            isInitialized = true
            progressCallback(1.0)
            
            print("✅ WhisperKit initialized with model: \(modelName)")
        } catch {
            print("❌ Failed to initialize WhisperKit: \(error)")
            throw TranscriptionError.modelLoadFailed(error)
        }
    }
    
    /// Transcribe audio file
    /// - Parameter audioURL: URL of the audio file to transcribe
    /// - Returns: Transcription text
    func transcribe(audioURL: URL) async throws -> String {
        guard let whisperKit = whisperKit, isInitialized else {
            throw TranscriptionError.notInitialized
        }
        
        do {
            // Configure transcription options
            var options = DecodingOptions()
            
            // For auto-detection, leave language as nil
            // This allows Whisper to detect Chinese, English, or mixed
            if preferredLanguage == "auto" || preferredLanguage == nil {
                options.language = nil  // Auto-detect
            } else {
                options.language = preferredLanguage
            }
            
            options.task = .transcribe
            // Disable prefill options to avoid English bias
            options.usePrefillPrompt = false
            options.usePrefillCache = false
            options.skipSpecialTokens = true
            options.withoutTimestamps = true
            
            // Perform transcription
            let results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )
            
            // Combine all result segments
            let transcription = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if transcription.isEmpty {
                throw TranscriptionError.emptyResult
            }
            
            // Detect language from results
            if let detectedLanguage = results.first?.language {
                print("🌐 Detected language: \(detectedLanguage)")
            }
            
            print("📝 Transcription: \(transcription.prefix(100))...")
            return transcription
            
        } catch let error as TranscriptionError {
            throw error
        } catch {
            print("❌ Transcription failed: \(error)")
            throw TranscriptionError.transcriptionFailed(error)
        }
    }
    
    /// Get detected language from last transcription
    func getDetectedLanguage() -> String? {
        // This would require storing the result from the last transcription
        return nil
    }
    
    // MARK: - Private Methods
    
    private func getModelDirectory() -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let modelDir = appSupport?.appendingPathComponent("VoiceCode/Models", isDirectory: true)
        
        if let dir = modelDir, !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return modelDir
    }
    
    private func getComputeOptions() -> ModelComputeOptions {
        // Use ANE (Apple Neural Engine) when available for best performance
        return ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine
        )
    }
    
    /// Change the model size (requires reinitialization)
    func changeModel(to size: WhisperModelSize) async throws {
        modelSize = size
        isInitialized = false
        whisperKit = nil
        
        try await initialize { _ in }
    }
    
    /// Check available disk space
    var hasEnoughDiskSpace: Bool {
        let requiredSpace: UInt64 = modelSize.approximateSize
        
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = attributes[.systemFreeSize] as? UInt64 {
            return freeSpace > requiredSpace
        }
        return true
    }
}

// MARK: - Model Sizes
enum WhisperModelSize: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large-v3"
    
    var id: String { rawValue }
    
    var modelName: String {
        return "openai_whisper-\(rawValue)"
    }
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (75MB) - Fastest"
        case .base: return "Base (145MB) - Fast"
        case .small: return "Small (483MB) - Good"
        case .medium: return "Medium (1.5GB) - Better"
        case .large: return "Large (3GB) - Best accuracy"
        }
    }
    
    var approximateSize: UInt64 {
        switch self {
        case .tiny: return 75_000_000
        case .base: return 145_000_000
        case .small: return 483_000_000
        case .medium: return 1_500_000_000
        case .large: return 3_000_000_000
        }
    }
}

// MARK: - Errors
enum TranscriptionError: LocalizedError {
    case notInitialized
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case emptyResult
    case audioFileNotFound
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Transcription service is not initialized."
        case .modelLoadFailed(let error):
            return "Failed to load Whisper model: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .emptyResult:
            return "No speech detected in the audio."
        case .audioFileNotFound:
            return "Audio file not found."
        }
    }
}
