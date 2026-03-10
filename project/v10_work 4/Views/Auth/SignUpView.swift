import SwiftUI

struct SignUpView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
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
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                    // Header minimal
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
                                .foregroundColor(.secondary)
                            
                            Button("Se connecter") {
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
    }
    
    // MARK: - Computed Properties
    
    private var isSignUpValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        agreeToTerms
    }
    
    // MARK: - Actions
    
    private func signUp() {
        Task {
            do {
                try await authManager.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
                
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
}


// MARK: - Step Indicator
struct StepIndicator: View {
    let step: Int
    let title: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Numéro de l'étape
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.tradingBlue : Color.surface3)
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                } else {
                    Text(t("step"))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                }
            }
            
            // Titre de l'étape
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthManager())
}

