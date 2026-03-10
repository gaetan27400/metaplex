import SwiftUI

struct DashboardHeatmapCellDetailsSheet: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let cell: DashboardHeatmapCell
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.titleMedium.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(cell.title)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                
                if cell.isBest {
                    badge(text: "Best", color: AppColors.success)
                } else if cell.isWorst {
                    badge(text: "Worst", color: AppColors.error)
                } else if cell.isCurrentWeek {
                    badge(text: "Semaine en cours", color: AppColors.primary)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text(cell.primaryText)
                    .font(AppTypography.titleLarge.weight(.bold))
                    .foregroundColor(Color(hex: cell.fillHex))
                    .monospacedDigit()
                
                if !cell.secondaryText.isEmpty {
                    Text(cell.secondaryText)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(AppColors.cardBackground.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                    )
            )
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.lg)
        .presentationDragIndicator(.visible)
    }
    
    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(AppTypography.captionSmall.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(color.opacity(0.18))
            )
            .foregroundColor(color)
    }
}


