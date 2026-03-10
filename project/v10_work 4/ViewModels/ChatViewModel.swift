//
//  ChatViewModel.swift
//  Journal de trading 2025
//
//  ViewModel pour gérer l'état et la logique du chat Coach IA
//  Plus de dépendance à une clé API — utilise Firebase Cloud Functions.
//

import Foundation
import SwiftUI
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// ViewModel pour le chat Coach IA
@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [ChatMessage] = []
    @Published var streamingMessage: String = ""
    @Published var isStreaming: Bool = false
    @Published var error: AIChatError?
    @Published var inputText: String = ""
    @Published var isServiceReady: Bool = false

    // MARK: - Private Properties

    private let chatService = AIChatService()
    private let maxContextMessages = 20

    // MARK: - Initialization

    init() {
        checkServiceReady()
    }

    /// Vérifie si le service est prêt (utilisateur authentifié Firebase)
    func checkServiceReady() {
        #if canImport(FirebaseAuth)
        if FirebaseAvailability.isConfigured {
            isServiceReady = Auth.auth().currentUser != nil
        } else {
            // Mode local / dev : toujours prêt
            isServiceReady = true
        }
        #else
        isServiceReady = true
        #endif

        if isServiceReady {
            initializeConversation()
        }
    }

    /// Initialise la conversation avec le message système
    private func initializeConversation() {
        if messages.isEmpty {
            let language = LanguageManager.shared.currentLanguage
            messages.append(ChatMessage.systemPrompt(language: language))
        }
    }

    // MARK: - Public Methods

    /// Envoie un message utilisateur et reçoit la réponse de l'IA
    func sendMessage(_ text: String? = nil) async {
        let messageText = text ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !messageText.isEmpty, isServiceReady else {
            if !isServiceReady {
                error = .invalidAPIKey
            }
            return
        }

        // Réinitialiser l'état
        error = nil
        inputText = ""
        streamingMessage = ""
        isStreaming = true

        // Ajouter le message utilisateur
        let userMessage = ChatMessage(role: .user, content: messageText)
        messages.append(userMessage)

        // Préparer les messages pour l'API
        let contextMessages = getContextMessages()

        // Créer un message assistant vide
        let assistantMessageId = UUID()
        let assistantMessage = ChatMessage(
            id: assistantMessageId,
            role: .assistant,
            content: ""
        )
        messages.append(assistantMessage)

        do {
            let fullResponse = try await chatService.sendMessage(
                messages: contextMessages + [userMessage],
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.streamingMessage.append(token)
                        if let index = self?.messages.lastIndex(where: { $0.id == assistantMessageId }) {
                            self?.messages[index] = ChatMessage(
                                id: assistantMessageId,
                                role: .assistant,
                                content: self?.streamingMessage ?? ""
                            )
                        }
                    }
                }
            )

            // Post-vérification et correction automatique
            let correctedResponse = try await chatService.postVerifyAndCorrect(fullResponse)

            // Finaliser le message avec la réponse corrigée
            if let index = messages.lastIndex(where: { $0.id == assistantMessageId }) {
                messages[index] = ChatMessage(
                    id: assistantMessageId,
                    role: .assistant,
                    content: correctedResponse
                )
            }

            streamingMessage = ""
            isStreaming = false

        } catch let error as AIChatError {
            self.error = error
            isStreaming = false
            streamingMessage = ""
            if let index = messages.lastIndex(where: { $0.id == assistantMessageId }) {
                messages.remove(at: index)
            }
        } catch {
            self.error = .unknown(error.localizedDescription)
            isStreaming = false
            streamingMessage = ""
            if let index = messages.lastIndex(where: { $0.id == assistantMessageId }) {
                messages.remove(at: index)
            }
        }
    }

    /// Réinitialise la conversation
    func clearConversation() {
        messages.removeAll()
        streamingMessage = ""
        error = nil
        initializeConversation()
    }

    /// Retourne les messages de contexte
    private func getContextMessages() -> [ChatMessage] {
        let language = LanguageManager.shared.currentLanguage
        var context: [ChatMessage] = [ChatMessage.systemPrompt(language: language)]

        let userMessages = messages.filter { $0.role != .system }
        let recentMessages = Array(userMessages.suffix(maxContextMessages))
        context.append(contentsOf: recentMessages)

        return context
    }

    /// Ajoute des données structurées au contexte
    func addContextData(_ data: String) {
        let contextMessage = ChatMessage(
            role: .system,
            content: "Contexte additionnel: \(data)"
        )
        if let systemIndex = messages.firstIndex(where: { $0.role == .system }) {
            messages.insert(contextMessage, at: systemIndex + 1)
        }
    }
}
