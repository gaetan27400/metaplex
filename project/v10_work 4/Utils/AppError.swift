//
//  AppError.swift
//  Journal de trading 2025
//
//  Gestion d'erreurs structurée pour l'application
//

import Foundation

/// Erreurs de l'application avec messages localisés
enum AppError: LocalizedError, Equatable {
    case storeError(String)
    case networkError(String)
    case validationError(String)
    case authenticationError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .storeError(let message):
            return "Erreur de stockage : \(message)"
        case .networkError(let message):
            return "Erreur réseau : \(message)"
        case .validationError(let message):
            return "Erreur de validation : \(message)"
        case .authenticationError(let message):
            return "Erreur d'authentification : \(message)"
        case .unknown(let message):
            return "Erreur inconnue : \(message)"
        }
    }
    
    var userFacingMessage: String {
        switch self {
        case .storeError:
            return "Impossible de sauvegarder les données. Veuillez réessayer."
        case .networkError:
            return "Problème de connexion. Vérifiez votre connexion internet."
        case .validationError(let message):
            return message
        case .authenticationError:
            return "Votre session a expiré. Veuillez vous reconnecter."
        case .unknown:
            return "Une erreur est survenue. Veuillez réessayer plus tard."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .storeError:
            return "Vérifiez que vous avez suffisamment d'espace de stockage disponible."
        case .networkError:
            return "Vérifiez votre connexion Wi-Fi ou données mobiles."
        case .validationError:
            return "Vérifiez les informations saisies."
        case .authenticationError:
            return "Déconnectez-vous et reconnectez-vous."
        case .unknown:
            return "Si le problème persiste, contactez le support."
        }
    }
}

extension AppError {
    /// Crée une AppError depuis une Error standard
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        let nsError = error as NSError
        
        // Essayer d'identifier le type d'erreur
        if nsError.domain == NSURLErrorDomain {
            return .networkError(nsError.localizedDescription)
        }
        
        if let localizedDescription = (error as? LocalizedError)?.errorDescription {
            return .unknown(localizedDescription)
        }
        
        return .unknown(error.localizedDescription)
    }
}
