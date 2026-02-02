import Foundation

/// Transcription mode options
enum TranscriptionMode: String, CaseIterable, Identifiable {
    case local = "local"
    case openai = "openai"
    case huggingface = "huggingface"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .local: return "Local (WhisperKit)"
        case .openai: return "OpenAI API"
        case .huggingface: return "Hugging Face API"
        }
    }
    
    var description: String {
        switch self {
        case .local: return "Offline, first run slow, then fast"
        case .openai: return "Fast, accurate, $0.006/min"
        case .huggingface: return "Free tier available"
        }
    }
}

/// Cloud-based transcription service supporting multiple providers
class CloudTranscriptionService {
    
    // MARK: - Properties (Computed from UserDefaults)
    
    private var openaiAPIKey: String? {
        get { UserDefaults.standard.string(forKey: "openai_api_key") }
    }
    
    private var huggingfaceAPIKey: String? {
        get { UserDefaults.standard.string(forKey: "huggingface_api_key") }
    }
    
    private let openaiURL = "https://api.openai.com/v1/audio/transcriptions"
    private let huggingfaceURL = "https://api-inference.huggingface.co/models/openai/whisper-large-v3"
    
    var isOpenAIConfigured: Bool {
        guard let key = openaiAPIKey else { return false }
        return !key.isEmpty
    }
    
    var isHuggingFaceConfigured: Bool {
        guard let key = huggingfaceAPIKey else { return false }
        return !key.isEmpty
    }
    
    // MARK: - Initialization
    
    init() {
        // No local loading needed, computed properties handle it
    }
    
    // MARK: - API Key Management
    
    func setOpenAIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
        // Force sync just in case
        UserDefaults.standard.synchronize()
    }
    
    func setHuggingFaceKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "huggingface_api_key")
        UserDefaults.standard.synchronize()
    }
    
    func getMaskedOpenAIKey() -> String? {
        guard let key = openaiAPIKey, key.count > 8 else { return nil }
        return "\(key.prefix(4))...\(key.suffix(4))"
    }
    
    func getMaskedHuggingFaceKey() -> String? {
        guard let key = huggingfaceAPIKey, key.count > 8 else { return nil }
        return "\(key.prefix(4))...\(key.suffix(4))"
    }
    
    // No loadAPIKeys needed
    
    func clearKeys() {
        UserDefaults.standard.removeObject(forKey: "openai_api_key")
        UserDefaults.standard.removeObject(forKey: "huggingface_api_key")
    }
    
    // MARK: - Transcription
    
    /// Transcribe using the specified provider
    func transcribe(audioURL: URL, provider: TranscriptionMode, language: String? = nil) async throws -> String {
        switch provider {
        case .openai:
            return try await transcribeWithOpenAI(audioURL: audioURL, language: language)
        case .huggingface:
            return try await transcribeWithHuggingFace(audioURL: audioURL)
        case .local:
            throw CloudTranscriptionError.invalidProvider
        }
    }
    
    // MARK: - OpenAI Whisper API
    
    private func transcribeWithOpenAI(audioURL: URL, language: String?) async throws -> String {
        guard let apiKey = openaiAPIKey, !apiKey.isEmpty else {
            throw CloudTranscriptionError.noAPIKey("OpenAI")
        }
        
        let audioData = try Data(contentsOf: audioURL)
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: openaiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        var body = Data()
        
        // Model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Language (optional)
        if let lang = language, lang != "auto" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(lang)\r\n".data(using: .utf8)!)
        }
        
        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw CloudTranscriptionError.apiError(message)
            }
            throw CloudTranscriptionError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw CloudTranscriptionError.parseError
        }
        
        print("☁️ OpenAI transcription complete")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Hugging Face Inference API
    
    private func transcribeWithHuggingFace(audioURL: URL) async throws -> String {
        guard let apiKey = huggingfaceAPIKey, !apiKey.isEmpty else {
            throw CloudTranscriptionError.noAPIKey("Hugging Face")
        }
        
        let audioData = try Data(contentsOf: audioURL)
        
        var request = URLRequest(url: URL(string: huggingfaceURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // HF can be slower
        request.httpBody = audioData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // Check if model is loading
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                if error.contains("loading") {
                    throw CloudTranscriptionError.modelLoading
                }
                throw CloudTranscriptionError.apiError(error)
            }
            throw CloudTranscriptionError.httpError(httpResponse.statusCode)
        }
        
        // HF returns { "text": "..." }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw CloudTranscriptionError.parseError
        }
        
        print("☁️ Hugging Face transcription complete")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors
enum CloudTranscriptionError: LocalizedError {
    case noAPIKey(String)
    case audioFileError(Error)
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError
    case invalidProvider
    case modelLoading
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "\(provider) API key not configured"
        case .audioFileError(let error):
            return "Failed to read audio: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .parseError:
            return "Failed to parse response"
        case .invalidProvider:
            return "Invalid transcription provider"
        case .modelLoading:
            return "Model is loading, please try again"
        }
    }
}
