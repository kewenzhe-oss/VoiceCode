import Foundation

/// Optional AI post-processing service for improving transcription quality
/// Supports OpenAI GPT and Google Gemini APIs
class AIPostProcessor {
    
    // MARK: - Properties
    private var openAIKey: String?
    private var geminiKey: String?
    private var preferredProvider: AIProvider = .none
    
    // MARK: - Configuration
    
    enum AIProvider: String, CaseIterable, Identifiable {
        case none = "None (Local only)"
        case openai = "OpenAI GPT"
        case gemini = "Google Gemini"
        
        var id: String { rawValue }
    }
    
    struct Config: Codable {
        var provider: String
        var openAIKey: String?
        var geminiKey: String?
        var enableCodeFormatting: Bool
        var enableLanguageCorrection: Bool
    }
    
    // MARK: - Initialization
    
    init() {
        loadConfig()
    }
    
    func configure(provider: AIProvider, apiKey: String?) {
        self.preferredProvider = provider
        switch provider {
        case .openai:
            self.openAIKey = apiKey
        case .gemini:
            self.geminiKey = apiKey
        case .none:
            break
        }
        saveConfig()
    }
    
    // MARK: - Post-Processing
    
    /// Process transcription through AI for improvements
    /// - Parameters:
    ///   - text: Original transcription
    ///   - context: Optional coding context (e.g., current language/framework)
    /// - Returns: Improved transcription
    func process(_ text: String, context: CodingContext? = nil) async throws -> String {
        guard preferredProvider != .none else {
            return text
        }
        
        let prompt = buildPrompt(text: text, context: context)
        
        switch preferredProvider {
        case .openai:
            return try await callOpenAI(prompt: prompt)
        case .gemini:
            return try await callGemini(prompt: prompt)
        case .none:
            return text
        }
    }
    
    // MARK: - Private Methods
    
    private func buildPrompt(text: String, context: CodingContext?) -> String {
        var prompt = """
        You are a code transcription assistant. Your task is to:
        1. Fix any speech recognition errors in the transcription
        2. Handle mixed Chinese/English content appropriately
        3. Preserve programming terminology and syntax exactly
        4. Format code-related content appropriately
        
        Original transcription:
        "\(text)"
        
        """
        
        if let ctx = context {
            prompt += """
            
            Context:
            - Programming language: \(ctx.language ?? "unknown")
            - Framework: \(ctx.framework ?? "unknown")
            
            """
        }
        
        prompt += """
        
        Return only the corrected transcription, nothing else.
        """
        
        return prompt
    }
    
    private func callOpenAI(prompt: String) async throws -> String {
        guard let apiKey = openAIKey, !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.apiRequestFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? prompt
    }
    
    private func callGemini(prompt: String) async throws -> String {
        guard let apiKey = geminiKey, !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1000
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.apiRequestFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String
        
        return text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? prompt
    }
    
    // MARK: - Persistence
    
    private func loadConfig() {
        let configPath = getConfigPath()
        guard let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return
        }
        
        preferredProvider = AIProvider(rawValue: config.provider) ?? .none
        openAIKey = config.openAIKey
        geminiKey = config.geminiKey
    }
    
    private func saveConfig() {
        let config = Config(
            provider: preferredProvider.rawValue,
            openAIKey: openAIKey,
            geminiKey: geminiKey,
            enableCodeFormatting: true,
            enableLanguageCorrection: true
        )
        
        let configPath = getConfigPath()
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configPath)
        }
    }
    
    private func getConfigPath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("VoiceCode", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: configDir.path) {
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
        
        return configDir.appendingPathComponent("ai_config.json")
    }
}

// MARK: - Supporting Types

struct CodingContext {
    var language: String?
    var framework: String?
    var fileType: String?
}

enum AIError: LocalizedError {
    case missingAPIKey
    case apiRequestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured"
        case .apiRequestFailed:
            return "AI API request failed"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}
