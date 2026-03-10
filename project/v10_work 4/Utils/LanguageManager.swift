//
//  LanguageManager.swift
//  Journal de trading 2025
//
//  Service centralisé pour gérer la langue de l'application
//

import Foundation
import SwiftUI
import Combine

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: Localizable.Language = .french
    
    private init() {
        // Charger la langue sauvegardée depuis UserDefaults
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Localizable.Language(rawValue: savedLanguage) {
            currentLanguage = language
        }
    }
    
    func setLanguage(_ language: Localizable.Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
    }
}
