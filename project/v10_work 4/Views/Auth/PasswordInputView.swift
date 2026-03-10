import SwiftUI

struct PasswordInputView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let isSignupFlow: Bool
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var enableTouchID = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header avec progression
                VStack(spacing: 16) {
                    // Barre de progression
                    ProgressBar(currentStep: 4, totalSteps: 5)
                    
                    VStack(spacing: 8) {
                        Text(t("password"))
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
                .padding(.top, 40)
                
                // Formulaire
                VStack(spacing: 20) {
                    // Mot de passe
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("password"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.tradingBlue)
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField("Mot de passe", text: $password)
                            } else {
                                SecureField("Mot de passe", text: $password)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.surface2)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.surface3, lineWidth: 1)
                        )
                    }
                    
                    // Confirmation mot de passe
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("confirm"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.tradingBlue)
                                .frame(width: 20)
                            
                            if showConfirmPassword {
                                TextField("Confirmer le mot de passe", text: $confirmPassword)
                            } else {
                                SecureField("Confirmer le mot de passe", text: $confirmPassword)
                            }
                            
                            Button(action: { showConfirmPassword.toggle() }) {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.surface2)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.surface3, lineWidth: 1)
                        )
                    }
                    
                    // Option Touch ID
                    HStack {
                        Text(t("yes"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $enableTouchID)
                            .toggleStyle(SwitchToggleStyle(tint: .tradingBlue))
                    }
                    .padding(.vertical, 8)
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
                        .background(isFormValid ? Color.tradingBlue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
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
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !password.isEmpty && 
        !confirmPassword.isEmpty && 
        password == confirmPassword &&
        password.count >= 8
    }
    
    // MARK: - Actions
    
    private func continueAction() {
        guard password == confirmPassword else {
            alertMessage = "Les mots de passe ne correspondent pas."
            showingAlert = true
            return
        }
        
        guard password.count >= 8 else {
            alertMessage = "Le mot de passe doit contenir au moins 8 caractères."
            showingAlert = true
            return
        }
        
        Task {
            do {
                // Simulation de création/réinitialisation du mot de passe
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    // TODO: Naviguer vers VerificationCompleteView
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
    PasswordInputView(isSignupFlow: true)
        .environmentObject(AuthManager())
}










