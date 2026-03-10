//
//  RootTabView.swift
//  Journal de trading 2025
//

import SwiftUI

struct RootTabView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab = 0
    @State private var showingAddMenu = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text(t("dashboard"))
                }
                .tag(0)
            
            SystemsView()
                .tabItem {
                    Image(systemName: "chart.radar")
                    Text(t("systems"))
                }
                .tag(1)
            
            // Placeholder pour le bouton +
            Color.clear
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text(t("add"))
                }
                .tag(2)
            
            TradesView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text(t("trades"))
                }
                .tag(3)
            
            EmotionalJournalView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text(t("motionnel"))
                }
                .tag(4)
        }
        .environmentObject(appState)
        .preferredColorScheme(.dark)
        .accentColor(.blue)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                showingAddMenu = true
                // Revenir à l'onglet précédent
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedTab = 0
                }
            }
        }
        .sheet(isPresented: $showingAddMenu) {
            AddTradeSelectionView()
                .environmentObject(appState)
        }
    }
}

#Preview {
    RootTabView()
}
