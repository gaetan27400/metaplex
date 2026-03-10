import SwiftUI

/// Petit composant réutilisable pour les 3 toggles "Pré-trade" dans les vues de saisie de trades.
struct PreTradeToggleChip: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? AppColors.success : AppColors.textSecondary)
                Text(title)
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isOn ? 0.10 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isOn ? AppColors.success.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}



