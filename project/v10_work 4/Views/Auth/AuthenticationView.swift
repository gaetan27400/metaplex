//
//  AuthenticationView.swift
//  Journal de trading 2025
//
//  Vue d'authentification principale qui affiche Login ou SignUp
//

import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Binding var showLogin: Bool
    @Binding var showSignUp: Bool
    @State private var isShowingLogin = true
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack {
                if isShowingLogin {
                    LoginViewContent(
                        onSwitchToSignUp: {
                            withAnimation {
                                isShowingLogin = false
                            }
                        },
                        onSuccess: {
                            // La connexion a réussi, l'observateur dans AppState gérera le reste
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    SignUpViewContent(
                        onSwitchToLogin: {
                            withAnimation {
                                isShowingLogin = true
                            }
                        },
                        onSuccess: {
                            // L'inscription a réussi, l'observateur dans AppState gérera le reste
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isShowingLogin)
        }
    }
}

// MARK: - Login View Content (sans NavigationStack pour éviter les conflits)
struct LoginViewContent: View {
    @EnvironmentObject var authManager: AuthManager
    let onSwitchToSignUp: () -> Void
    let onSuccess: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var rememberMe = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingForgotPassword = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    VStack(spacing: 8) {
                        Text(t("bonjour"))
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(t("connectezvousPourAccderVotreJournalDeTrading"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 40)
                
                // Form
                VStack(spacing: 16) {
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("email"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        TextField("", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Mot de passe
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("password"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        HStack {
                            if showPassword {
                                TextField("", text: $password)
                            } else {
                                SecureField("", text: $password)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 16))
                            }
                        }
                        .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // Options
                    HStack {
                        Button(action: { rememberMe.toggle() }) {
                            HStack(spacing: 8) {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .foregroundColor(rememberMe ? AppColors.primary : AppColors.textSecondary)
                                
                                Text(t("friday"))
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Mot de passe oublié ?") {
                            showingForgotPassword = true
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
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
                        .background(isLoginValid ? AppColors.primary : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isLoginValid || authManager.isLoading)
                    
                    // Lien vers l'inscription
                    HStack {
                        Text(t("account"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Button("S'inscrire") {
                            onSwitchToSignUp()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 20)
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
    
    private var isLoginValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func signIn() {
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                onSuccess()
            } catch {
                await MainActor.run {
                    // Utiliser le message d'erreur de AuthManager ou convertir l'erreur
                    if let authError = error as? AuthError {
                        alertMessage = authError.errorDescription ?? "Erreur lors de la connexion"
                    } else {
                        // Essayer de convertir l'erreur Firebase
                        alertMessage = convertErrorToMessage(error)
                    }
                    showingAlert = true
                }
            }
        }
    }
    
    private func convertErrorToMessage(_ error: Error) -> String {
        // Si c'est déjà une AuthError, utiliser sa description
        if let authError = error as? AuthError {
            return authError.errorDescription ?? "Erreur lors de la connexion"
        }
        
        // Sinon, essayer d'extraire un message utile
        let nsError = error as NSError
        if let localizedDescription = nsError.localizedDescription as String?,
           !localizedDescription.isEmpty && !localizedDescription.contains("internal error") {
            return localizedDescription
        }
        
        return "Erreur lors de la connexion. Vérifiez vos identifiants et votre connexion internet."
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

// MARK: - Sign Up View Content (sans NavigationStack)
struct SignUpViewContent: View {
    @EnvironmentObject var authManager: AuthManager
    let onSwitchToLogin: () -> Void
    let onSuccess: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var agreeToTerms = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text(t("account"))
                        .font(.title2.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, 20)
                }
                
                // Form
                VStack(spacing: 16) {
                    // Nom
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("name"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        TextField("", text: $displayName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("email"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        TextField("", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Mot de passe
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("password"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        HStack {
                            if showPassword {
                                TextField("", text: $password)
                            } else {
                                SecureField("", text: $password)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 16))
                            }
                        }
                        .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // Confirmer
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("confirm"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        HStack {
                            if showConfirmPassword {
                                TextField("", text: $confirmPassword)
                            } else {
                                SecureField("", text: $confirmPassword)
                            }
                            
                            Button(action: { showConfirmPassword.toggle() }) {
                                Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 16))
                            }
                        }
                        .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // Conditions d'utilisation avec toggle
                    HStack(spacing: 12) {
                        Text(t("saturday"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $agreeToTerms)
                            .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)
                
                // Bouton d'inscription avec gradient
                VStack(spacing: 16) {
                    Button(action: signUp) {
                        HStack(spacing: 8) {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(t("account"))
                                    .font(.headline.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(
                            Group {
                                if isSignUpValid {
                                    LinearGradient(
                                        colors: [Color(red: 0.5, green: 0.3, blue: 1.0), Color(red: 0.3, green: 0.6, blue: 1.0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .cornerRadius(12)
                    }
                    .disabled(!isSignUpValid || authManager.isLoading)
                    
                    // Disclaimer Firebase
                    Text(t("enContinuantTuUtilisesFirebaseAuthentication"))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Boutons de connexion sociale
                    HStack(spacing: 16) {
                        // Apple
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 16))
                                Text(t("apple"))
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.cardBackground)
                            .foregroundColor(AppColors.textPrimary)
                            .cornerRadius(12)
                        }
                        
                        // Google
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16))
                                Text(t("google"))
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.cardBackground)
                            .foregroundColor(AppColors.textPrimary)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Lien vers la connexion
                    HStack {
                        Text(t("account"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Button("Se connecter") {
                            onSwitchToLogin()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 20)
            }
        }
        .alert("Erreur", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isSignUpValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        agreeToTerms
    }
    
    private func signUp() {
        Task {
            do {
                try await authManager.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
                onSuccess()
            } catch {
                await MainActor.run {
                    // Utiliser le message d'erreur de AuthManager ou convertir l'erreur
                    if let authError = error as? AuthError {
                        alertMessage = authError.errorDescription ?? "Erreur lors de l'inscription"
                    } else {
                        alertMessage = convertErrorToMessage(error)
                    }
                    showingAlert = true
                }
            }
        }
    }
    
    private func convertErrorToMessage(_ error: Error) -> String {
        // Si c'est déjà une AuthError, utiliser sa description
        if let authError = error as? AuthError {
            return authError.errorDescription ?? "Erreur lors de l'inscription"
        }
        
        // Sinon, essayer d'extraire un message utile
        let nsError = error as NSError
        if let localizedDescription = nsError.localizedDescription as String?,
           !localizedDescription.isEmpty && !localizedDescription.contains("internal error") {
            return localizedDescription
        }
        
        return "Erreur lors de l'inscription. Vérifiez vos informations et votre connexion internet."
    }
}

