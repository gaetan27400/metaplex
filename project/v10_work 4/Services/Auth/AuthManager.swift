import Foundation
import Combine

// MARK: - Authentication Models
struct AuthUser {
    let uid: String
    let email: String
    let displayName: String?
    let photoURL: String?
    let isEmailVerified: Bool
    let createdAt: Date
}

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case networkError
    case tooManyRequests
    case userDisabled
    case operationNotAllowed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Adresse email invalide"
        case .weakPassword:
            return "Mot de passe trop faible (minimum 6 caractères)"
        case .emailAlreadyInUse:
            return "Cette adresse email est déjà utilisée"
        case .userNotFound:
            return "Aucun compte trouvé avec cette adresse email"
        case .wrongPassword:
            return "Mot de passe incorrect"
        case .networkError:
            return "Erreur de connexion. Vérifiez votre réseau"
        case .tooManyRequests:
            return "Trop de tentatives. Veuillez réessayer plus tard"
        case .userDisabled:
            return "Ce compte a été désactivé. Contactez le support"
        case .operationNotAllowed:
            return "Cette opération n'est pas autorisée"
        case .unknown:
            return "Une erreur inattendue s'est produite. Veuillez réessayer"
        }
    }
}

// MARK: - Auth Manager
class AuthManager: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    #if canImport(FirebaseAuth)
    private var authStateHandle: FirebaseAuth.AuthStateDidChangeListenerHandle?
    #endif
    
    init() {
        // Firebase devrait déjà être configuré dans @main init() avant que AppState ne soit créé
        // On ne configure pas Firebase ici pour éviter les conflits d'initialisation
        #if canImport(FirebaseAuth)
        if FirebaseAvailability.isConfigured {
            setupFirebaseAuthListener()
            return
        }
        #endif
        
        // Si Firebase n'est pas configuré, utiliser un utilisateur mock pour le développement
        setupMockUser()
    }
    
    // MARK: - Mock User for Development
    private func setupMockUser() {
        // Simuler un utilisateur connecté pour les tests
        currentUser = AuthUser(
            uid: "mock-user-id",
            email: "demo@tradingjournal.com",
            displayName: "Trader Demo",
            photoURL: nil,
            isEmailVerified: true,
            createdAt: Date()
        )
        isAuthenticated = true
    }
    
    // MARK: - Authentication Methods
    
    /// Inscription avec email et mot de passe
    func signUp(email: String, password: String, displayName: String?) async throws {
        isLoading = true
        errorMessage = nil
        
        // Validation
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }
        
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }
        
        do {
            #if canImport(FirebaseAuth)
            if FirebaseAvailability.isConfigured {
                try await signUpWithFirebase(email: email, password: password, displayName: displayName)
                await MainActor.run { self.isLoading = false }
                return
            }
            #endif
            
            // Fallback: simulate sign up
            try await Task.sleep(nanoseconds: 700_000_000)
            let newUser = AuthUser(
                uid: UUID().uuidString,
                email: email,
                displayName: displayName,
                photoURL: nil,
                isEmailVerified: false,
                createdAt: Date()
            )
            
            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                let authError = error as? AuthError ?? .unknown
                self.errorMessage = authError.errorDescription ?? "Erreur lors de l'inscription"
                print("❌ [AuthManager.signUp] Erreur: \(authError.errorDescription ?? "Unknown")")
            }
            throw error
        }
    }
    
    /// Connexion avec email et mot de passe
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        // Validation
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }
        
        guard !password.isEmpty else {
            throw AuthError.wrongPassword
        }
        
        do {
            #if canImport(FirebaseAuth)
            if FirebaseAvailability.isConfigured {
                try await signInWithFirebase(email: email, password: password)
                await MainActor.run { self.isLoading = false }
                return
            }
            #endif
            
            // Fallback: simulate sign in
            try await Task.sleep(nanoseconds: 700_000_000)
            if email == "demo@tradingjournal.com" && password == "demo123" {
                let user = AuthUser(
                    uid: "demo-user-id",
                    email: email,
                    displayName: "Trader Demo",
                    photoURL: nil,
                    isEmailVerified: true,
                    createdAt: Date()
                )
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.isLoading = false
                }
            } else {
                throw AuthError.wrongPassword
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                let authError = error as? AuthError ?? .unknown
                self.errorMessage = authError.errorDescription ?? "Erreur lors de la connexion"
                print("❌ [AuthManager.signIn] Erreur: \(authError.errorDescription ?? "Unknown")")
            }
            throw error
        }
    }
    
    /// Déconnexion
    func signOut() async {
        isLoading = true
        
        do {
            #if canImport(FirebaseAuth)
            if FirebaseAvailability.isConfigured {
                try FirebaseAuth.Auth.auth().signOut()
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.isLoading = false
                    self.errorMessage = nil
                }
                return
            }
            #endif
            
            // Fallback: simulate sign out
            try await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    /// Réinitialisation du mot de passe
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        guard isValidEmail(email) else {
            throw AuthError.invalidEmail
        }
        
        do {
            #if canImport(FirebaseAuth)
            if FirebaseAvailability.isConfigured {
                try await FirebaseAuth.Auth.auth().sendPasswordReset(withEmail: email)
                await MainActor.run { self.isLoading = false }
                return
            }
            #endif
            
            // Fallback: simulate reset email
            try await Task.sleep(nanoseconds: 700_000_000)
            
            await MainActor.run {
                self.isLoading = false
                // En production, afficher un message de succès
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Erreur lors de l'envoi de l'email"
            }
            throw error
        }
    }
    
    /// Envoi d'email de vérification
    func sendEmailVerification() async throws {
        guard let user = currentUser, !user.isEmailVerified else { return }
        
        isLoading = true
        
        do {
            #if canImport(FirebaseAuth)
            if FirebaseAvailability.isConfigured {
                try await FirebaseAuth.Auth.auth().currentUser?.sendEmailVerification()
                await MainActor.run { self.isLoading = false }
                return
            }
            #endif
            
            // Fallback: simulate verification email
            try await Task.sleep(nanoseconds: 700_000_000)
            
            await MainActor.run {
                self.isLoading = false
                // En production, afficher un message de succès
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Erreur lors de l'envoi de l'email"
            }
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func clearError() {
        errorMessage = nil
    }
}

#if canImport(FirebaseAuth)
import FirebaseAuth

extension AuthManager {
    private func setupFirebaseAuthListener() {
        // Avoid registering twice
        if authStateHandle != nil { return }
        
        authStateHandle = FirebaseAuth.Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            let mapped = user.map { self.mapFirebaseUser($0) }
            DispatchQueue.main.async {
                self.currentUser = mapped
                self.isAuthenticated = (mapped != nil)
                self.errorMessage = nil
            }
        }
    }
    
    private func mapFirebaseUser(_ user: FirebaseAuth.User) -> AuthUser {
        AuthUser(
            uid: user.uid,
            email: user.email ?? "",
            displayName: user.displayName,
            photoURL: user.photoURL?.absoluteString,
            isEmailVerified: user.isEmailVerified,
            createdAt: user.metadata.creationDate ?? Date()
        )
    }
    
    private func signUpWithFirebase(email: String, password: String, displayName: String?) async throws {
        do {
            let result = try await FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password)
            if let displayName, !displayName.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = displayName
                try await change.commitChanges()
            }
            // Listener will update published state
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    private func signInWithFirebase(email: String, password: String) async throws {
        do {
            _ = try await FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password)
            // Listener will update published state
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    /// Convertit une erreur Firebase en AuthError avec un message français
    private func mapFirebaseError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        
        // Essayer de récupérer le code d'erreur Firebase Auth
        guard let errorCode = AuthErrorCode(_bridgedNSError: nsError) else {
            // Si le code n'est pas reconnu comme AuthErrorCode, vérifier le code numérique
            let errorCodeValue = nsError.code
            print("⚠️ [AuthManager] Code d'erreur Firebase non reconnu: \(errorCodeValue)")
            print("⚠️ [AuthManager] Domain: \(nsError.domain)")
            print("⚠️ [AuthManager] UserInfo: \(nsError.userInfo)")
            print("⚠️ [AuthManager] Description: \(nsError.localizedDescription)")
            
            // Essayer de mapper manuellement via le code numérique si c'est une erreur Firebase Auth
            // Les codes d'erreur Firebase Auth sont généralement dans le domain com.firebase.auth
            if nsError.domain == "FIRAuthErrorDomain" || nsError.domain.contains("auth") {
                return mapAuthErrorCode(Int32(errorCodeValue))
            }
            
            return .unknown
        }
        
        print("🔍 [AuthManager] Code erreur Firebase: \(errorCode.rawValue), Description: \(nsError.localizedDescription)")
        
        switch errorCode {
        // Cas principaux
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .networkError:
            return .networkError
        case .tooManyRequests:
            return .tooManyRequests
        case .userDisabled:
            return .userDisabled
        case .operationNotAllowed:
            return .operationNotAllowed
        
        // Tokens et credentials
        case .invalidCustomToken:
            return .invalidEmail
        case .customTokenMismatch:
            return .invalidEmail
        case .invalidCredential:
            return .wrongPassword
        case .accountExistsWithDifferentCredential:
            return .emailAlreadyInUse
        case .credentialAlreadyInUse:
            return .emailAlreadyInUse
        case .invalidUserToken:
            return .invalidEmail
        case .userTokenExpired:
            return .operationNotAllowed
        case .rejectedCredential:
            return .wrongPassword
        
        // Providers et authentification
        case .providerAlreadyLinked:
            return .emailAlreadyInUse
        case .noSuchProvider:
            return .userNotFound
        case .invalidProviderID:
            return .unknown
        case .requiresRecentLogin:
            return .operationNotAllowed
        case .userMismatch:
            return .userNotFound
        
        // Email et vérification
        case .missingEmail:
            return .invalidEmail
        case .invalidRecipientEmail:
            return .invalidEmail
        case .unverifiedEmail:
            return .invalidEmail
        case .emailChangeNeedsVerification:
            return .invalidEmail
        case .expiredActionCode:
            return .operationNotAllowed
        case .invalidActionCode:
            return .invalidEmail
        
        // Messages et notifications
        case .invalidMessagePayload:
            return .unknown
        case .invalidSender:
            return .unknown
        case .missingAppToken:
            return .unknown
        case .notificationNotForwarded:
            return .unknown
        
        // App et configuration
        case .appNotAuthorized:
            return .operationNotAllowed
        case .appNotVerified:
            return .operationNotAllowed
        case .missingIosBundleID:
            return .unknown
        case .missingAndroidPackageName:
            return .unknown
        case .unauthorizedDomain:
            return .operationNotAllowed
        case .invalidContinueURI:
            return .unknown
        case .missingContinueURI:
            return .unknown
        case .invalidClientID:
            return .unknown
        case .missingClientIdentifier:
            return .unknown
        case .missingClientType:
            return .unknown
        
        // Téléphone
        case .missingPhoneNumber:
            return .invalidEmail
        case .invalidPhoneNumber:
            return .invalidEmail
        case .missingVerificationCode:
            return .wrongPassword
        case .invalidVerificationCode:
            return .wrongPassword
        case .missingVerificationID:
            return .unknown
        case .invalidVerificationID:
            return .unknown
        
        // App credentials
        case .missingAppCredential:
            return .unknown
        case .invalidAppCredential:
            return .unknown
        
        // Sessions et quotas
        case .sessionExpired:
            return .operationNotAllowed
        case .quotaExceeded:
            return .tooManyRequests
        
        // Web context
        case .webContextAlreadyPresented:
            return .operationNotAllowed
        case .webContextCancelled:
            return .operationNotAllowed
        case .webNetworkRequestFailed:
            return .networkError
        case .webInternalError:
            return .unknown
        case .webSignInUserInteractionFailure:
            return .operationNotAllowed
        
        // reCAPTCHA
        case .recaptchaNotEnabled:
            return .unknown
        case .missingRecaptchaToken:
            return .unknown
        case .invalidRecaptchaToken:
            return .unknown
        case .invalidRecaptchaAction:
            return .unknown
        case .missingRecaptchaVersion:
            return .unknown
        case .invalidRecaptchaVersion:
            return .unknown
        case .invalidReqType:
            return .unknown
        case .recaptchaSDKNotLinked:
            return .unknown
        case .recaptchaSiteKeyMissing:
            return .unknown
        case .recaptchaActionCreationFailed:
            return .unknown
        case .captchaCheckFailed:
            return .operationNotAllowed
        
        // Multi-factor authentication
        case .secondFactorRequired:
            return .operationNotAllowed
        case .missingMultiFactorSession:
            return .operationNotAllowed
        case .missingMultiFactorInfo:
            return .operationNotAllowed
        case .invalidMultiFactorSession:
            return .operationNotAllowed
        case .multiFactorInfoNotFound:
            return .userNotFound
        case .secondFactorAlreadyEnrolled:
            return .emailAlreadyInUse
        case .maximumSecondFactorCountExceeded:
            return .operationNotAllowed
        case .unsupportedFirstFactor:
            return .operationNotAllowed
        
        // GameKit et autres
        case .localPlayerNotAuthenticated:
            return .operationNotAllowed
        case .gameKitNotLinked:
            return .operationNotAllowed
        case .appVerificationUserInteractionFailure:
            return .operationNotAllowed
        
        // Tenant et hosting
        case .tenantIDMismatch:
            return .unknown
        case .unsupportedTenantOperation:
            return .operationNotAllowed
        case .invalidHostingLinkDomain:
            return .unknown
        
        // Erreurs système
        case .nullUser:
            return .userNotFound
        case .invalidAPIKey:
            return .unknown
        case .keychainError:
            return .unknown
        case .internalError:
            return .unknown
        case .malformedJWT:
            return .invalidEmail
        case .missingOrInvalidNonce:
            return .invalidEmail
        case .blockingCloudFunctionError:
            return .unknown
        case .adminRestrictedOperation:
            return .operationNotAllowed
        
        @unknown default:
            print("⚠️ [AuthManager] Code d'erreur non géré: \(errorCode.rawValue)")
            return mapAuthErrorCode(Int32(errorCode.rawValue))
        }
    }
    
    /// Mappe un code d'erreur numérique Firebase Auth vers AuthError
    private func mapAuthErrorCode(_ code: Int32) -> AuthError {
        // Codes d'erreur Firebase Auth (selon la documentation Firebase)
        switch code {
        case 17007: // EMAIL_ALREADY_IN_USE
            return .emailAlreadyInUse
        case 17008: // INVALID_EMAIL
            return .invalidEmail
        case 17006: // OPERATION_NOT_ALLOWED
            return .operationNotAllowed
        case 17026: // WEAK_PASSWORD
            return .weakPassword
        case 17011: // USER_DISABLED
            return .userDisabled
        case 17012: // USER_NOT_FOUND
            return .userNotFound
        case 17013: // WRONG_PASSWORD
            return .wrongPassword
        case 17020: // NETWORK_ERROR
            return .networkError
        case 17010: // TOO_MANY_REQUESTS
            return .tooManyRequests
        default:
            print("⚠️ [AuthManager] Code d'erreur numérique non géré: \(code)")
            return .unknown
        }
    }
}
#endif











