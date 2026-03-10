//
//  AISettingsView.swift
//  Journal de trading 2025
//
//  L'IA est désormais fournie par le serveur TradeMindSet (Firebase Cloud Functions).
//  Plus besoin de clé API utilisateur.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct AISettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared

    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @State private var enableLLM: Bool = true
    @State private var testResult: String = ""
    @State private var isTesting: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var isAuthenticated: Bool {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser != nil
        #else
        return true
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                // Info Section
                Section(header: Text(t("ai"))) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IA sécurisée")
                                .font(.headline)
                            Text("L'analyse IA est fournie par TradeMindSet via un serveur sécurisé. Aucune clé API nécessaire.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Activer l'analyse IA", isOn: $enableLLM)
                }

                // Status Section
                Section(header: Text("Statut")) {
                    HStack {
                        Circle()
                            .fill(isAuthenticated ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(isAuthenticated ? "Connecté — IA disponible" : "Non connecté — Connectez-vous pour utiliser l'IA")
                            .foregroundColor(.secondary)
                    }

                    if isAuthenticated {
                        Button {
                            Task { await testConnection() }
                        } label: {
                            HStack {
                                Text("Tester la connexion")
                                Spacer()
                                if isTesting {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isTesting)
                    }

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult.contains("OK") ? .green : .red)
                    }
                }
            }
            .navigationTitle("IA & Analyse")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        let isEN = languageManager.currentLanguage == .english
        let testPrompt = isEN ? "Reply OK." : "Réponds OK."

        do {
            let response = try await CloudFunctionService.shared.openAIChat(
                messages: [ChatMessagePayload(role: "user", content: testPrompt)],
                temperature: 0
            )
            testResult = response.contains("OK")
                ? (isEN ? "✅ AI Connection OK" : "✅ Connexion IA OK")
                : (isEN ? "✅ Response received" : "✅ Réponse reçue")
        } catch {
            testResult = isEN
                ? "❌ Error: \(error.localizedDescription)"
                : "❌ Erreur: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AISettingsView()
}
