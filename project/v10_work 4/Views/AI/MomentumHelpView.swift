//
//  MomentumHelpView.swift
//  Journal de trading 2025
//
//  Vue d'aide pour expliquer le Momentum
//

import SwiftUI

struct MomentumHelpView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // FIX: Hero section avec icône
                    VStack(spacing: AppSpacing.md) {
                        // Icône centrale
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                        }
                        
                        Text(t("momentum"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(t("price"))
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.lg)
                    
                    // FIX: Niveaux d'intensité - Cards visuelles
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(t("niveaux"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        VStack(spacing: AppSpacing.xs) {
                            intensityCard(icon: "tortoise.fill", title: "Faible", range: "< 0.3", color: .gray)
                            intensityCard(icon: "hare.fill", title: "Modéré", range: "0.3 - 0.7", color: .yellow)
                            intensityCard(icon: "flame.fill", title: "Fort", range: "0.7 - 1.2", color: .orange)
                            intensityCard(icon: "bolt.fill", title: "Très fort", range: "> 1.2", color: .red)
                        }
                    }
                    
                    // FIX: Utilisation - Points clés
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(t("saturday"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        VStack(spacing: AppSpacing.xs) {
                            keyPoint(icon: "arrow.up.right", text: "Croissant → Accélération", color: .green)
                            keyPoint(icon: "arrow.down.right", text: "Décroissant → Ralentissement", color: .red)
                        }
                    }
                    
                    // FIX: Conseil pro - Card d'alerte
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.warning)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("conseilPro"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.warning)
                            
                            Text(t("momentumTrsFortRisqueDeRetournement"))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(AppColors.warning.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
    }
    
    // FIX: Card d'intensité moderne
    private func intensityCard(icon: String, title: String, range: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Icône
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            
            // Texte
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(range)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
            }
            
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
        )
    }
    
    // FIX: Point clé simple
    private func keyPoint(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }
    
    private func helpRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(icon)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(description)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(color.opacity(0.1))
        )
    }
    
    private func usagePoint(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(.init(text)) // Markdown support
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

#Preview {
    MomentumHelpView()
}
