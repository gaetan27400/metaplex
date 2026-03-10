//
//  LocalizableModifier.swift
//  Journal de trading 2025
//
//  ViewModifier global pour faciliter l'accès aux traductions
//

import SwiftUI

/// ViewModifier qui injecte LanguageManager dans l'environnement
struct LocalizableModifier: ViewModifier {
    @ObservedObject var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
    }
}

extension View {
    /// Applique le modifier de localisation à une vue
    func withLocalization() -> some View {
        modifier(LocalizableModifier())
    }
    
    /// Retourne la traduction d'une clé (version raccourcie)
    func t(_ key: String) -> String {
        Localizable.text(key, language: LanguageManager.shared.currentLanguage)
    }
}

/// Extension String pour faciliter la localisation inline
extension String {
    var localized: String {
        Localizable.text(self, language: LanguageManager.shared.currentLanguage)
    }
    
    func localized(_ language: Localizable.Language) -> String {
        Localizable.text(self, language: language)
    }
}
