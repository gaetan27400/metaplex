//
//  SocialVerificationView.swift
//  Journal de trading 2025
//
//  Vue pour vérifier ses comptes sociaux

import SwiftUI

struct SocialVerificationView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlatform: SocialPlatform = .discord
    @State private var username: String = ""
    @State private var verificationCode: String = ""
    @State private var showingCode = false
    @State private var isVerifying = false
    @State private var verificationStatus: SocialVerification.VerificationStatus?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Sélecteur de plateforme
                    platformSelector
                    
                    // Formulaire de vérification
                    verificationForm
                    
                    // Instructions
                    instructionsSection
                    
                    // Méthodes de vérification
                    verificationMethods
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("socialVerification"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert("Vérification", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                generateCode()
            }
        }
    }
    
    // MARK: - Sélecteur de plateforme
    private var platformSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("plateforme"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(SocialPlatform.allCases, id: \.self) { platform in
                        PlatformButton(
                            platform: platform,
                            isSelected: selectedPlatform == platform
                        ) {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.3)) {
                                selectedPlatform = platform
                                generateCode()
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Formulaire
    private var verificationForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("informations"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            // Username
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(t("no"))
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                
                TextField("Votre @username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // Code de vérification
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(t("codeDeVrification"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Button(action: {
                        HapticFeedback.selection()
                        generateCode()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
                
                HStack {
                    Text(verificationCode)
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    Button(action: {
                        HapticFeedback.selection()
                        UIPasteboard.general.string = verificationCode
                        alertMessage = "Code copié dans le presse-papiers !"
                        showingAlert = true
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
                        )
                )
            }
            
            // Bouton de vérification
            Button(action: {
                Task {
                    await submitVerification()
                }
            }) {
                HStack {
                    if isVerifying {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                    }
                    Text(isVerifying ? "Vérification en cours..." : "Soumettre pour vérification")
                }
                .font(AppTypography.labelLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(selectedPlatform.supportsOAuth ? AppColors.primary : AppColors.accent)
                )
            }
            .disabled(isVerifying || username.isEmpty || verificationCode.isEmpty)
            .opacity((isVerifying || username.isEmpty || verificationCode.isEmpty) ? 0.6 : 1.0)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Instructions
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.primary)
                Text(t("instructions"))
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(selectedPlatform.verificationInstructions)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(t("tapes"))
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    InstructionStep(number: 1, text: "Copiez le code de vérification ci-dessus")
                    InstructionStep(number: 2, text: "Ajoutez-le dans votre bio/profil \(selectedPlatform.displayName)")
                    InstructionStep(number: 3, text: "Entrez votre nom d'utilisateur et soumettez")
                    InstructionStep(number: 4, text: "Notre équipe vérifiera manuellement (sous 24-48h)")
                }
            }
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(Color(hex: selectedPlatform.color).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(Color(hex: selectedPlatform.color).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Méthodes de vérification
    private var verificationMethods: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("mthodesDeVrification"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                if selectedPlatform.supportsOAuth {
                    VerificationMethodCard(
                        title: "Connexion OAuth",
                        description: "Vérification automatique via \(selectedPlatform.displayName)",
                        icon: "lock.shield.fill",
                        isAvailable: true
                    ) {
                        Task {
                            await verifyWithOAuth()
                        }
                    }
                }
                
                VerificationMethodCard(
                    title: "Code dans la bio",
                    description: "Ajoutez le code dans votre bio (vérification manuelle)",
                    icon: "text.bubble.fill",
                    isAvailable: true
                ) {
                    // Déjà implémenté dans le formulaire
                }
                
                VerificationMethodCard(
                    title: "Vérification manuelle",
                    description: "Soumettez votre profil pour vérification par notre équipe",
                    icon: "person.badge.shield.checkmark.fill",
                    isAvailable: true
                ) {
                    Task {
                        await submitVerification()
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Functions
    private func generateCode() {
        // Générer un code unique pour l'utilisateur et la plateforme
        // En production, utiliser userId depuis appState
        let userId = appState.authManager.currentUser?.uid ?? "temp"
        verificationCode = SocialVerificationService.shared.generateVerificationCode(
            userId: userId,
            platform: selectedPlatform
        )
    }
    
    private func submitVerification() async {
        guard !username.isEmpty, !verificationCode.isEmpty else { return }
        
        isVerifying = true
        HapticFeedback.medium()
        
        do {
            let userId = appState.authManager.currentUser?.uid ?? "temp"
            let verification = try await SocialVerificationService.shared.submitForManualVerification(
                userId: userId,
                platform: selectedPlatform,
                username: username,
                code: verificationCode,
                profileLink: nil
            )
            
            await MainActor.run {
                verificationStatus = verification.status
                alertMessage = "Vérification soumise avec succès ! Notre équipe va vérifier votre compte sous 24-48h."
                showingAlert = true
                isVerifying = false
                HapticFeedback.success()
            }
        } catch {
            await MainActor.run {
                alertMessage = "Erreur lors de la soumission : \(error.localizedDescription)"
                showingAlert = true
                isVerifying = false
                HapticFeedback.error()
            }
        }
    }
    
    private func verifyWithOAuth() async {
        isVerifying = true
        HapticFeedback.medium()
        
        do {
            switch selectedPlatform {
            case .discord:
                _ = try await SocialVerificationService.shared.startDiscordOAuth()
            case .twitter:
                _ = try await SocialVerificationService.shared.startTwitterOAuth()
            default:
                throw NSError(domain: "SocialVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: "OAuth non supporté pour cette plateforme"])
            }
            
            // Traiter le code OAuth
            await MainActor.run {
                alertMessage = "Vérification OAuth réussie !"
                showingAlert = true
                isVerifying = false
                HapticFeedback.success()
            }
        } catch {
            await MainActor.run {
                alertMessage = "Erreur OAuth : \(error.localizedDescription)"
                showingAlert = true
                isVerifying = false
                HapticFeedback.error()
            }
        }
    }
}

// MARK: - Composants UI

struct PlatformButton: View {
    let platform: SocialPlatform
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: platform.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color(hex: platform.color))
                
                Text(platform.displayName)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? Color(hex: platform.color) : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(isSelected ? Color.clear : AppColors.border.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(t("number"))
                .font(AppTypography.captionMedium)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(AppColors.primary)
                )
            
            Text(text)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

struct VerificationMethodCard: View {
    let title: String
    let description: String
    let icon: String
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isAvailable ? AppColors.primary : AppColors.textTertiary)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(description)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if isAvailable {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.6)
    }
}

// Note: Color extension with init(hex:) is defined in Utils/ColorExtensions.swift

