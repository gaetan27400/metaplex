//
//  View+Localized.swift
//  Journal de trading 2025
//
//  Extension pour faciliter l'utilisation des traductions dans les vues
//

import SwiftUI

extension View {
    /// Retourne la traduction de la clé dans la langue courante
    /// Usage: Text(localized("dashboard"))
    func localized(_ key: String) -> String {
        Localizable.text(key, language: LanguageManager.shared.currentLanguage)
    }
}
