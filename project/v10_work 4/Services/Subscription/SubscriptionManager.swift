//
//  SubscriptionManager.swift
//  Journal de trading 2025
//
//  Gestionnaire d'abonnements PRO avec StoreKit 2
//

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // Identifiants des produits (à configurer dans App Store Connect)
    private let productIDs = [
        // ✅ IDs App Store Connect (TradeMindSet)
        "tms.pro.monthly"
        // Ajoute un yearly plus tard si tu le crées côté ASC:
        // "tms.pro.yearly"
    ]
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    /// Date d'expiration de l'abonnement actif (StoreKit). Nil si inconnu / non applicable.
    @Published var activeExpirationDate: Date? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    // Le produit actuellement actif
    var activeSubscription: Product? {
        products.first { purchasedProductIDs.contains($0.id) }
    }
    
    // Vérifie si l'utilisateur a un abonnement actif
    var isPremiumActive: Bool {
        subscriptionStatus == .subscribed
    }
    
    private init() {
        // Démarrer l'écoute des mises à jour
        startListeningForTransactions()
        
        // Charger les produits et vérifier le statut
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Charge les produits disponibles depuis l'App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🛒 [SubscriptionManager] Chargement des produits...")
            products = try await Product.products(for: productIDs)
            print("✅ [SubscriptionManager] \(products.count) produits chargés")
            
            // Trier par prix (moins cher en premier)
            products.sort { $0.price < $1.price }
        } catch {
            print("❌ [SubscriptionManager] Erreur lors du chargement des produits: \(error)")
            errorMessage = "Impossible de charger les produits. Vérifiez votre connexion."
        }
        
        isLoading = false
    }
    
    /// Achete un produit d'abonnement
    func purchase(_ product: Product) async throws -> Bool {
        guard !isLoading else {
            throw SubscriptionError.alreadyProcessing
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🛒 [SubscriptionManager] Achat de \(product.id)...")
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                
                // Mettre à jour le statut
                await checkSubscriptionStatus()
                
                print("✅ [SubscriptionManager] Achat réussi: \(product.id)")
                isLoading = false
                return true
                
            case .userCancelled:
                print("⚠️ [SubscriptionManager] Achat annulé par l'utilisateur")
                isLoading = false
                return false
                
            case .pending:
                print("⏳ [SubscriptionManager] Achat en attente")
                errorMessage = "Votre achat est en attente d'approbation."
                isLoading = false
                return false
                
            @unknown default:
                print("❓ [SubscriptionManager] Résultat inconnu")
                isLoading = false
                return false
            }
        } catch {
            print("❌ [SubscriptionManager] Erreur lors de l'achat: \(error)")
            errorMessage = "Erreur lors de l'achat: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    /// Restaure les achats précédents
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔄 [SubscriptionManager] Restauration des achats...")
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ [SubscriptionManager] Restauration terminée")
        } catch {
            print("❌ [SubscriptionManager] Erreur lors de la restauration: \(error)")
            errorMessage = "Impossible de restaurer les achats: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Vérifie le statut actuel de l'abonnement
    func checkSubscriptionStatus() async {
        print("🔍 [SubscriptionManager] Vérification du statut de l'abonnement...")
        
        var status: SubscriptionStatus = .notSubscribed
        var purchasedIDs = Set<String>()
        var bestExpiration: Date? = nil
        
        // Vérifier les transactions actuelles
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                
                // Vérifier si c'est un de nos produits
                if productIDs.contains(transaction.productID) {
                    purchasedIDs.insert(transaction.productID)
                    
                    // Vérifier si l'abonnement est toujours actif
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            status = .subscribed
                            bestExpiration = max(bestExpiration ?? expirationDate, expirationDate)
                            print("✅ [SubscriptionManager] Abonnement actif: \(transaction.productID) jusqu'au \(expirationDate)")
                        } else {
                            status = .expired
                            print("⚠️ [SubscriptionManager] Abonnement expiré: \(transaction.productID)")
                        }
                    } else {
                        // Pas de date d'expiration = abonnement actif
                        status = .subscribed
                        // Dans ce cas, on ne force pas d'expiration (nil)
                    }
                }
            } catch {
                print("❌ [SubscriptionManager] Erreur lors de la vérification: \(error)")
            }
        }
        
        purchasedProductIDs = purchasedIDs
        subscriptionStatus = status
        activeExpirationDate = bestExpiration
        
        print("📊 [SubscriptionManager] Statut final: \(status)")
    }
    
    // MARK: - Private Methods
    
    /// Démarre l'écoute des mises à jour de transactions
    private func startListeningForTransactions() {
        updateListenerTask = Task.detached { [weak self] in
            guard let self = self else { return }
            
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    
                    // Vérifier si c'est un de nos produits
                    if self.productIDs.contains(transaction.productID) {
                        await self.checkSubscriptionStatus()
                    }
                    
                    await transaction.finish()
                } catch {
                    print("❌ [SubscriptionManager] Erreur dans la transaction: \(error)")
                }
            }
        }
    }
    
    /// Vérifie et retourne une transaction vérifiée
    /// Méthode non isolée pour pouvoir être appelée depuis n'importe quel contexte
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw SubscriptionError.unverifiedTransaction(error)
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus: Equatable {
    case unknown
    case notSubscribed
    case subscribed
    case expired
    case inGracePeriod
}

// MARK: - Subscription Errors

enum SubscriptionError: LocalizedError {
    case alreadyProcessing
    case unverifiedTransaction(Error)
    case productNotFound
    case purchaseFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Une transaction est déjà en cours"
        case .unverifiedTransaction(let error):
            return "Transaction non vérifiée: \(error.localizedDescription)"
        case .productNotFound:
            return "Produit introuvable"
        case .purchaseFailed(let error):
            return "Échec de l'achat: \(error.localizedDescription)"
        }
    }
}

// MARK: - Product Extensions

extension Product {
    /// Retourne le prix formaté avec la devise
    var formattedPrice: String {
        // Utiliser displayPrice qui est déjà formaté avec la devise locale
        return displayPrice
    }
    
    /// Retourne la période d'abonnement formatée
    var subscriptionPeriodFormatted: String {
        guard let subscription = subscription else {
            return ""
        }
        
        let period = subscription.subscriptionPeriod
        
        switch period.unit {
        case .day:
            return period.value == 1 ? "jour" : "\(period.value) jours"
        case .week:
            return period.value == 1 ? "semaine" : "\(period.value) semaines"
        case .month:
            return period.value == 1 ? "mois" : "\(period.value) mois"
        case .year:
            return period.value == 1 ? "an" : "\(period.value) ans"
        @unknown default:
            return ""
        }
    }
}

