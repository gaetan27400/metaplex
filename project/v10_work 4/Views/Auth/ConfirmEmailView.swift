import SwiftUI

struct ConfirmEmailView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let userEmail: String
    let isSignup: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header avec progression
                VStack(spacing: 16) {
                    // Barre de progression
                    ProgressBar(currentStep: 2, totalSteps: 5)
                    
                    // Illustration
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.tradingBlue.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "envelope.open")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(.tradingBlue)
                        }
                        
                        VStack(spacing: 8) {
                            Text(t("ai"))
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(t("ai"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Actions
                VStack(spacing: 16) {
                    Button(action: confirmAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(t("confirm"))
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
                    
                    // Lien pour renvoyer l'email
                    Button("Je n'ai pas reçu l'email") {
                        resendEmail()
                    }
                    .font(.subheadline)
                    .foregroundColor(.tradingBlue)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Retour") {
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
    
    private func confirmAction() {
        Task {
            do {
                // Simulation de confirmation d'email
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    // TODO: Naviguer vers OTPView
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
    
    private func resendEmail() {
        Task {
            do {
                try await authManager.resetPassword(email: userEmail)
                
                await MainActor.run {
                    alertMessage = "Un nouvel email a été envoyé à \(userEmail)"
                    showingAlert = true
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
    ConfirmEmailView(userEmail: "test@example.com", isSignup: true)
        .environmentObject(AuthManager())
}










