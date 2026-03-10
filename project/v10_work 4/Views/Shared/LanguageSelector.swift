//
//  LanguageSelector.swift
//  Journal de trading 2025
//
//  Sélecteur de langue pour l'interface utilisateur
//

import SwiftUI

struct LanguageSelector: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        Menu {
            ForEach(Localizable.Language.allCases) { language in
                Button {
                    languageManager.setLanguage(language)
                } label: {
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                        if languageManager.currentLanguage == language {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(languageManager.currentLanguage.flag)
                    .font(.system(size: 20))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

// MARK: - Preview
struct LanguageSelector_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSelector()
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
