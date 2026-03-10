//
//  Journal_de_trading_2025App.swift
//  Journal de trading 2025
//

import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

@main
struct Journal_de_trading_2025App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    // ✅ Ne pas initialiser AppState directement - on le fait dans init() APRÈS Firebase
    @StateObject private var appState: AppState

    init() {
        #if DEBUG && canImport(FirebaseAppCheck)
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        #endif
        
        // Créer AppState APRÈS Firebase
        _appState = StateObject(wrappedValue: AppState.shared)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Sauvegarder tous les trades non sauvegardés quand l'app passe en arrière-plan
                    print("💾 [App] willResignActive - Sauvegarde des trades en attente...")
                    Task {
                        await appState.savePendingTrades()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Double sauvegarde au cas où willResignActive n'est pas appelé
                    print("💾 [App] didEnterBackground - Sauvegarde des trades en attente...")
                    Task {
                        await appState.savePendingTrades()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Sauvegarder tous les trades non sauvegardés avant la fermeture
                    // NOTE: Cette notification peut ne pas être appelée sur iOS moderne
                    print("💾 [App] willTerminate - Sauvegarde des trades en attente...")
                    Task {
                        await appState.savePendingTrades()
                    }
                }
        }
    }
}
