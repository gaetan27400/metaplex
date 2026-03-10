//
//  ContentView.swift
//  Journal de trading 2025
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var deepLinkManager = DeepLinkManager()
    @State private var showLogin = false
    @State private var showSignUp = false
    
    var body: some View {
        Group {
            // Vérifier si Firebase est configuré
            if FirebaseAvailability.isConfigured {
                // Si Firebase est configuré, authentification obligatoire
                if appState.authManager.isAuthenticated {
                    // Utilisateur authentifié : afficher l'app
                    TradingJournalApp()
                        .environmentObject(appState)
                        .environmentObject(deepLinkManager)
                        .preferredColorScheme(.dark)
                        .background(Color.black.ignoresSafeArea())
                        .onOpenURL { url in
                            deepLinkManager.handleIncomingURL(url)
                            DeepLinkRouter.shared.handleURL(url)
                        }
                        .onAppear {
                            // Register for push notifications
                            Task {
                                await PushService.shared.registerForPushNotifications()
                            }
                        }
                } else {
                    // Utilisateur non authentifié : afficher la page de connexion
                    AuthenticationView(showLogin: $showLogin, showSignUp: $showSignUp)
                        .environmentObject(appState.authManager)
                        .environmentObject(appState)
                }
            } else {
                // Firebase non configuré : afficher l'app en mode local (pour développement)
                TradingJournalApp()
                    .environmentObject(appState)
                    .environmentObject(deepLinkManager)
                    .preferredColorScheme(.dark)
                    .background(Color.black.ignoresSafeArea())
                    .onOpenURL { url in
                        deepLinkManager.handleIncomingURL(url)
                        DeepLinkRouter.shared.handleURL(url)
                    }
                    .onAppear {
                        // Register for push notifications
                        Task {
                            await PushService.shared.registerForPushNotifications()
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
