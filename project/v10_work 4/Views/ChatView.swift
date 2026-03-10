//
//  ChatView.swift
//  Journal de trading 2025
//
//  Vue principale du chat Coach IA
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
            // Liste des messages
            messagesListView
            
            // Barre de saisie
            inputBarView
            }
        }
        .navigationTitle("Coach IA")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticFeedback.selection()
                    viewModel.clearConversation()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .alert("Erreur", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .onAppear {
            viewModel.checkServiceReady()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20))
                .foregroundColor(AppColors.primary)
            
            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                Text(t("ai"))
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(viewModel.isServiceReady ? "En ligne" : "Connectez-vous pour utiliser l'IA")
                    .font(AppTypography.captionSmall)
                    .foregroundColor(viewModel.isServiceReady ? AppColors.success : AppColors.warning)
            }
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cardBackground)
    }
    
    // MARK: - Messages List
    
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.xs) {
                    // Afficher uniquement les messages non-système
                    let userMessages = viewModel.messages.filter { $0.role != .system }
                    
                    if userMessages.isEmpty {
                        // État vide optimisé
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xl)
                    } else {
                        ForEach(userMessages) { message in
                            MessageBubble(
                                message: message,
                                isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, 100) // Padding pour la barre de navigation en bas
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isStreaming) { oldValue, newValue in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "message.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary.opacity(0.4))
            
            Text(t("saturday"))
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)
            
            Text(t("trades"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBarView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            HStack(spacing: AppSpacing.sm) {
                // Champ de texte
                TextField("Tapez votre message...", text: $viewModel.inputText, axis: .vertical)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .fill(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.large)
                                    .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .disabled(viewModel.isStreaming || !viewModel.isServiceReady)
                    .onSubmit {
                        if !viewModel.inputText.isEmpty {
                            Task {
                                await viewModel.sendMessage()
                            }
                        }
                    }
                
                // Bouton envoyer
                Button(action: {
                    HapticFeedback.selection()
                    Task {
                        await viewModel.sendMessage()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            canSendMessage ? AppColors.primary : AppColors.textTertiary
                        )
                }
                .disabled(!canSendMessage)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.sm)
            .background(AppColors.background)
        }
    }
    
    private var canSendMessage: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.isStreaming &&
        viewModel.isServiceReady
    }
    
    // MARK: - Helpers
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.filter({ $0.role != .system }).last {
            withAnimation(AppAnimations.standard) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
