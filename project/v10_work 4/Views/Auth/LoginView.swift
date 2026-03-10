import SwiftUI

struct LoginView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var rememberMe = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                    // Header avec logo et message d'accueil
                    VStack(spacing: 16) {
                        // Logo/Icone
                        ZStack {
                            Circle()
                                .fill(Color.tradingBlue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.tradingBlue)
                        }
                        
                        VStack(spacing: 8) {
                            Text(t("bonjour"))
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.primary)
                            
                            Text(t("connectezvousPourAccderVotreJournalDeTrading"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Boutons de connexion sociale
                    VStack(spacing: 16) {
                        // Connexion avec Apple
                        SocialLoginButton(
                            title: "Continuer avec Apple",
                            icon: "applelogo",
                            backgroundColor: .black,
                            textColor: .white,
                            action: signInWithApple
                        )
                        
                        // Connexion avec Google
                        SocialLoginButton(
                            title: "Continuer avec Google",
                            icon: "globe",
                            backgroundColor: .white,
                            textColor: .black,
                            borderColor: .gray.opacity(0.3),
                            action: signInWithGoogle
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Séparateur
                    HStack {
                        Rectangle()
                            .fill(Color.surface3)
                            .frame(height: 1)
                        
                        Text(t("account"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.surface3)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 20)
                    
                    // Form
                    VStack(spacing: 16) {
                        // Email
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("ai"))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            TextField("votre@email.com", text: $email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Mot de passe
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("password"))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                if showPassword {
                                    TextField("Votre mot de passe", text: $password)
                                } else {
                                    SecureField("Votre mot de passe", text: $password)
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Options
                        HStack {
                            Button(action: { rememberMe.toggle() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .foregroundColor(rememberMe ? .tradingBlue : .secondary)
                                    
                                    Text(t("friday"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button("Mot de passe oublié ?") {
                                // TODO: Naviguer vers AddEmailView pour la réinitialisation
                                showingForgotPassword = true
                            }
                            .font(.caption)
                            .foregroundColor(.tradingBlue)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    
                    // Bouton de connexion
                    VStack(spacing: 16) {
                        Button(action: signIn) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(t("signIn"))
                                        .font(.headline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isLoginValid ? Color.tradingBlue : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isLoginValid || authManager.isLoading)
                        
                        // Lien vers l'inscription
                        HStack {
                            Text(t("account"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("S'inscrire") {
                                // TODO: Naviguer vers AddEmailView pour l'inscription
                                dismiss()
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.tradingBlue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                    }
                }
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
        .alert("Mot de passe oublié", isPresented: $showingForgotPassword) {
            TextField("Email", text: $email)
            Button("Envoyer") {
                resetPassword()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text(t("ai"))
        }
    }
    
    // MARK: - Computed Properties
    
    private var isLoginValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    // MARK: - Actions
    
    private func signIn() {
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                
                await MainActor.run {
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
    
    private func signInWithApple() {
        // TODO: Implémenter Sign in with Apple
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulation
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func signInWithGoogle() {
        // TODO: Implémenter Sign in with Google
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulation
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func resetPassword() {
        Task {
            do {
                try await authManager.resetPassword(email: email)
                
                await MainActor.run {
                    showingForgotPassword = false
                    alertMessage = "Un email de réinitialisation a été envoyé à \(email)"
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

// MARK: - Social Login Button
struct SocialLoginButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let textColor: Color
    let borderColor: Color?
    let action: () -> Void
    
    init(title: String, icon: String, backgroundColor: Color, textColor: Color, borderColor: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.borderColor = borderColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor ?? Color.clear, lineWidth: borderColor != nil ? 1 : 0)
            )
            .cornerRadius(12)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}

