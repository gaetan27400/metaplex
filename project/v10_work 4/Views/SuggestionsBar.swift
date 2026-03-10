//
//  SuggestionsBar.swift
//  Journal de trading 2025
//
//  Barre de suggestions rapides pour démarrer une conversation
//

import SwiftUI

struct SuggestionsBar: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let suggestions: [ChatSuggestion]
    let onSuggestionTapped: (ChatSuggestion) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(suggestions) { suggestion in
                    SuggestionChip(
                        suggestion: suggestion,
                        onTap: { onSuggestionTapped(suggestion) }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
}

/// Chip de suggestion individuel
struct SuggestionChip: View {
    let suggestion: ChatSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            onTap()
        }) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.primary)
                
                Text(suggestion.title)
                    .font(AppTypography.labelMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SuggestionsBar(
        suggestions: ChatSuggestion.defaults,
        onSuggestionTapped: { suggestion in
            print("Tapped: \(suggestion.title)")
        }
    )
    .padding()
    .background(AppColors.background)
}


