//
//  MessageBubble.swift
//  Journal de trading 2025
//
//  Composant pour afficher une bulle de message dans le chat
//

import SwiftUI

struct MessageBubble: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let message: ChatMessage
    let isStreaming: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            if message.role == .assistant {
                // Avatar IA à gauche
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppColors.primary.opacity(0.1))
                    )
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AppSpacing.xxs) {
                // Contenu du message
                Text(message.content.isEmpty && isStreaming ? "L'IA écrit..." : message.content)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(message.role == .user ? .white : AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .fill(message.role == .user ? AppColors.primary : AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.large)
                                    .stroke(
                                        message.role == .user ? Color.clear : AppColors.border.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Indicateur de streaming
                if isStreaming && message.role == .assistant {
                    TypingIndicator()
                        .padding(.leading, AppSpacing.md)
                }
                
                // Timestamp
                Text(message.date.formatted(date: .omitted, time: .shortened))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.xs)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .user {
                // Avatar utilisateur à droite
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppColors.cardBackground)
                    )
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }
}

/// Indicateur visuel "L'IA écrit..."
struct TypingIndicator: View {
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppColors.textTertiary)
                    .frame(width: 6, height: 6)
                    .opacity(0.3 + Foundation.sin(animationPhase + Double(index) * 0.5) * 0.7)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        MessageBubble(
            message: ChatMessage(
                role: .user,
                content: "Bonjour, j'aimerais analyser mon dernier trade."
            ),
            isStreaming: false
        )
        
        MessageBubble(
            message: ChatMessage(
                role: .assistant,
                content: "Bonjour ! Je serais ravi de t'aider à analyser ton dernier trade. Peux-tu me donner plus de détails ?"
            ),
            isStreaming: false
        )
        
        MessageBubble(
            message: ChatMessage(
                role: .assistant,
                content: ""
            ),
            isStreaming: true
        )
    }
    .padding()
    .background(AppColors.background)
}

