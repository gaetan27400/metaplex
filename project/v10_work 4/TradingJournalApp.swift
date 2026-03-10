import Foundation
import SwiftUI
import Combine

struct TradingJournalApp: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var selectedTab = 0
    @State private var showAddTradeSheet = false
    @State private var shouldOpenPhotoTab = false
    
    private var language: Localizable.Language {
        languageManager.currentLanguage
    }
    
    var body: some View {
        // ✅ Meilleure approche: safeAreaInset réserve l'espace automatiquement (pas de "hack" padding global)
        contentView
            .environmentObject(appState)
            .safeAreaInset(edge: .bottom) {
                CustomBottomBar(selectedTab: $selectedTab, addAction: { showAddTradeSheet = true }, tradesTitle: loc("trades"))
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
        .sheet(isPresented: $showAddTradeSheet) {
            AddTradeSelectionView()
        }
        .onAppear {
            // Vérifier si une image a été partagée
            checkForSharedImage()
        }
    }
    
    private func checkForSharedImage() {
        // Vérifier si une image partagée est disponible
        if SharedImageService.shared.hasPendingSharedImage() {
            // Naviguer vers l'onglet IA (index 3)
            selectedTab = 3
            // Marquer qu'on doit ouvrir l'onglet Photo
            shouldOpenPhotoTab = true
            print("✅ [TradingJournalApp] Shared image detected, navigating to Photo tab")
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if selectedTab == 0 {
            EnhancedDashboardView(language: .constant(language))
        } else if selectedTab == 1 {
            SystemsView()
        } else if selectedTab == 2 {
            TradesAndExchangesView(language: .constant(language))
        } else if selectedTab == 3 {
            AIAssistantView(initialTab: shouldOpenPhotoTab ? .photo : nil)
                .onAppear {
                    // Réinitialiser le flag après utilisation
                    if shouldOpenPhotoTab {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            shouldOpenPhotoTab = false
                        }
                    }
                }
        } else {
            EnhancedDashboardView(language: .constant(language))
        }
    }

    // Barre inférieure personnalisée type iPad
    struct CustomBottomBar: View {
        @Binding var selectedTab: Int
        var addAction: () -> Void
        var tradesTitle: String
        
        private var language: Localizable.Language {
            LanguageManager.shared.currentLanguage
        }
        
        var body: some View {
            HStack(spacing: 8) {
                BottomItem(title: Localizable.text("dashboard", language: language), systemImage: "rectangle.grid.1x2", isSelected: selectedTab == 0) { selectedTab = 0 }
                BottomItem(title: Localizable.text("systems", language: language), systemImage: "chart.bar", isSelected: selectedTab == 1) { selectedTab = 1 }
                
                Spacer(minLength: 8)
                
                Button(action: addAction) {
                    ZStack {
                        Circle().fill(Color.tradingBlue).frame(width: 50, height: 50)
                        Image(systemName: "plus").font(.title3).foregroundColor(AppColors.textPrimary)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .accessibilityLabel(Localizable.text("addTradeAccessibility", language: language))
                
                Spacer(minLength: 8)
                
                BottomItem(title: Localizable.text("trades", language: language), systemImage: "list.bullet", isSelected: selectedTab == 2) { selectedTab = 2 }
                BottomItem(title: Localizable.text("ai", language: language), systemImage: "brain.head.profile", isSelected: selectedTab == 3) { selectedTab = 3 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6).opacity(0.15))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            )
        }
        
        struct BottomItem: View {
            let title: String
            let systemImage: String
            let isSelected: Bool
            let action: () -> Void
            
            var body: some View {
                Button(action: action) {
                    VStack(spacing: 6) {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                        Text(title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.tradingBlue : Color.clear)
                            .opacity(isSelected ? 1.0 : 0.0)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func loc(_ key: String) -> String {
        Localizable.text(key, language: language)
    }
}

// MARK: - Enhanced Dashboard View
