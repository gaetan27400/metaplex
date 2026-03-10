//
//  EmptyStateView.swift
//  Journal de trading 2025
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String = "chart.line.uptrend.xyaxis",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.primary.opacity(0.2),
                                AppColors.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Content
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.titleLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            // Action button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                    .font(AppTypography.labelLarge)
                }
                .buttonStyle(.appButton(variant: .primary))
                .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.xxxl)
    }
}

// MARK: - Skeleton Loader
struct SkeletonLoader: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        RoundedRectangle(cornerRadius: AppRadius.medium)
            .fill(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: -200, y: 0)
                    .opacity(opacity)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    opacity = 0.6
                }
            }
    }
}

struct SkeletonCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                SkeletonLoader()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    SkeletonLoader()
                        .frame(height: 16)
                        .frame(width: 120)
                    
                    SkeletonLoader()
                        .frame(height: 14)
                        .frame(width: 80)
                }
                
                Spacer()
            }
            
            SkeletonLoader()
                .frame(height: 12)
                .frame(maxWidth: .infinity)
            
            SkeletonLoader()
                .frame(height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 100)
        }
        .appCard()
    }
}

// MARK: - Professional Empty States
struct EmptyTradesView: View {
    let action: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            icon: "chart.line.uptrend.xyaxis",
            title: "Aucun trade enregistré",
            message: "Commencez votre journal de trading en ajoutant votre premier trade. Suivez vos performances et améliorez votre stratégie.",
            actionTitle: "Ajouter un trade",
            action: action
        )
    }
}

struct EmptyAlertsView: View {
    var body: some View {
        EmptyStateView(
            icon: "bell.badge",
            title: "Aucune alerte",
            message: "Vous n'avez pas encore d'alertes. Configurez des alertes personnalisées pour être notifié des opportunités de trading.",
            actionTitle: "Configurer des alertes",
            action: nil
        )
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textSecondary)
            
            Text("Aucun résultat")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Essayez avec d'autres mots-clés")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.xxxl)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            EmptyTradesView(action: {})
            Divider()
            EmptySearchView()
            Divider()
            EmptyAlertsView()
        }
        .padding()
    }
    .background(AppColors.background)
}





