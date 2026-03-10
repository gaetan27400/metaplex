import SwiftUI

/// Écran Mission
/// - Rôle produit: centraliser **Aperçu / Progression / Défis / Badges** (anciennement dans Profil).
/// - Important: aucun élément "compte" (uid, email, tradingview, etc.) ici.
struct MissionView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MissionTab = .overview
    @State private var showingStats: Bool = false
    
    enum MissionTab: String, CaseIterable {
        case overview = "Aperçu"
        case progression = "Progression"
        case challenges = "Défis"
        case badges = "Badges"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MissionTabPicker(selectedTab: $selectedTab)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                
                TabView(selection: $selectedTab) {
                    ProfileOverviewTab(selectedTab: $selectedTab)
                        .tag(MissionTab.overview)
                    
                    ProfileProgressionTab()
                        .tag(MissionTab.progression)
                    
                    ProfileChallengesTab()
                        .tag(MissionTab.challenges)
                    
                    ProfileBadgesTab()
                        .tag(MissionTab.badges)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("mission"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            HapticFeedback.selection()
                            showingStats = true
                        } label: {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .accessibilityLabel("Ouvrir les statistiques")
                        
                        Button {
                        HapticFeedback.selection()
                        // Shortcut: aller sur Défis
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = .challenges
                        }
                        } label: {
                            Image(systemName: "target")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .accessibilityLabel("Aller aux défis")
                    }
                }
            }
            .sheet(isPresented: $showingStats) {
                NavigationStack {
                    ProfileStatsTab()
                        .navigationTitle(t("statistics"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(t("close")) { showingStats = false }
                            }
                        }
                }
                .environmentObject(appState)
            }
        }
    }
}


