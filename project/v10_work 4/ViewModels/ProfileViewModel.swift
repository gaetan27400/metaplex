import Foundation
import Combine

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
#endif

/// ViewModel du profil utilisateur.
///
/// - Important: Le document Firestore utilisateur est **identifié par le uid Firebase Auth** :
///   `users/{uid}`. On ne crée **pas** de champ `userId` dans Firestore.
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published State
    
    /// UID Firebase (document id Firestore). `nil` si non connecté.
    @Published private(set) var uid: String?
    
    /// Valeur actuellement lue depuis Firestore.
    @Published private(set) var tradingViewUsername: String = ""
    
    /// Valeur éditée dans le TextField.
    @Published var tradingViewUsernameDraft: String = ""
    
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    
    /// Affiche l a coche verte UNIQUEMENT après succès du `setData(...)`.
    @Published var didSaveTradingViewUsername: Bool = false
    
    /// Message d’erreur à afficher en UI (fetch/save).
    @Published var errorMessage: String?
    
    // MARK: - Firestore Keys
    
    private enum FirestoreKeys {
        static let users = "users"
        static let tradingViewUsername = "tradingViewUsername"
    }
    
    // MARK: - Public API
    
    /// Charge le document utilisateur `users/{uid}` et hydrate `tradingViewUsername`.
    func fetchUser() async {
        errorMessage = nil
        didSaveTradingViewUsername = false
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAvailability.isConfigured else {
            uid = nil
            errorMessage = "Firebase n'est pas configuré."
            return
        }
        
        guard let currentUID = Auth.auth().currentUser?.uid else {
            uid = nil
            errorMessage = "Aucun utilisateur connecté."
            return
        }
        
        uid = currentUID
        
        do {
            let docRef = Firestore.firestore()
                .collection(FirestoreKeys.users)
                .document(currentUID) // ✅ doc id == uid
            
            let snapshot = try await docRef.getDocument()
            let data = snapshot.data() ?? [:]
            let tv = (data[FirestoreKeys.tradingViewUsername] as? String) ?? ""
            
            tradingViewUsername = tv
            tradingViewUsernameDraft = tv
        } catch {
            errorMessage = "Impossible de charger le profil: \(error.localizedDescription)"
        }
        #else
        uid = nil
        errorMessage = "FirebaseAuth/FirebaseFirestore indisponible dans ce build."
        #endif
    }
    
    /// Sauvegarde `tradingViewUsername` dans `users/{uid}` avec `merge: true`,
    /// puis relit la valeur depuis Firestore et met à jour la vue.
    func saveTradingViewUsername() async {
        errorMessage = nil
        didSaveTradingViewUsername = false
        isSaving = true
        defer { isSaving = false }
        
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAvailability.isConfigured else {
            errorMessage = "Firebase n'est pas configuré."
            return
        }
        
        guard let currentUID = Auth.auth().currentUser?.uid else {
            errorMessage = "Aucun utilisateur connecté."
            return
        }
        
        uid = currentUID
        
        let value = tradingViewUsernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let docRef = Firestore.firestore()
                .collection(FirestoreKeys.users)
                .document(currentUID) // ✅ doc id == uid
            
            // ✅ Exigence: setData avec merge: true
            try await docRef.setData(
                [FirestoreKeys.tradingViewUsername: value],
                merge: true
            )
            
            // Exigence: relire après enregistrement réussi
            let snapshot = try await docRef.getDocument()
            let data = snapshot.data() ?? [:]
            let tv = (data[FirestoreKeys.tradingViewUsername] as? String) ?? ""
            
            tradingViewUsername = tv
            tradingViewUsernameDraft = tv
            didSaveTradingViewUsername = true
        } catch {
            errorMessage = "Impossible d'enregistrer: \(error.localizedDescription)"
            didSaveTradingViewUsername = false
        }
        #else
        errorMessage = "FirebaseAuth/FirebaseFirestore indisponible dans ce build."
        #endif
    }
    
    /// À appeler quand l’utilisateur modifie le champ : on retire la coche “succès”.
    func onDraftChanged() {
        didSaveTradingViewUsername = false
        errorMessage = nil
    }
}


