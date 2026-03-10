import SwiftUI

struct ProfessionalEmotionalBalanceView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let analysis: EmotionPerformanceAnalysis
    let moodEntries: [MoodEntry]
    let trades: [Trade]
    
    private var recentMoods: [MoodEntry] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return moodEntries.filter { $0.timestamp >= weekAgo }
    }
    
    private var dominantEmotion: EmotionalState? {
        let emotionGroups = Dictionary(grouping: recentMoods, by: { $0.emotionalState })
        let emotionCounts = emotionGroups.mapValues { $0.count }
        return emotionCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private var emotionGroups: [EmotionalState: [MoodEntry]] {
        Dictionary(grouping: recentMoods, by: { $0.emotionalState })
    }
    
    private var emotionalStateInfo: (title: String, description: String, color: Color, icon: String) {
        if let dominant = dominantEmotion {
            let dominantCount = emotionGroups[dominant]?.count ?? 0
            let percentage = Int((Double(dominantCount) / Double(max(1, recentMoods.count))) * 100)
            
            switch dominant {
            case .confident, .focused, .calm:
                return (
                    t("stateConfident"),
                    recentMoods.isEmpty
                        ? t("descExcellent10")
                        : t("descEmoPosPercent").replacingOccurrences(of: "{pct}", with: "\(percentage)").replacingOccurrences(of: "{n}", with: "\(recentMoods.count)"),
                    AppColors.success,
                    "checkmark.circle.fill"
                )
            case .stressed, .frustrated, .fearful:
                return (
                    t("stateStressed"),
                    recentMoods.isEmpty
                        ? t("descDifficult10")
                        : t("descEmoNegPercent").replacingOccurrences(of: "{pct}", with: "\(percentage)").replacingOccurrences(of: "{n}", with: "\(recentMoods.count)"),
                    AppColors.error,
                    "exclamationmark.triangle.fill"
                )
            case .impatient, .greedy, .excited:
                return (
                    t("stateAgitated"),
                    recentMoods.isEmpty
                        ? t("descBalanced10")
                        : t("descEmoMixPercent").replacingOccurrences(of: "{pct}", with: "\(percentage)").replacingOccurrences(of: "{n}", with: "\(recentMoods.count)"),
                    AppColors.warning,
                    "arrow.triangle.2.circlepath"
                )
            default:
                return (
                    t("stateNeutral"),
                    "Pas assez de données pour analyser l'état émotionnel",
                    AppColors.textSecondary,
                    "minus.circle.fill"
                )
            }
        } else {
            // Fallback sur les trades
            let recentTrades = trades.suffix(10)
            let winRate = recentTrades.isEmpty ? 0 : Double(recentTrades.filter { $0.pnl > 0 }.count) / Double(recentTrades.count)
            
            if winRate >= 0.7 {
                return (t("stateConfident"), t("descExcellent10"), AppColors.success, "checkmark.circle.fill")
            } else if winRate >= 0.4 {
                return (t("stateNeutral"), t("descBalanced10"), AppColors.textSecondary, "minus.circle.fill")
            } else {
                return (t("stateStressed"), t("descDifficult10"), AppColors.error, "exclamationmark.triangle.fill")
            }
        }
    }
    
    private var impactInfo: (title: String, description: String, color: Color, icon: String) {
        if analysis.isEmpty {
            let recentTrades = trades.suffix(20)
            if recentTrades.isEmpty {
                return (t("impactInsufficient"), "Pas assez de données pour analyser l'impact émotionnel", AppColors.textSecondary, "chart.bar.xaxis")
            }
            
            let consecutiveLosses = calculateConsecutiveLosses(recentTrades)
            let consecutiveWins = calculateConsecutiveWins(recentTrades)
            let pnls = recentTrades.map { $0.pnl }
            let volatility = calculatePnLVolatility(pnls)
            
            if consecutiveLosses >= 3 {
                return (t("impactHighStress"), t("descConsecLoss").replacingOccurrences(of: "{n}", with: "\(consecutiveLosses)"), AppColors.error, "arrow.down.circle.fill")
            } else if consecutiveWins >= 3 {
                return (t("impactHighConf"), t("descConsecWin").replacingOccurrences(of: "{n}", with: "\(consecutiveWins)"), AppColors.success, "arrow.up.circle.fill")
            } else if volatility > 1000 {
                return (t("impactInstability"), t("descVolatility").replacingOccurrences(of: "{v}", with: "\(Int(volatility))"), AppColors.warning, "waveform.path.ecg")
            } else {
                return (t("impactBalanced"), t("descBalancedStable"), AppColors.success, "equal.circle.fill")
            }
        } else {
            let correlation = analysis.correlation
            let impact = analysis.impactPercentage
            
            if correlation > 0.2 {
                return (t("impactPositive"), t("descCorrPositive").replacingOccurrences(of: "{pct}", with: "\(impact)"), AppColors.success, "arrow.up.right.circle.fill")
            } else if correlation < -0.2 {
                return (t("impactNegative"), t("descCorrNegative").replacingOccurrences(of: "{pct}", with: "\(impact)"), AppColors.error, "arrow.down.right.circle.fill")
            } else {
                return (t("stateNeutral"), t("descNoCorrPnl"), AppColors.textSecondary, "equal.circle.fill")
            }
        }
    }
    
    private var riskInfo: (title: String, description: String, color: Color, icon: String) {
        let recentTrades = trades.suffix(10)
        var consecutiveLosses = 0
        var maxConsecutiveLosses = 0
        
        for trade in recentTrades.reversed() {
            if trade.pnl < 0 {
                consecutiveLosses += 1
                maxConsecutiveLosses = max(maxConsecutiveLosses, consecutiveLosses)
            } else {
                consecutiveLosses = 0
            }
        }
        
        if maxConsecutiveLosses >= 4 {
            return (t("riskCritical"), t("descRiskCritical").replacingOccurrences(of: "{n}", with: "\(maxConsecutiveLosses)"), AppColors.error, "exclamationmark.octagon.fill")
        } else if maxConsecutiveLosses >= 2 {
            return (t("riskAttention"), t("descRiskAttention").replacingOccurrences(of: "{n}", with: "\(maxConsecutiveLosses)"), AppColors.warning, "exclamationmark.triangle.fill")
        } else {
            return (t("riskStable"), t("descRiskStable"), AppColors.success, "checkmark.shield.fill")
        }
    }
    
    private var adviceInfo: (title: String, description: String, color: Color, icon: String) {
        let recentTrades = trades.suffix(15)
        let winRate = recentTrades.isEmpty ? 0 : Double(recentTrades.filter { $0.pnl > 0 }.count) / Double(recentTrades.count)
        
        if winRate < 0.3 {
            return (t("advicePause"), t("advicePauseDesc"), AppColors.error, "pause.circle.fill")
        } else if winRate < 0.5 {
            return (t("adviceStudy"), t("adviceStudyDesc"), AppColors.warning, "book.fill")
        } else {
            return (t("adviceContinue"), t("adviceContinueDesc"), AppColors.success, "play.circle.fill")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                
                Text(t("bilanmotionnel"))
                    .font(AppTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            
            // Grid de métriques
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.md),
                GridItem(.flexible(), spacing: AppSpacing.md)
            ], spacing: AppSpacing.md) {
                ProfessionalEmotionalCard(
                    title: t("cardAverageState"),
                    value: emotionalStateInfo.title,
                    description: emotionalStateInfo.description,
                    color: emotionalStateInfo.color,
                    icon: emotionalStateInfo.icon
                )
                
                ProfessionalEmotionalCard(
                    title: t("cardEmotionImpact"),
                    value: impactInfo.title,
                    description: impactInfo.description,
                    color: impactInfo.color,
                    icon: impactInfo.icon
                )
                
                ProfessionalEmotionalCard(
                    title: t("cardEmotionalRisk"),
                    value: riskInfo.title,
                    description: riskInfo.description,
                    color: riskInfo.color,
                    icon: riskInfo.icon
                )
                
                ProfessionalEmotionalCard(
                    title: t("cardAIAdvice"),
                    value: adviceInfo.title,
                    description: adviceInfo.description,
                    color: adviceInfo.color,
                    icon: adviceInfo.icon
                )
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)
    }
    
    // MARK: - Helper Functions
    
    private func calculateConsecutiveWins(_ trades: ArraySlice<Trade>) -> Int {
        var maxWins = 0
        var currentWins = 0
        
        for trade in trades.reversed() {
            if trade.pnl > 0 {
                currentWins += 1
                maxWins = max(maxWins, currentWins)
            } else {
                currentWins = 0
            }
        }
        
        return maxWins
    }
    
    private func calculateConsecutiveLosses(_ trades: ArraySlice<Trade>) -> Int {
        var maxLosses = 0
        var currentLosses = 0
        
        for trade in trades.reversed() {
            if trade.pnl < 0 {
                currentLosses += 1
                maxLosses = max(maxLosses, currentLosses)
            } else {
                currentLosses = 0
            }
        }
        
        return maxLosses
    }
    
    private func calculatePnLVolatility(_ pnls: [Double]) -> Double {
        guard !pnls.isEmpty else { return 0 }
        
        let mean = pnls.reduce(0, +) / Double(pnls.count)
        let variance = pnls.map { pow($0 - mean, 2) }.reduce(0, +) / Double(pnls.count)
        return sqrt(variance)
    }
}

// MARK: - Professional Emotional Card Component

private struct ProfessionalEmotionalCard: View {
    let title: String
    let value: String
    let description: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header avec icône
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
            }
            
            Spacer(minLength: 4)
            
            // Valeur principale
            Text(value)
                .font(AppTypography.titleSmall)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            // Description
            Text(description)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
