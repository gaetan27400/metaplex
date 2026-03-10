//
//  BadgeUnlockedView.swift
//  Journal de trading 2025
//
//  Vue de notification pour les badges débloqués
//

import SwiftUI

struct BadgeUnlockedView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let badge: Badge
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Overlay sombre
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Carte du badge
            VStack(spacing: AppSpacing.lg) {
                // Icône du badge avec animation
                ZStack {
                    Circle()
                        .fill(badgeRarityGradient(badge.rarity).opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: badge.icon)
                        .font(.system(size: 60))
                        .foregroundColor(badgeRarityColor(badge.rarity))
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // Titre
                VStack(spacing: AppSpacing.sm) {
                    Text(t("badgeDbloqu"))
                        .font(AppTypography.headlineMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(badge.name)
                        .font(AppTypography.titleLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(badgeRarityColor(badge.rarity))
                    
                    Text(badge.description)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                    
                    // Rareté
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: rarityIcon(badge.rarity))
                            .font(.system(size: 12))
                        Text(badge.rarity.rawValue.capitalized)
                            .font(AppTypography.captionMedium)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(badgeRarityColor(badge.rarity))
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        Capsule()
                            .fill(badgeRarityColor(badge.rarity).opacity(0.2))
                    )
                }
                
                // Bouton de fermeture
                Button(action: dismiss) {
                    Text(t("continuer"))
                        .font(AppTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppGradients.primary)
                        )
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(AppSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xlarge)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xlarge)
                            .stroke(badgeRarityColor(badge.rarity).opacity(0.3), lineWidth: 2)
                    )
            )
            .shadow(color: badgeRarityColor(badge.rarity).opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, AppSpacing.xl)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Feedback haptique
            HapticFeedback.success()
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 0.8
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func badgeRarityColor(_ rarity: BadgeRarity) -> Color {
        switch rarity {
        case .common: return AppColors.textSecondary
        case .rare: return AppColors.primary
        case .epic: return AppColors.accent
        case .legendary: return AppColors.warning
        }
    }
    
    private func badgeRarityGradient(_ rarity: BadgeRarity) -> LinearGradient {
        switch rarity {
        case .common:
            return LinearGradient(colors: [AppColors.textSecondary, AppColors.textSecondary.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rare:
            return LinearGradient(colors: [AppColors.primary, AppColors.primary.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .epic:
            return LinearGradient(colors: [AppColors.accent, AppColors.accent.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legendary:
            return LinearGradient(colors: [AppColors.warning, AppColors.warning.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func rarityIcon(_ rarity: BadgeRarity) -> String {
        switch rarity {
        case .common: return "circle.fill"
        case .rare: return "star.fill"
        case .epic: return "star.circle.fill"
        case .legendary: return "crown.fill"
        }
    }
}

#Preview {
    BadgeUnlockedView(
        badge: Badge(
            id: "test",
            name: "Premier Pas",
            description: "Effectuer votre premier trade",
            icon: "1.circle.fill",
            rarity: .common,
            unlockedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ),
        onDismiss: {}
    )
}


