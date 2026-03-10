import Foundation

struct EmotionPerformanceAnalysis: Equatable {
    struct Point: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let pnl: Double
        let emotionScore: Double
        let dominantEmotion: EmotionalState?
    }
    
    let points: [Point]
    let correlation: Double
    let interpretation: String
    let impactPercentage: Int
    
    var isEmpty: Bool { points.isEmpty }
    
    static var empty: EmotionPerformanceAnalysis {
        let lang = LanguageManager.shared.currentLanguage
        let msg = lang == .english
            ? "Not enough data yet to analyze the emotional impact on your P&L."
            : "Pas encore assez de données pour analyser l'impact des émotions sur ton P&L."
        return EmotionPerformanceAnalysis(points: [], correlation: 0, interpretation: msg, impactPercentage: 0)
    }
}

final class EmotionPerformanceService {
    private let calendar: Calendar
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    func analyze(trades: [Trade], moods: [MoodEntry]) -> EmotionPerformanceAnalysis {
        let dailyData = aggregateDaily(trades: trades, moods: moods)
        guard dailyData.count >= 3 else {
            return .empty
        }
        
        let sortedDates = dailyData.keys.sorted()
        let points: [EmotionPerformanceAnalysis.Point] = sortedDates.compactMap { date in
            guard let aggregate = dailyData[date] else { return nil }
            let dominantEmotion = aggregate.emotionCounts.max(by: { $0.value < $1.value })?.key
            let averageEmotion = aggregate.emotionScores.isEmpty ? 0 : aggregate.emotionScores.reduce(0, +) / Double(aggregate.emotionScores.count)
            return EmotionPerformanceAnalysis.Point(
                date: date,
                pnl: aggregate.pnl,
                emotionScore: averageEmotion,
                dominantEmotion: dominantEmotion
            )
        }
        
        guard points.count >= 3 else {
            return .empty
        }
        
        let pnlValues = points.map { $0.pnl }
        let emotionValues = points.map { $0.emotionScore }
        let correlation = pearsonCorrelation(x: pnlValues, y: emotionValues)
        let impact = Int(round(abs(correlation) * 100))
        let interpretation = buildInterpretation(correlation: correlation, dominantEmotion: points.last?.dominantEmotion, impact: impact)
        
        return EmotionPerformanceAnalysis(
            points: points,
            correlation: correlation,
            interpretation: interpretation,
            impactPercentage: impact
        )
    }
    
    private func aggregateDaily(trades: [Trade], moods: [MoodEntry]) -> [Date: DailyAggregate] {
        var aggregates: [Date: DailyAggregate] = [:]
        
        for trade in trades {
            let day = calendar.startOfDay(for: trade.date)
            var aggregate = aggregates[day] ?? DailyAggregate()
            aggregate.pnl += trade.pnl
            aggregates[day] = aggregate
        }
        
        for mood in moods {
            let day = calendar.startOfDay(for: mood.timestamp)
            var aggregate = aggregates[day] ?? DailyAggregate()
            let weightedScore = mood.emotionalState.valenceScore * Double(mood.intensity) / 10.0
            aggregate.emotionScores.append(weightedScore)
            aggregate.emotionCounts[mood.emotionalState, default: 0] += 1
            aggregates[day] = aggregate
        }
        
        return aggregates
    }
    
    private func pearsonCorrelation(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count >= 2 else { return 0 }
        
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        
        var numerator = 0.0
        var denominatorX = 0.0
        var denominatorY = 0.0
        
        for i in 0..<x.count {
            let diffX = x[i] - meanX
            let diffY = y[i] - meanY
            numerator += diffX * diffY
            denominatorX += diffX * diffX
            denominatorY += diffY * diffY
        }
        
        let denominator = sqrt(denominatorX * denominatorY)
        guard denominator != 0 else { return 0 }
        return max(-1, min(1, numerator / denominator))
    }
    
    private func buildInterpretation(correlation: Double, dominantEmotion: EmotionalState?, impact: Int) -> String {
        let lang = LanguageManager.shared.currentLanguage
        let isEN = lang == .english
        
        guard impact > 5 else {
            return isEN
                ? "Low emotional impact detected. Keep journaling to refine the analysis."
                : "Impact émotionnel faible détecté. Continue à journaliser pour affiner l'analyse."
        }
        
        let direction: String
        if correlation > 0.3 {
            direction = isEN
                ? "When your emotional state is positive, your performance tends to improve."
                : "Quand ton état émotionnel est positif, tes performances ont tendance à augmenter."
        } else if correlation < -0.3 {
            direction = isEN
                ? "When emotional tension rises, your performance drops."
                : "Quand la tension émotionnelle monte, tes performances reculent."
        } else {
            direction = isEN
                ? "Your emotions have a moderate impact on your P&L."
                : "Tes émotions ont un impact modéré sur ton P&L."
        }
        
        if let emotion = dominantEmotion {
            let emotionName = emotion.displayName.lowercased()
            return isEN
                ? "\(direction) Your recent dominant emotion is \(emotionName). Estimated impact: \(impact)%."
                : "\(direction) Ton émotion dominante récente est \(emotionName). Impact estimé : \(impact)%."
        } else {
            return isEN
                ? "\(direction) Estimated impact: \(impact)%."
                : "\(direction) Impact estimé : \(impact)%."
        }
    }
}

private struct DailyAggregate {
    var pnl: Double = 0
    var emotionScores: [Double] = []
    var emotionCounts: [EmotionalState: Int] = [:]
}
