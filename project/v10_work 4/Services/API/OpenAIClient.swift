//
//  OpenAIClient.swift
//  Journal de trading 2025
//

import Foundation

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double?
    let response_format: OpenAIResponseFormat?
}

struct OpenAIResponseFormat: Codable {
    let type: String
}

struct OpenAIChatChoice: Codable {
    let index: Int
    let message: OpenAIChatMessage
}

struct OpenAIChatResponse: Codable {
    let choices: [OpenAIChatChoice]
}

struct LLMAnalysis: Codable {
    let summary: String
    let insights: [String]
    let recommendations: [String]
}

final class OpenAIClient {
    private let apiKey: String
    private let baseURL: URL
    private let model: String
    
    init?(apiKey: String?, model: String = "gpt-4o", baseURL: String = "https://api.openai.com/v1") {
        guard let key = apiKey, !key.isEmpty else {
            print("❌ [OpenAI] Invalid API key in init")
            return nil
        }
        guard let url = URL(string: baseURL) else {
            print("❌ [OpenAI] Invalid base URL: \(baseURL)")
            return nil
        }
        self.apiKey = key
        self.baseURL = url
        self.model = model
        print("✅ [OpenAI] Client initialized with model: \(model), baseURL: \(baseURL)")
    }
    
    func analyze(tradingSummary: String, language: Localizable.Language = .french) async throws -> LLMAnalysis {
        print("🔄 [OpenAI] Starting analysis with model: \(model), language: \(language.rawValue)")
        print("📝 [OpenAI] Prompt length: \(tradingSummary.count) characters")
        
        let endpoint = baseURL.appendingPathComponent("/chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let systemContent: String = {
            switch language {
            case .french:
                return "Tu es un analyste technique expert en cryptomonnaie et marchés financiers. Tu dois répondre UNIQUEMENT en français et en JSON valide avec exactement 3 clés: 'summary' (string avec l'analyse structurée en plusieurs parties selon la demande de l'utilisateur), 'insights' (array de strings), 'recommendations' (array de strings). Pas de texte avant ou après le JSON. Le JSON doit être valide et commencer par '{' et finir par '}'."
            case .english:
                return "You are a technical analyst expert in cryptocurrency and financial markets. You must respond ONLY in English and in valid JSON with exactly 3 keys: 'summary' (string with structured analysis in several parts according to the user's request), 'insights' (array of strings), 'recommendations' (array of strings). No text before or after the JSON. The JSON must be valid and start with '{' and end with '}'."
            }
        }()
        
        let system = OpenAIChatMessage(role: "system", content: systemContent)
        let user = OpenAIChatMessage(role: "user", content: tradingSummary)
        let body = OpenAIChatRequest(model: model, messages: [system, user], temperature: 0.2, response_format: OpenAIResponseFormat(type: "json_object"))
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🌐 [OpenAI] Making request to: \(endpoint.absoluteString)")
        
        // Create a URLSession with timeout configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0 // 300 seconds timeout (5 minutes)
        config.timeoutIntervalForResource = 360.0 // 360 seconds for resource (6 minutes)
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            print("❌ [OpenAI] Invalid response type")
            throw NSError(domain: "OpenAIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        print("📊 [OpenAI] HTTP Status: \(http.statusCode)")
        
        guard (200..<300).contains(http.statusCode) else {
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ [OpenAI] HTTP Error Body: \(errorBody)")
            }
            throw NSError(domain: "OpenAIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI HTTP error: \(http.statusCode)"])
        }
        
        print("✅ [OpenAI] Response received, data length: \(data.count)")
        
        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 [OpenAI] Raw response (first 500 chars): \(String(responseString.prefix(500)))")
        }
        
        // Parse chat response first to extract the JSON content
        let chat = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content.data(using: .utf8) else {
            print("❌ [OpenAI] Empty content in chat response")
            throw NSError(domain: "OpenAIClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty content"])
        }
        
        if let contentString = String(data: content, encoding: .utf8) {
            print("📄 [OpenAI] Content extracted (first 500 chars): \(String(contentString.prefix(500)))")
        } else {
            print("❌ [OpenAI] Content cannot be converted to String")
        }
        
        // Decode the JSON content
        let decoder = JSONDecoder()
        do {
            let analysis = try decoder.decode(LLMAnalysis.self, from: content)
            print("✅ [OpenAI] Successfully decoded from chat content")
            return analysis
        } catch {
            print("❌ [OpenAI] Failed to decode LLMAnalysis: \(error)")
            print("❌ [OpenAI] Raw content: \(String(data: content, encoding: .utf8) ?? "invalid utf-8")")
            throw NSError(domain: "OpenAIClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "The data couldn't be read because it isn't in the correct format: \(error.localizedDescription)"])
        }
    }
    
    func chat(messages: [OpenAIChatMessage]) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("/chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body = OpenAIChatRequest(model: model, messages: messages, temperature: 0.2, response_format: nil)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "OpenAIClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "OpenAI chat error"])
        }
        let chat = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        return chat.choices.first?.message.content ?? ""
    }
    
    func analyzeMarket(prompt: String, language: Localizable.Language = .french) async throws -> String {
        print("🔄 [OpenAI] Starting market analysis with model: \(model), language: \(language.rawValue)")
        print("📝 [OpenAI] Prompt length: \(prompt.count) characters")
        
        let endpoint = baseURL.appendingPathComponent("/chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let systemContent: String = {
            switch language {
            case .french:
                return "Tu es un analyste technique expert en cryptomonnaies. Écris de manière élégante, professionnelle et esthétiquement soignée. Utilise des phrases courtes, un vocabulaire précis, une mise en page aérée avec des paragraphes courts (2-3 phrases max). Arrondis tous les chiffres à 1 décimale. Sois factuel, neutre et confiant. Structure ta réponse avec des séparateurs visuels et un usage judicieux des emojis. Réponds UNIQUEMENT en français."
            case .english:
                return "You are a technical analyst expert in cryptocurrencies. Write in an elegant, professional and aesthetically refined manner. Use short sentences, precise vocabulary, airy layout with short paragraphs (2-3 sentences max). Round all numbers to 1 decimal place. Be factual, neutral and confident. Structure your response with visual separators and judicious use of emojis. Respond ONLY in English."
            }
        }()
        
        let system = OpenAIChatMessage(role: "system", content: systemContent)
        let user = OpenAIChatMessage(role: "user", content: prompt)
        let body = OpenAIChatRequest(model: model, messages: [system, user], temperature: 0.2, response_format: nil)
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🌐 [OpenAI] Making request to: \(endpoint.absoluteString)")
        
        // Create a URLSession with timeout configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300.0
        config.timeoutIntervalForResource = 360.0
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        print("📊 [OpenAI] HTTP Status: \(http.statusCode)")
        
        guard (200..<300).contains(http.statusCode) else {
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ [OpenAI] HTTP Error Body: \(errorBody)")
            }
            throw NSError(domain: "OpenAIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI HTTP error: \(http.statusCode)"])
        }
        
        // Parse chat response and return content as plain text
        let chat = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content else {
            throw NSError(domain: "OpenAIClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty content"])
        }
        
        print("✅ [OpenAI] Market analysis received, length: \(content.count)")
        return content
    }
    
    func analyzeImage(imageData: Data, prompt: String) async throws -> String {
        print("🔄 [OpenAI] Starting image analysis")
        
        let endpoint = baseURL.appendingPathComponent("/chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Encoder l'image en base64
        let base64Image = imageData.base64EncodedString()
        
        // Construire le payload pour Vision API (GPT-4 Vision)
        let imageContent: [String: Any] = [
            "type": "image_url",
            "image_url": [
                "url": "data:image/jpeg;base64,\(base64Image)"
            ]
        ]
        
        let userMessage: [String: Any] = [
            "role": "user",
            "content": [
                [
                    "type": "text",
                    "text": prompt
                ],
                imageContent
            ]
        ]
        
        let systemMessage: [String: Any] = [
            "role": "system",
            "content": "Tu es un analyste technique expert en cryptomonnaies et graphiques de trading. Analyse les graphiques pour identifier les patterns techniques, les niveaux de support/résistance, et donne des recommandations de trading précises."
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [systemMessage, userMessage],
            "max_tokens": 1000,
            "temperature": 0.2
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "OpenAIClient", code: 4, userInfo: [NSLocalizedDescriptionKey: "OpenAI image analysis error"])
        }
        
        let chat = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        return chat.choices.first?.message.content ?? "Aucune analyse disponible."
    }
}


