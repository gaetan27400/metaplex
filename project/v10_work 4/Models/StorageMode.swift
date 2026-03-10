//
//  StorageMode.swift
//  Journal de trading 2025
//

import Foundation

enum StorageMode: String, CaseIterable, Codable, Identifiable {
    case local = "local"
    case firebase = "firebase"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .local: return "Stockage Local"
        case .firebase: return "Firebase Cloud"
        }
    }
    
    var description: String {
        switch self {
        case .local: return "Données stockées localement sur l'appareil"
        case .firebase: return "Données synchronisées avec Firebase"
        }
    }
}



