//
//  FormComponents.swift
//  Journal de trading 2025
//
//  Composants réutilisables pour les formulaires de trade
//

import SwiftUI

// MARK: - Form Field

struct FormField: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 12))
                
                Text(title)
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.background)
                )
        }
    }
}

// MARK: - Picker Field

struct PickerField: View {
    let title: String
    @Binding var selection: UUID?
    let options: [(UUID, String)]
    let icon: String
    
    var selectedText: String {
        if let selection = selection,
           let option = options.first(where: { $0.0 == selection }) {
            return option.1
        }
        return "Sélectionner"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 12))
                
                Text(title)
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Menu {
                ForEach(options, id: \.0) { option in
                    Button(action: {
                        HapticFeedback.selection()
                        selection = option.0
                    }) {
                        HStack {
                            Text(option.1)
                            if selection == option.0 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedText)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(selection != nil ? AppColors.textPrimary : AppColors.textTertiary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.background)
                )
            }
        }
    }
}

// MARK: - System Picker Field

struct SystemPickerField: View {
    let title: String
    @Binding var selection: UUID?
    let systems: [TradingSystem]
    let icon: String
    let onAddSystem: () -> Void
    
    var selectedText: String {
        if let selection = selection,
           let system = systems.first(where: { $0.id == selection }) {
            return system.name
        }
        return "Sélectionner"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 12))
                
                Text(title)
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Menu {
                // Options existantes
                ForEach(systems) { system in
                    Button(action: {
                        HapticFeedback.selection()
                        selection = system.id
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: system.color))
                                .frame(width: 12, height: 12)
                            
                            Text(system.name)
                            
                            if selection == system.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                // Option "Ajouter un système"
                Button(action: {
                    HapticFeedback.medium()
                    onAddSystem()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppColors.primary)
                        Text(t("add"))
                            .foregroundColor(AppColors.primary)
                    }
                }
            } label: {
                HStack {
                    if let selection = selection,
                       let system = systems.first(where: { $0.id == selection }) {
                        Circle()
                            .fill(Color(hex: system.color))
                            .frame(width: 10, height: 10)
                    }
                    
                    Text(selectedText)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(selection != nil ? AppColors.textPrimary : AppColors.textTertiary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.background)
                )
            }
        }
    }
}


