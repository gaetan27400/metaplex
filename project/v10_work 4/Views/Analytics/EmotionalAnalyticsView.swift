//
//  EmotionalAnalyticsView.swift
//  Journal de trading 2025
//
//  Vue conteneur pour les analyses émotionnelles
//  Intègre les trois graphiques corrigés
//

import SwiftUI

// MARK: - Emotional Analytics Tab

enum EmotionalAnalyticsTab: String, CaseIterable, Identifiable {
    case charge = "Charge"
    case correlation = "Corrélation"
    case context = "Contexte P&L"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .charge: return "waveform.path.ecg"
        case .correlation: return "arrow.left.arrow.right"
        case .context: return "chart.bar.xaxis"
        }
    }
    
    var description: String {
        switch self {
        case .charge:
            return "Évolution de votre charge émotionnelle dans le temps"
        case .correlation:
            return "Lien entre vos émotions et vos performances"
        case .context:
            return "P&L quotidien avec contexte émotionnel"
        }
    }
}

/// Vue principale des analyses émotionnelles (Version Standalone)
struct StandaloneEmotionalAnalyticsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: EmotionalAnalyticsTab = .charge
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    headerSection
                    tabSelector
                    
                    // Graphique sélectionné
                    Group {
                        switch selectedTab {
                        case .charge:
                            StandaloneEmotionalChartView()
                        case .correlation:
                            StandaloneCorrelationChartView()
                        case .context:
                            StandalonePnlContextChartView()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    
                    // Insights rapides
                    insightsSection
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("emotionalAnalyses"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("analyse"))
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(t("trades"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(0.08),
                            AppColors.accent.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("type"))
                .font(AppTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(EmotionalAnalyticsTab.allCases) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: {
                                HapticFeedback.selection()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                            }
                        )
                    }
                }
            }
            
            // Description de l'onglet sélectionné
            Text(selectedTab.description)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, AppSpacing.xs)
        }
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.warning)
                
                Text(t("insights"))
                    .font(AppTypography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(spacing: AppSpacing.sm) {
                InsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Vos meilleures performances ont lieu en période de calme émotionnel",
                    color: AppColors.success
                )
                
                InsightCard(
                    icon: "exclamationmark.triangle.fill",
                    text: "Votre charge émotionnelle a augmenté de 15% cette semaine",
                    color: AppColors.warning
                )
                
                InsightCard(
                    icon: "arrow.left.arrow.right",
                    text: "Corrélation négative détectée : plus vous êtes stressé, moins vous performez",
                    color: AppColors.info
                )
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Supporting Views

private struct TabButton: View {
    let tab: EmotionalAnalyticsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                
                Text(tab.rawValue)
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            }
            .frame(minWidth: 100)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [AppColors.cardBackground, AppColors.cardBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .stroke(
                                isSelected ? AppColors.primary : AppColors.border.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? AppColors.primary.opacity(0.3) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
}

private struct InsightCard: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    StandaloneEmotionalAnalyticsView()
        .environmentObject(AppState())
}

// MARK: - Alias for compatibility
typealias EmotionalAnalyticsView = StandaloneEmotionalAnalyticsView
