//
//  SubscriptionView.swift
//  Journal de trading 2025
//
//  Vue principale pour gérer les abonnements PRO
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header
                    headerSection
                    
                    // Fonctionnalités PRO
                    featuresSection
                    
                    // Produits disponibles
                    if !subscriptionManager.products.isEmpty {
                        productsSection
                    } else if subscriptionManager.isLoading {
                        loadingView
                    } else {
                        errorView
                    }
                    
                    // Footer
                    footerSection
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Pass PRO")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert("Erreur", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(t("dbloquezToutLePotentiel"))
                .font(AppTypography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(t("accdezToutesLesFonctionnalitsAvancesAvecLePassPro"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("fonctionnalitsPro"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(proFeatures, id: \.id) { feature in
                    FeatureRow(feature: feature)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    private let proFeatures = [
        ProFeature(
            icon: "brain.head.profile",
            title: "IA Avancée",
            description: "Analyses approfondies et recommandations personnalisées"
        ),
        ProFeature(
            icon: "chart.line.uptrend.xyaxis",
            title: "Analytics Avancés",
            description: "Graphiques détaillés et export de données"
        ),
        ProFeature(
            icon: "icloud.fill",
            title: "Synchronisation Cloud",
            description: "Multi-appareils et sauvegarde automatique"
        ),
        ProFeature(
            icon: "bell.badge.fill",
            title: "Alertes Premium",
            description: "Notifications personnalisées et webhooks TradingView"
        ),
        ProFeature(
            icon: "arrow.triangle.2.circlepath",
            title: "Support Prioritaire",
            description: "Réponses rapides et fonctionnalités en avant-première"
        )
    ]
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(spacing: AppSpacing.md) {
            Text(t("choisissezVotreAbonnement"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            ForEach(subscriptionManager.products, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isPurchasing: isPurchasing
                ) {
                    selectedProduct = product
                }
            }
            
            // Bouton d'achat
            if let product = selectedProduct ?? subscriptionManager.products.first {
                Button(action: {
                    purchaseProduct(product)
                }) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "crown.fill")
                            Text(t("ai"))
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppRadius.medium)
                }
                .disabled(isPurchasing)
            }
            
            // Bouton de restauration
            Button(action: {
                restorePurchases()
            }) {
                Text(t("restaurerLesAchats"))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primary)
            }
            .disabled(isPurchasing)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text(t("loadingProducts"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.xl)
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.error)
            
            Text(t("impossibleDeChargerLesProduits"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            Text(subscriptionManager.errorMessage ?? "Erreur inconnue")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Réessayer") {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(AppSpacing.xl)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(t("account"))
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: AppSpacing.lg) {
                Button("Conditions") {
                    // Ouvrir les conditions
                }
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.primary)
                
                Button("Confidentialité") {
                    // Ouvrir la politique
                }
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.primary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func purchaseProduct(_ product: Product) {
        isPurchasing = true
        
        Task {
            do {
                let success = try await subscriptionManager.purchase(product)
                if success {
                    HapticFeedback.success()
                    // Le statut sera mis à jour automatiquement via l'observateur
                    dismiss()
                } else {
                    HapticFeedback.error()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                HapticFeedback.error()
            }
            
            isPurchasing = false
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        
        Task {
            await subscriptionManager.restorePurchases()
            isPurchasing = false
            
            if subscriptionManager.isPremiumActive {
                HapticFeedback.success()
                dismiss()
            } else {
                errorMessage = "Aucun achat à restaurer"
                showError = true
            }
        }
    }
}

// MARK: - Supporting Views

struct ProFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct FeatureRow: View {
    let feature: ProFeature
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(AppColors.primary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(feature.title)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(feature.description)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.background)
        )
    }
}

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let isPurchasing: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(product.displayName)
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(product.subscriptionPeriodFormatted)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Text(product.formattedPrice)
                    .font(AppTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? AppColors.primary.opacity(0.1) : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(isSelected ? AppColors.primary : AppColors.border, lineWidth: 2)
                    )
            )
        }
        .disabled(isPurchasing)
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(AppState())
}


