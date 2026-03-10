//
//  AddTradeSelectionView.swift
//  Journal de trading 2025
//

import SwiftUI

struct AddTradeSelectionView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var showingManualEntry = false
    @State private var showingMEXCImport = false
    @State private var showingEmotionEntry = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header avec icône
                    VStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text(t("add"))
                                .font(AppTypography.titleLarge)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(t("choisissezVotreMthodeDajout"))
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, AppSpacing.xl)
                    
                    // === SECTION TRADES ===
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(t("trades"))
                            .font(AppTypography.labelLarge)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.lg)
                        
                        VStack(spacing: AppSpacing.md) {
                            // Saisie manuelle
                            OptionCard(
                                icon: "pencil.circle.fill",
                                iconColor: AppColors.primary,
                                title: t("newTrade"),
                                description: t("enregistrezVosTransactionsDeTrading"),
                                accentColor: AppColors.primary
                            ) {
                                showingManualEntry = true
                            }
                            
                            // Import depuis Exchange
                            OptionCard(
                                icon: "arrow.down.circle.fill",
                                iconColor: AppColors.success,
                                title: "Import Exchange",
                                description: t("mexc"),
                                accentColor: AppColors.success
                            ) {
                                showingMEXCImport = true
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    // === SECTION ÉMOTION ===
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(t("motionnel"))
                            .font(AppTypography.labelLarge)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.lg)
                        
                        OptionCard(
                            icon: "heart.circle.fill",
                            iconColor: .pink,
                            title: t("ajouterUneEmotion"),
                            description: t("enregistrezVotretatmotionnelActuel"),
                            accentColor: .pink
                        ) {
                            showingEmotionEntry = true
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    // Conseil
                    TipCard()
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                }
                .padding(.top, AppSpacing.md)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                    .font(AppTypography.labelLarge)
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            AddTradeView()
                .environmentObject(AppState.shared)
        }
        .sheet(isPresented: $showingMEXCImport) {
            MEXCImportView()
        }
        .sheet(isPresented: $showingEmotionEntry) {
            EmotionQuickEntryView()
                .environmentObject(AppState.shared)
        }
    }
}

// MARK: - Option Card Component
struct OptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            HStack(spacing: AppSpacing.md) {
                // Icône avec fond coloré
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                // Texte
                VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                    Text(title)
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(description)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .stroke(accentColor.opacity(0.2), lineWidth: 1.5)
                    )
            )
            .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tip Card Component
struct TipCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Icône
            ZStack {
                Circle()
                    .fill(AppColors.warning.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.warning)
            }
            
            // Contenu
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(t("conseils"))
                    .font(AppTypography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.warning)
                
                Text(t("settings"))
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.warning.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    AddTradeSelectionView()
}
