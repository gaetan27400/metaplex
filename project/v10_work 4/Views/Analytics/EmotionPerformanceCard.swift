import SwiftUI
import Charts

struct EmotionPerformanceCard: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    
    private var analysis: EmotionPerformanceAnalysis {
        appState.emotionPerformanceAnalysis
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            chartSection
            footer
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(t("motionsPerformance"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                Text(t("ai"))
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            CorrelationBadge(correlation: analysis.correlation, impact: analysis.impactPercentage)
        }
    }
    
    private var chartSection: some View {
        Group {
            if analysis.isEmpty {
                emptyChartState
            } else {
                chartContent
            }
        }
    }
    
    private var emptyChartState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textSecondary.opacity(0.8))
            Text(t("analyse"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
    
    private var chartContent: some View {
        Chart {
            ForEach(analysis.points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("P&L", point.pnl)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppColors.success)
                .lineStyle(.init(lineWidth: 2.5))
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("P&L", point.pnl)
                )
                .foregroundStyle(AppColors.success)
                .symbolSize(40)
            }
            
            ForEach(analysis.points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Indice émotionnel", point.emotionScore)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppColors.accent)
                .lineStyle(.init(lineWidth: 2, dash: [6, 3]))
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Indice émotionnel", point.emotionScore)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(30)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(AppColors.border.opacity(0.3))
                if let date = value.as(Date.self) {
                    AxisValueLabel(dateFormatter.string(from: date))
                        .foregroundStyle(AppColors.textSecondary)
                        .font(AppTypography.captionSmall)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(AppColors.border.opacity(0.2))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(String(format: "%+.0f", number))
                            .font(AppTypography.captionSmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .frame(height: 220)
    }
    
    private var footer: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(analysis.interpretation)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let lastEmotion = analysis.points.last?.dominantEmotion {
                Label {
                    Text(t("name"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                } icon: {
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

private struct CorrelationBadge: View {
    let correlation: Double
    let impact: Int
    
    private var label: String {
        switch correlation {
        case let c where c > 0.5: return "Corrélation forte +"
        case let c where c > 0.2: return "Corrélation légère +"
        case let c where c < -0.5: return "Corrélation forte -"
        case let c where c < -0.2: return "Corrélation légère -"
        default: return "Corrélation neutre"
    }
    }
    
    private var tint: Color {
        if correlation > 0.2 {
            return AppColors.success
        } else if correlation < -0.2 {
            return AppColors.error
        } else {
            return AppColors.textSecondary
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .font(AppTypography.captionSmall)
                .foregroundColor(tint)
            Text(String(impact))                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }
}


