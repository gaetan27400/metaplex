//
//  SocialVerification.swift
//  Journal de trading 2025
//
//  Modèle pour la vérification des comptes sociaux

import Foundation

// SocialPlatform doit être défini avant SocialVerification pour la conformité Codable
enum SocialPlatform: String, Codable, CaseIterable {
    case discord = "discord"
    case twitter = "twitter"
    case telegram = "telegram"
    case reddit = "reddit"
    case youtube = "youtube"
    case instagram = "instagram"
    case linkedin = "linkedin"
    case tiktok = "tiktok"
    case twitch = "twitch"
    
    var displayName: String {
        switch self {
        case .discord: return "Discord"
        case .twitter: return "Twitter/X"
        case .telegram: return "Telegram"
        case .reddit: return "Reddit"
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .linkedin: return "LinkedIn"
        case .tiktok: return "TikTok"
        case .twitch: return "Twitch"
        }
    }
    
    var icon: String {
        switch self {
        case .discord: return "message.fill"
        case .twitter: return "at"
        case .telegram: return "paperplane.fill"
        case .reddit: return "r.circle.fill"
        case .youtube: return "play.circle.fill"
        case .instagram: return "camera.fill"
        case .linkedin: return "link"
        case .tiktok: return "music.note"
        case .twitch: return "gamecontroller.fill"
        }
    }
    
    var color: String {
        switch self {
        case .discord: return "#5865F2"
        case .twitter: return "#1DA1F2"
        case .telegram: return "#0088CC"
        case .reddit: return "#FF4500"
        case .youtube: return "#FF0000"
        case .instagram: return "#E4405F"
        case .linkedin: return "#0077B5"
        case .tiktok: return "#000000"
        case .twitch: return "#9146FF"
        }
    }
    
    var supportsOAuth: Bool {
        switch self {
        case .discord, .twitter: return true
        default: return false
        }
    }
    
    var verificationInstructions: String {
        switch self {
        case .discord:
            return "Ajoutez le code de vérification dans votre bio Discord ou partagez-le dans un message sur notre serveur."
        case .twitter:
            return "Ajoutez le code de vérification dans votre bio Twitter/X ou utilisez la connexion OAuth."
        case .telegram:
            return "Ajoutez le code de vérification dans votre bio Telegram."
        case .reddit:
            return "Ajoutez le code de vérification dans votre bio Reddit ou créez un post avec le code."
        case .youtube:
            return "Ajoutez le code de vérification dans la description de votre chaîne YouTube."
        case .instagram:
            return "Ajoutez le code de vérification dans votre bio Instagram."
        case .linkedin:
            return "Ajoutez le code de vérification dans votre bio LinkedIn."
        case .tiktok:
            return "Ajoutez le code de vérification dans votre bio TikTok."
        case .twitch:
            return "Ajoutez le code de vérification dans votre bio Twitch."
        }
    }
}

struct SocialVerification: Identifiable, Codable {
    let id: String
    let userId: String
    let platform: SocialPlatform
    let username: String? // Username sur la plateforme
    let verificationCode: String // Code unique pour vérification
    let verificationMethod: VerificationMethod
    let status: VerificationStatus
    let verifiedAt: Date?
    let verifiedBy: String? // ID de l'admin qui a vérifié (si manuel)
    let createdAt: Date
    let updatedAt: Date
    
    enum VerificationMethod: String, Codable {
        case codeInBio = "code_in_bio" // Code dans la bio/profil
        case oauth = "oauth" // OAuth (Discord, Twitter)
        case manual = "manual" // Vérification manuelle
        case linkVerification = "link_verification" // Lien avec code unique
    }
    
    enum VerificationStatus: String, Codable {
        case pending = "pending" // En attente de vérification
        case verified = "verified" // Vérifié
        case rejected = "rejected" // Rejeté
        case expired = "expired" // Code expiré
    }
}

