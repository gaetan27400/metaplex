//
//  AIChatView.swift
//  Journal de trading 2025
//
//  Vue de chat IA — utilise désormais Firebase Cloud Functions.
//  Plus de clé API locale.
//

import SwiftUI

struct AIChatView: View {
    @ObservedObject var languageManager = LanguageManager.shared

    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isSending: Bool = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { msg in
                        HStack(alignment: .top) {
                            if msg.role == .assistant { Spacer(minLength: 0) }
                            Text(msg.content)
                                .padding(10)
                                .background(msg.role == .user ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: msg.role == .user ? .leading : .trailing)
                            if msg.role == .user { Spacer(minLength: 0) }
                        }
                    }
                }
                .padding()
            }

            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if input.isEmpty {
                        Text(t("writeMessage"))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $input)
                        .frame(minHeight: 38, maxHeight: 120)
                        .padding(6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                        .focused($inputFocused)
                        .disabled(isSending)
                }
                Button {
                    Task { await send() }
                } label: {
                    if isSending { ProgressView() } else { Image(systemName: "paperplane.fill") }
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle("Chat IA")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if messages.isEmpty {
                let welcomeMessage = languageManager.currentLanguage == .english
                    ? "Hello! Ask me questions about your trading performance and I'll help you analyze it."
                    : "Bonjour ! Pose-moi des questions sur tes performances et je t'aide à analyser."
                messages.append(ChatMessage(role: .assistant, content: welcomeMessage))
            }
            inputFocused = true
        }
        .onChange(of: languageManager.currentLanguage) { _ in
            // Reset chat with welcome message in the new language when language changes
            let welcomeMessage = languageManager.currentLanguage == .english
                ? "Hello! Ask me questions about your trading performance and I'll help you analyze it."
                : "Bonjour ! Pose-moi des questions sur tes performances et je t'aide à analyser."
            messages = [ChatMessage(role: .assistant, content: welcomeMessage)]
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(ChatMessage(role: .user, content: text))
        isSending = true
        defer { isSending = false }

        do {
            // Build system message enforcing the selected language
            let systemContent: String = {
                switch languageManager.currentLanguage {
                case .english:
                    return "You are an expert trading coach and analyst. You MUST respond ONLY in English. Help the user analyze their trading performance, emotions, and improve their discipline."
                case .french:
                    return "Tu es un coach de trading expert et analyste. Tu DOIS répondre UNIQUEMENT en français. Aide l'utilisateur à analyser ses performances de trading, ses émotions et à améliorer sa discipline."
                }
            }()
            let systemPayload = ChatMessagePayload(role: "system", content: systemContent)

            let conversationPayloads = messages.map {
                ChatMessagePayload(role: $0.role.rawValue, content: $0.content)
            }
            let allPayloads = [systemPayload] + conversationPayloads

            let reply = try await CloudFunctionService.shared.openAIChat(messages: allPayloads)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            let errorMsg = languageManager.currentLanguage == .english
                ? "AI Error: \(error.localizedDescription)"
                : "Erreur IA: \(error.localizedDescription)"
            messages.append(ChatMessage(role: .assistant, content: errorMsg))
        }
    }
}
