import Foundation

// MARK: - Coach IA Models

struct DisciplineScoreSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let score: Int
    let recordedAt: Date

    init(id: UUID = UUID(), score: Int, recordedAt: Date = Date()) {
        self.id = id
        self.score = max(0, min(100, score))
        self.recordedAt = recordedAt
    }
}

struct DisciplineScore: Codable, Equatable {
    enum Band: String, Codable {
        case low
        case medium
        case high
        case elite
    }

    let value: Int
    let trend: Int
    let band: Band
    let updatedAt: Date

    init(value: Int, trend: Int, updatedAt: Date = Date()) {
        let clampedValue = max(0, min(100, value))
        self.value = clampedValue
        self.trend = trend
        if clampedValue >= 85 {
            self.band = .elite
        } else if clampedValue >= 65 {
            self.band = .high
        } else if clampedValue >= 40 {
            self.band = .medium
        } else {
            self.band = .low
        }
        self.updatedAt = updatedAt
    }
}

struct WeeklyGoal: Identifiable, Codable, Equatable {
    enum FocusArea: String, Codable, CaseIterable {
        case discipline
        case riskManagement
        case emotionalBalance
        case performance
    }

    let id: UUID
    let title: String
    let description: String
    let focus: FocusArea
    let deadline: Date
    var progress: Double
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        focus: FocusArea,
        deadline: Date,
        progress: Double = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.focus = focus
        self.deadline = deadline
        self.progress = max(0, min(1, progress))
        self.isCompleted = isCompleted
    }
}

struct CoachIAMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let headline: String
    let body: String
    let generatedAt: Date

    init(id: UUID = UUID(), headline: String, body: String, generatedAt: Date = Date()) {
        self.id = id
        self.headline = headline
        self.body = body
        self.generatedAt = generatedAt
    }
}

struct CoachIAObjective: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let rationale: String
    let targetMetric: String
    let dueDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        rationale: String,
        targetMetric: String,
        dueDate: Date
    ) {
        self.id = id
        self.title = title
        self.rationale = rationale
        self.targetMetric = targetMetric
        self.dueDate = dueDate
    }
}

struct CoachIAState: Codable, Equatable {
    var disciplineScore: DisciplineScore
    var weeklyGoal: WeeklyGoal
    var message: CoachIAMessage
    var history: [DisciplineScoreSnapshot]
    var objective: CoachIAObjective?
    var dailySummary: String?

    static var initial: CoachIAState {
        let score = DisciplineScore(value: 50, trend: 0)
        let goal = WeeklyGoal(
            title: "Définis ton plan de trading",
            description: "Note ton setup, ton point d'entrée et ton risque maximum avant chaque session cette semaine.",
            focus: .discipline,
            deadline: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date().addingTimeInterval(604800),
            progress: 0
        )

        let message = CoachIAMessage(
            headline: "Bienvenue avec ton Coach IA",
            body: "Commence par documenter tes trades et tes émotions. Nous construirons ta discipline jour après jour.",
            generatedAt: Date()
        )

        return CoachIAState(
            disciplineScore: score,
            weeklyGoal: goal,
            message: message,
            history: [],
            objective: nil,
            dailySummary: nil
        )
    }

    static var placeholder: CoachIAState {
        let score = DisciplineScore(value: 62, trend: 4)
        let goal = WeeklyGoal(
            title: "Respecter ton stop-loss",
            description: "Objectif : 5 trades consécutifs avec respect strict du stop.",
            focus: .discipline,
            deadline: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date().addingTimeInterval(604800),
            progress: 0.3
        )

        let message = CoachIAMessage(
            headline: "Tu progresses vers plus de discipline",
            body: "Tes derniers trades montrent une meilleure gestion du risque. Reste concentré sur ton plan et continue de noter tes émotions.",
            generatedAt: Date()
        )

        let objective = CoachIAObjective(
            title: "Stabiliser les émotions en pré-trade",
            rationale: "Tes trades performants surviennent lorsque tu es calme et confiant.",
            targetMetric: "Atteindre un score émotionnel \"calme\" 4 jours sur 5.",
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date().addingTimeInterval(432000)
        )

        let history = (0..<10).map { index in
            let scoreValue = max(40, min(90, 55 + Int.random(in: -5...12) + index))
            let date = Calendar.current.date(byAdding: .day, value: -9 + index, to: Date()) ?? Date()
            return DisciplineScoreSnapshot(score: scoreValue, recordedAt: date)
        }

        return CoachIAState(
            disciplineScore: score,
            weeklyGoal: goal,
            message: message,
            history: history,
            objective: objective,
            dailySummary: "WinRate 60 %, drawdown contrôlé, émotions stables. Coach IA recommande de poursuivre la routine actuelle."
        )
    }
}

extension WeeklyGoal.FocusArea {
    var displayName: String {
        switch self {
        case .discipline: return "Discipline"
        case .riskManagement: return "Gestion du risque"
        case .emotionalBalance: return "Équilibre émotionnel"
        case .performance: return "Performance"
        }
    }
    
    var emoji: String {
        switch self {
        case .discipline: return "🎯"
        case .riskManagement: return "🛡️"
        case .emotionalBalance: return "🧘"
        case .performance: return "🚀"
        }
    }
}



