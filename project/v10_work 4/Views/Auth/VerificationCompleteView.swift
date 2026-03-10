import SwiftUI

struct VerificationCompleteView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let isSignup: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header avec progression
                VStack(spacing: 16) {
                    // Barre de progression
                    ProgressBar(currentStep: 5, totalSteps: 5)
                    
                    // Illustration de succès
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(.green)
                        }
                        
                        VStack(spacing: 8) {
                            Text(isSignup ? "Vérification réussie" : "Félicitations !")
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(isSignup ? 
                                 "Félicitations ! Votre compte est prêt à être utilisé. Vous pouvez maintenant commencer à trader des cryptomonnaies." :
                                 "Vous avez créé un nouveau mot de passe avec succès. Cliquez sur continuer pour accéder à l'application.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Bouton final
                VStack(spacing: 16) {
                    Button(action: startAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(isSignup ? "Commencer maintenant" : "Continuer")
                                    .font(.headline.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.tradingBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("close")) {
                        dismiss()
                    }
                    .foregroundColor(.tradingBlue)
                }
            }
        }
        .alert("Erreur", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Actions
    
    private func startAction() {
        Task {
            do {
                // Simulation de finalisation du processus
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    if isSignup {
                        // Créer le compte utilisateur
                        Task {
                            try await authManager.signUp(
                                email: "user@example.com",
                                password: "password123",
                                displayName: "Nouvel utilisateur"
                            )
                        }
                    }
                    
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    VerificationCompleteView(isSignup: true)
        .environmentObject(AuthManager())
}










