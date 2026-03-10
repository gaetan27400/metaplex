import Foundation

final class CoachIAService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func evaluate(
        trades: [Trade],
        moods: [MoodEntry],
        previousState: CoachIAState?,
        language: Localizable.Language = .french
    ) -> CoachIAState {
        let metrics = computeMetrics(trades: trades, moods: moods)
        let score = buildDisciplineScore(metrics: metrics, previousState: previousState)
        let goal = buildWeeklyGoal(metrics: metrics, previousGoal: previousState?.weeklyGoal, language: language)
        let message = buildCoachMessage(metrics: metrics, score: score, language: language)
        let history = updatedHistory(
            previousHistory: previousState?.history ?? [],
            latestSnapshot: DisciplineScoreSnapshot(score: score.value)
        )
        let objective = buildObjective(metrics: metrics, previousObjective: previousState?.objective, language: language)
        let summary = buildDailySummary(metrics: metrics, score: score, goal: goal, language: language)

        return CoachIAState(
            disciplineScore: score,
            weeklyGoal: goal,
            message: message,
            history: history,
            objective: objective,
            dailySummary: summary
        )
    }
}

private extension CoachIAService {
    struct CoachMetrics {
        let winRate: Double
        let totalPnL: Double
        let positiveEmotionRatio: Double
        let dominantEmotion: EmotionalState
        let averageEmotionIntensity: Double
        let emotionalVolatility: Double
        let tradingFrequency7d: Int
        let lastTradeDate: Date?
    }

    func computeMetrics(trades: [Trade], moods: [MoodEntry]) -> CoachMetrics {
        let winTrades = trades.filter { $0.pnl > 0 }
        let winRate = trades.isEmpty ? 0 : Double(winTrades.count) / Double(trades.count)
        let totalPnL = trades.reduce(0) { $0 + $1.pnl }

        let positiveSet: Set<EmotionalState> = [.calm, .confident, .focused, .excited]
        let positiveCount = moods.filter { positiveSet.contains($0.emotionalState) }.count
        let positiveRatio = moods.isEmpty ? 0.5 : Double(positiveCount) / Double(moods.count)

        let dominantEmotion = moods
            .map { $0.emotionalState }
            .mostFrequent(defaultValue: .calm)

        let averageIntensity = moods.isEmpty ? 5 : moods.map { Double($0.intensity) }.average()
        let volatility = moods.map { Double($0.intensity) }.standardDeviation()

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentTrades = trades.filter { $0.date >= sevenDaysAgo }
        let lastTradeDate = trades.sorted(by: { $0.date > $1.date }).first?.date

        return CoachMetrics(
            winRate: winRate,
            totalPnL: totalPnL,
            positiveEmotionRatio: positiveRatio,
            dominantEmotion: dominantEmotion,
            averageEmotionIntensity: averageIntensity,
            emotionalVolatility: volatility,
            tradingFrequency7d: recentTrades.count,
            lastTradeDate: lastTradeDate
        )
    }

    func buildDisciplineScore(metrics: CoachMetrics, previousState: CoachIAState?) -> DisciplineScore {
        let winScore = metrics.winRate * 55 // 0 - 55
        let emotionScore = metrics.positiveEmotionRatio * 25 // 0 - 25
        let volatilityPenalty = min(20, metrics.emotionalVolatility * 4)
        let frequencyBonus = min(10, Double(metrics.tradingFrequency7d) * 1.2)

        let raw = winScore + emotionScore + frequencyBonus - volatilityPenalty
        let clamped = Int(max(25, min(95, raw)))

        let previousValue = previousState?.disciplineScore.value ?? clamped
        let trend = clamped - previousValue

        return DisciplineScore(value: clamped, trend: trend, updatedAt: Date())
    }

    func buildWeeklyGoal(metrics: CoachMetrics, previousGoal: WeeklyGoal?, language: Localizable.Language) -> WeeklyGoal {
        let deadline = calendar.nextDate(after: Date(), matching: DateComponents(hour: 20), matchingPolicy: .nextTimePreservingSmallerComponents) ?? Date().addingTimeInterval(604800)

        if let goal = previousGoal, !calendar.isDateInYesterday(goal.deadline) {
            return goal
        }

        if metrics.winRate < 0.5 {
            let (title, description) = language == .french
                ? ("Focus sur l'exécution", "Documente chaque trade et valide ton setup avant d'entrer.")
                : ("Focus on execution", "Document each trade and validate your setup before entering.")
            return WeeklyGoal(
                title: title,
                description: description,
                focus: .performance,
                deadline: deadline,
                progress: 0
            )
        }

        if metrics.positiveEmotionRatio < 0.5 {
            let (title, description) = language == .french
                ? ("Stabiliser tes émotions", "Note ton état mental avant et après chaque trade pendant 5 jours.")
                : ("Stabilize your emotions", "Note your mental state before and after each trade for 5 days.")
            return WeeklyGoal(
                title: title,
                description: description,
                focus: .emotionalBalance,
                deadline: deadline,
                progress: 0
            )
        }

        let (title, description) = language == .french
            ? ("Renforcer la discipline", "Respecte ton plan de sortie sur 5 trades consécutifs.")
            : ("Strengthen discipline", "Respect your exit plan on 5 consecutive trades.")
        return WeeklyGoal(
            title: title,
            description: description,
            focus: .discipline,
            deadline: deadline,
            progress: 0
        )
    }

    func buildCoachMessage(metrics: CoachMetrics, score: DisciplineScore, language: Localizable.Language) -> CoachIAMessage {
        let tone: String = {
            switch language {
            case .french:
                switch score.band {
                case .elite: return "Incroyable constance ces derniers jours"
                case .high: return "Belle progression sur ta discipline"
                case .medium: return "On voit une dynamique encourageante"
                case .low: return "C'est le moment de revenir à ton plan"
                }
            case .english:
                switch score.band {
                case .elite: return "Incredible consistency these past days"
                case .high: return "Great progress on your discipline"
                case .medium: return "We see an encouraging dynamic"
                case .low: return "Time to get back to your plan"
                }
            }
        }()

        let emotionComment = comment(for: metrics.dominantEmotion, language: language)
        let pnlComment = language == .french
            ? (metrics.totalPnL >= 0 ? "Ton P&L cumulé reste positif." : "Tu traverses une phase de drawdown maîtrisée.")
            : (metrics.totalPnL >= 0 ? "Your cumulative P&L remains positive." : "You're going through a controlled drawdown phase.")
        
        let continuationAdvice = language == .french
            ? "Continue de noter tes émotions et de valider tes setups avant d'agir."
            : "Keep noting your emotions and validating your setups before acting."
        
        let body = "\(emotionComment) \(pnlComment) \(continuationAdvice)"

        return CoachIAMessage(
            headline: tone,
            body: body,
            generatedAt: Date()
        )
    }

    func comment(for emotion: EmotionalState, language: Localizable.Language) -> String {
        switch language {
        case .french:
            switch emotion {
            case .calm, .confident:
                return "Tu sembles plus posé récemment, c'est idéal pour respecter ton plan."
            case .focused:
                return "Ton niveau de concentration est excellent, garde cette énergie."
            case .stressed, .fearful:
                return "Le stress revient souvent avant tes décisions clés, prends le temps de respirer."
            case .frustrated:
                return "La frustration apparait, pense à décrocher après une série de pertes."
            case .greedy:
                return "La gourmandise a tendance à remonter, fixe tes objectifs avant d'entrer en position."
            case .excited:
                return "L'enthousiasme est bon signe, mais garde un œil sur ton risque."
            case .impatient:
                return "L'impatience peut te faire sortir de ton plan, télécharge ton énergie ailleurs."
            case .distracted:
                return "Tu sembles dispersé, recentre une routine avant de trader."
            }
        case .english:
            switch emotion {
            case .calm, .confident:
                return "You seem more composed recently, ideal for sticking to your plan."
            case .focused:
                return "Your concentration level is excellent, keep this energy."
            case .stressed, .fearful:
                return "Stress often returns before your key decisions, take time to breathe."
            case .frustrated:
                return "Frustration appears, think about stepping away after a losing streak."
            case .greedy:
                return "Greed tends to creep back up, set your targets before entering a position."
            case .excited:
                return "Enthusiasm is a good sign, but keep an eye on your risk."
            case .impatient:
                return "Impatience can take you off your plan, channel your energy elsewhere."
            case .distracted:
                return "You seem scattered, refocus on a routine before trading."
            }
        }
    }

    func updatedHistory(previousHistory: [DisciplineScoreSnapshot], latestSnapshot: DisciplineScoreSnapshot) -> [DisciplineScoreSnapshot] {
        var history = previousHistory.filter { !calendar.isDate($0.recordedAt, inSameDayAs: latestSnapshot.recordedAt) }
        history.append(latestSnapshot)
        return history.suffix(30)
    }

    func buildObjective(metrics: CoachMetrics, previousObjective: CoachIAObjective?, language: Localizable.Language) -> CoachIAObjective? {
        if let objective = previousObjective,
           let due = calendar.date(byAdding: .day, value: 1, to: objective.dueDate),
           due > Date() {
            return previousObjective
        }

        switch metrics.dominantEmotion {
        case .stressed, .fearful:
            let (title, rationale, target) = language == .french
                ? ("Routine anti-stress",
                   "Le stress précède souvent tes entrées de position.",
                   "5 séances de respiration avant l'ouverture des marchés.")
                : ("Anti-stress routine",
                   "Stress often precedes your position entries.",
                   "5 breathing sessions before market opening.")
            return CoachIAObjective(
                title: title,
                rationale: rationale,
                targetMetric: target,
                dueDate: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(432000)
            )
        case .greedy:
            let (title, rationale, target) = language == .french
                ? ("Ancrer ton plan de sortie",
                   "La gourmandise te pousse à prolonger les trades gagnants.",
                   "Documenter ton take profit idéal pour les 5 prochains trades.")
                : ("Anchor your exit plan",
                   "Greed pushes you to extend winning trades.",
                   "Document your ideal take profit for the next 5 trades.")
            return CoachIAObjective(
                title: title,
                rationale: rationale,
                targetMetric: target,
                dueDate: calendar.date(byAdding: .day, value: 4, to: Date()) ?? Date().addingTimeInterval(345600)
            )
        default:
            return previousObjective
        }
    }

    func buildDailySummary(metrics: CoachMetrics, score: DisciplineScore, goal: WeeklyGoal, language: Localizable.Language) -> String {
        let winRateText = String(format: "%.0f%%", metrics.winRate * 100)
        let pnlText = String(format: "%.2f", metrics.totalPnL)
        let volatilityText = String(format: "%.1f", metrics.emotionalVolatility)
        let emotionText = metrics.dominantEmotion.displayName
        
        switch language {
        case .french:
            return "WinRate \(winRateText), P&L \(pnlText)€, émotion dominante \(emotionText), volatilité émotionnelle \(volatilityText). Objectif de la semaine: \(goal.title)."
        case .english:
            return "WinRate \(winRateText), P&L \(pnlText)€, dominant emotion \(emotionText), emotional volatility \(volatilityText). Weekly goal: \(goal.title)."
        }
    }
}

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    func standardDeviation() -> Double {
        guard count > 1 else { return 0 }
        let mean = average()
        let variance = map { pow($0 - mean, 2) }.reduce(0, +) / Double(count)
        return sqrt(variance)
    }
}

private extension Array where Element: Hashable {
    func mostFrequent(defaultValue: Element) -> Element {
        guard let (value, _) = Dictionary(grouping: self, by: { $0 })
            .mapValues({ $0.count })
            .max(by: { $0.value < $1.value }) else {
            return defaultValue
        }
        return value
    }
}
