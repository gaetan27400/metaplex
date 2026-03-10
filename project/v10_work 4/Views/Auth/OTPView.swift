import SwiftUI

struct OTPView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let userEmail: String
    let isSignup: Bool
    @State private var otpCode = Array(repeating: "", count: 6)
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var focusedField: Int?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header avec progression
                VStack(spacing: 16) {
                    // Barre de progression
                    ProgressBar(currentStep: 3, totalSteps: 5)
                    
                    VStack(spacing: 8) {
                        Text(t("entrezLeCode"))
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
                
                // Champ OTP
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            TextField("", text: $otpCode[index])
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .multilineTextAlignment(.center)
                                .frame(width: 45, height: 55)
                                .background(Color.surface2)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == index ? Color.tradingBlue : Color.surface3, lineWidth: 2)
                                )
                                .focused($focusedField, equals: index)
                                .onChange(of: otpCode[index]) { oldValue, newValue in
                                    if otpCode[index].count > 1 {
                                        otpCode[index] = String(otpCode[index].prefix(1))
                                    }
                                    
                                    if otpCode[index].count == 1 && index < 5 {
                                        focusedField = index + 1
                                    } else if otpCode[index].isEmpty && index > 0 {
                                        focusedField = index - 1
                                    }
                                }
                        }
                    }
                    
                    // Lien pour renvoyer le code
                    HStack {
                        Text(t("vousNavezPasReuLeCode"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Renvoyer") {
                            resendCode()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.tradingBlue)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Bouton de confirmation
                VStack(spacing: 16) {
                    Button(action: confirmOTP) {
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
                        .background(isOTPValid ? Color.tradingBlue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isOTPValid || authManager.isLoading)
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
        .onAppear {
            focusedField = 0
        }
    }
    
    // MARK: - Computed Properties
    
    private var isOTPValid: Bool {
        otpCode.allSatisfy { !$0.isEmpty }
    }
    
    // MARK: - Actions
    
    private func confirmOTP() {
        let code = otpCode.joined()
        
        Task {
            do {
                // Simulation de vérification OTP
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Vérification simple (en production, ceci serait fait côté serveur)
                if code == "123456" {
                    await MainActor.run {
                        // TODO: Naviguer vers PasswordInputView
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        alertMessage = "Code OTP invalide. Veuillez réessayer."
                        showingAlert = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func resendCode() {
        Task {
            do {
                try await authManager.resetPassword(email: userEmail)
                
                await MainActor.run {
                    alertMessage = "Un nouveau code a été envoyé à \(userEmail)"
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
    OTPView(userEmail: "test@example.com", isSignup: true)
        .environmentObject(AuthManager())
}
