import SwiftUI

struct AddEmailView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let isSignup: Bool
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header avec progression
                VStack(spacing: 16) {
                    // Barre de progression
                    ProgressBar(currentStep: 1, totalSteps: 5)
                    
                    VStack(spacing: 8) {
                        Text(isSignup ? "Quel est votre email ?" : "Réinitialisation du mot de passe")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(isSignup ? 
                             "Entrez l'adresse email que vous souhaitez utiliser pour vous inscrire" :
                             "Veuillez entrer votre adresse email enregistrée pour réinitialiser votre mot de passe")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 40)
                
                // Formulaire
                VStack(spacing: 20) {
                    // Champ email
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("ai"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.tradingBlue)
                                .frame(width: 20)
                            
                            TextField("votre@email.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.emailAddress)
                        }
                        .padding()
                        .background(Color.surface2)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.surface3, lineWidth: 1)
                        )
                    }
                    
                    // Lien vers la connexion (si inscription)
                    if isSignup {
                        HStack {
                            Text(t("account"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Se connecter") {
                                dismiss()
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.tradingBlue)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Bouton continuer
                VStack(spacing: 16) {
                    Button(action: continueAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(t("continuer"))
                                    .font(.headline.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isEmailValid ? Color.tradingBlue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isEmailValid || authManager.isLoading)
                    
                    // Conditions d'utilisation
                    Text(t("ai"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("cancel")) {
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
    
    // MARK: - Computed Properties
    
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    // MARK: - Actions
    
    private func continueAction() {
        Task {
            do {
                if isSignup {
                    // Simulation d'envoi d'email de vérification
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } else {
                    // Simulation d'envoi d'email de réinitialisation
                    try await authManager.resetPassword(email: email)
                }
                
                await MainActor.run {
                    // TODO: Naviguer vers ConfirmEmailView
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

// MARK: - Progress Bar
struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.tradingBlue : Color.surface3)
                        .frame(width: 8, height: 8)
                    
                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? Color.tradingBlue : Color.surface3)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Text("Étape \(currentStep) sur \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    AddEmailView(isSignup: true)
        .environmentObject(AuthManager())
}










