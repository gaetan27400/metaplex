//
//  AIChatService.swift
//  Journal de trading 2025
//
//  Service pour gérer les conversations avec le Coach IA
//  Passe désormais par Firebase Cloud Functions — plus de clé API côté iOS.
//

import Foundation

/// Erreurs possibles lors de l'appel à l'API
enum AIChatError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimitExceeded
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Service IA non disponible. Vérifiez votre connexion."
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .rateLimitExceeded:
            return "Limite de requêtes atteinte. Réessayez plus tard."
        case .timeout:
            return "Délai d'attente dépassé"
        case .unknown(let message):
            return message
        }
    }
}

/// Service de chat IA via Firebase Cloud Functions
@MainActor
final class AIChatService {
    
    /// Initialise le service — plus besoin de clé API
    init() {}

    /// Envoie un message et reçoit une réponse (sans streaming — V1 Cloud Functions)
    /// - Parameters:
    ///   - messages: Liste des messages de la conversation
    ///   - onToken: Callback appelé avec la réponse complète (compatibilité avec l'ancien streaming)
    /// - Returns: La réponse complète
    func sendMessage(
        messages: [ChatMessage],
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        let payloads = messages.map { msg in
            ChatMessagePayload(role: msg.role.rawValue, content: msg.content)
        }

        do {
            let response = try await CloudFunctionService.shared.openAIChat(messages: payloads)
            // Simuler le streaming en envoyant la réponse complète d'un coup
            onToken(response)
            return response
        } catch {
            throw mapError(error)
        }
    }

    /// Envoie un message sans streaming (fallback)
    func sendMessageSync(messages: [ChatMessage]) async throws -> String {
        let payloads = messages.map { msg in
            ChatMessagePayload(role: msg.role.rawValue, content: msg.content)
        }

        do {
            return try await CloudFunctionService.shared.openAIChat(messages: payloads)
        } catch {
            throw mapError(error)
        }
    }

    /// Post-vérifie et corrige une réponse pour éliminer les erreurs de grammaire
    func postVerifyAndCorrect(_ response: String) async throws -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 10 else { return response }

        let verificationPrompt = """
        CORRECTION GRAMMATICALE STRICTE - Expert en français.
        
        MISSION : Corriger TOUTES les erreurs dans le texte suivant.
        
        ERREURS FRÉQUENTES À CORRIGER :
        ❌ "points considérer" → ✅ "points À considérer"
        ❌ "points important" → ✅ "points importants"
        ❌ "trading russe" → ✅ "trading réussi"
        
        INSTRUCTIONS :
        1. Cherche TOUTES les prépositions manquantes
        2. Vérifie TOUS les accords
        3. Corrige TOUTE terminologie incorrecte
        4. Garde le sens, la structure et la mise en forme identiques
        5. Si aucune erreur, retourne le texte tel quel
        
        Retourne UNIQUEMENT le texte corrigé, sans commentaires.
        
        TEXTE :
        \(trimmed)
        """

        let payloads = [
            ChatMessagePayload(
                role: "system",
                content: "Tu es un correcteur expert en français professionnel. Tu corriges TOUTES les erreurs grammaticales, orthographiques et terminologiques. Tu retournes UNIQUEMENT le texte corrigé, sans commentaires."
            ),
            ChatMessagePayload(role: "user", content: verificationPrompt)
        ]

        do {
            let corrected = try await CloudFunctionService.shared.openAIChat(
                messages: payloads,
                temperature: 0.1
            )
            let correctedTrimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)

            if correctedTrimmed.count >= trimmed.count * 7 / 10 && correctedTrimmed.count <= trimmed.count * 2 {
                print("✅ [AIChatService] Réponse corrigée: \(trimmed.count) → \(correctedTrimmed.count) caractères")
                return correctedTrimmed
            } else {
                print("⚠️ [AIChatService] Correction trop différente, garde l'original")
                return response
            }
        } catch {
            print("⚠️ [AIChatService] Erreur lors de la post-vérification: \(error)")
            return response
        }
    }

    // MARK: - Private

    private func mapError(_ error: Error) -> AIChatError {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("unauthenticated") {
            return .invalidAPIKey
        } else if desc.contains("rate") || desc.contains("429") {
            return .rateLimitExceeded
        } else if desc.contains("timeout") {
            return .timeout
        } else {
            return .networkError(error)
        }
    }
}
