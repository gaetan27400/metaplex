import Foundation

// MARK: - État Émotionnel
enum EmotionalState: String, CaseIterable, Codable {
    case confident = "confident"
    case stressed = "stressed"
    case impatient = "impatient"
    case fearful = "fearful"
    case greedy = "greedy"
    case calm = "calm"
    case excited = "excited"
    case frustrated = "frustrated"
    case focused = "focused"
    case distracted = "distracted"
    
    var displayName: String {
        switch self {
        case .confident: return "Confiant"
        case .stressed: return "Stressé"
        case .impatient: return "Impatient"
        case .fearful: return "Peur"
        case .greedy: return "Avarice"
        case .calm: return "Calme"
        case .excited: return "Excité"
        case .frustrated: return "Frustré"
        case .focused: return "Concentré"
        case .distracted: return "Distrait"
        }
    }
    
    var emoji: String {
        switch self {
        case .confident: return "😎"
        case .stressed: return "😰"
        case .impatient: return "😤"
        case .fearful: return "😨"
        case .greedy: return "💰"
        case .calm: return "😌"
        case .excited: return "🤩"
        case .frustrated: return "😡"
        case .focused: return "🎯"
        case .distracted: return "🤔"
        }
    }
    
    var color: String {
        switch self {
        case .confident: return "#4CAF50"
        case .stressed: return "#F44336"
        case .impatient: return "#FF9800"
        case .fearful: return "#9C27B0"
        case .greedy: return "#FFC107"
        case .calm: return "#2196F3"
        case .excited: return "#E91E63"
        case .frustrated: return "#795548"
        case .focused: return "#00BCD4"
        case .distracted: return "#607D8B"
        }
    }
    
    /// Score émotionnel entre -1 (très négatif) et +1 (très positif)
    var valenceScore: Double {
        switch self {
        case .confident: return 0.9
        case .focused: return 0.7
        case .calm: return 0.6
        case .excited: return 0.5
        case .greedy: return 0.2
        case .distracted: return -0.1
        case .impatient: return -0.3
        case .frustrated: return -0.6
        case .stressed: return -0.7
        case .fearful: return -0.8
        }
    }
}

// MARK: - Impact (AUTO)
enum MoodImpact: String, CaseIterable, Codable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"

    var badgeEmoji: String {
        switch self {
        case .positive: return "🟢"
        case .neutral: return "⚪"
        case .negative: return "🔴"
        }
    }

    var displayName: String {
        switch self {
        case .positive: return "Positif"
        case .neutral: return "Neutre"
        case .negative: return "Négatif"
        }
    }
}

// MARK: - Durée (catégories)
enum MoodDurationCategory: String, CaseIterable, Codable {
    case tresCourte = "very_short"
    case courte = "short"
    case moyenne = "medium"
    case longue = "long"
    case persistante = "persistent"

    var displayName: String {
        switch self {
        case .tresCourte: return "Très courte"
        case .courte: return "Courte"
        case .moyenne: return "Moyenne"
        case .longue: return "Longue"
        case .persistante: return "Persistante"
        }
    }
}

// MARK: - Déclencheur (trigger)
enum MoodTrigger: String, CaseIterable, Codable {
    // ✅ v2 (trading triggers) — ajout non-breaking
    case fomo = "fomo"
    case revenge = "revenge"
    case news = "news"
    case loss = "loss"
    case overconfidence = "overconfidence"
    case fatigue = "fatigue"
    case externalStress = "external_stress"

    // ✅ v1 (existant)
    case marketMove = "market_move"
    case waiting = "waiting"
    case previousLoss = "previous_loss"
    case missedOpportunity = "missed_opportunity"
    case personal = "personal"
    case other = "other"

    var displayName: String {
        switch self {
        case .fomo: return "FOMO"
        case .revenge: return "Revenge"
        case .news: return "News"
        case .loss: return "Loss"
        case .overconfidence: return "Overconfidence"
        case .fatigue: return "Fatigue"
        case .externalStress: return "Stress externe"
        case .marketMove: return "Mouvement du marché"
        case .waiting: return "Attente"
        case .previousLoss: return "Perte précédente"
        case .missedOpportunity: return "Opportunité manquée"
        case .personal: return "Personnel"
        case .other: return "Autre"
        }
    }

    /// Label très court pour chips.
    var chipLabel: String {
        switch self {
        case .externalStress: return "Stress"
        case .overconfidence: return "Confiance"
        case .missedOpportunity: return "Manqué"
        case .previousLoss: return "Perte"
        default: return displayName
        }
    }
}

// MARK: - Intention
enum MoodIntention: String, CaseIterable, Codable {
    case followPlan = "follow_plan"
    case catchMove = "catch_move"
    case recoverLoss = "recover_loss"
    case testIdea = "test_idea"
    case unsure = "unsure"

    var displayName: String {
        switch self {
        case .followPlan: return "Suivre le plan"
        case .catchMove: return "Attraper un mouvement"
        case .recoverLoss: return "Récupérer une perte"
        case .testIdea: return "Tester une idée"
        case .unsure: return "Incertain"
        }
    }
}

// MARK: - Source d'entrée (futur IA)
enum EntrySource: String, CaseIterable, Codable {
    case manual = "manual"
    case aiSuggested = "ai_suggested"

    var displayName: String {
        switch self {
        case .manual: return "Manuel"
        case .aiSuggested: return "IA (suggestion)"
        }
    }
}

// MARK: - Checklist avant trade
enum ChecklistBeforeTradeItem: String, CaseIterable, Codable {
    case planClear = "plan_clear"
    case stopDefined = "stop_defined"
    case riskAccepted = "risk_accepted"
    case noRevenge = "no_revenge"
    case noUrgency = "no_urgency"

    var displayName: String {
        switch self {
        case .planClear: return "Plan clair"
        case .stopDefined: return "Stop défini"
        case .riskAccepted: return "Risque accepté"
        case .noRevenge: return "Pas de revenge"
        case .noUrgency: return "Pas d’urgence"
        }
    }
}

/// Checklist stockée en "set de bools" (Codable) — uniquement pertinent si `context == .beforeTrade`.
struct ChecklistBeforeTrade: Codable, Hashable {
    var planClear: Bool = false
    var stopDefined: Bool = false
    var riskAccepted: Bool = false
    var noRevenge: Bool = false
    var noUrgency: Bool = false

    static let empty = ChecklistBeforeTrade()

    subscript(_ item: ChecklistBeforeTradeItem) -> Bool {
        get {
            switch item {
            case .planClear: return planClear
            case .stopDefined: return stopDefined
            case .riskAccepted: return riskAccepted
            case .noRevenge: return noRevenge
            case .noUrgency: return noUrgency
            }
        }
        set {
            switch item {
            case .planClear: planClear = newValue
            case .stopDefined: stopDefined = newValue
            case .riskAccepted: riskAccepted = newValue
            case .noRevenge: noRevenge = newValue
            case .noUrgency: noUrgency = newValue
            }
        }
    }
}

// MARK: - Mini checklist pré-trade (max 3)
struct MiniPreTradeChecklist: Codable, Hashable {
    var planOK: Bool = false
    var sizeOK: Bool = false
    var stopDefined: Bool = false

    static let empty = MiniPreTradeChecklist()
}

// MARK: - Action rapide (optionnelle)
enum MoodQuickAction: String, CaseIterable, Codable {
    case breathing30s = "breathing_30s"
    case pause2min = "pause_2min"
    case mentalChecklist = "mental_checklist"

    var displayName: String {
        switch self {
        case .breathing30s: return "Respiration 30s"
        case .pause2min: return "Pause 2 min"
        case .mentalChecklist: return "Checklist mentale"
        }
    }

    var systemImage: String {
        switch self {
        case .breathing30s: return "wind"
        case .pause2min: return "pause.circle"
        case .mentalChecklist: return "checklist"
        }
    }
}

struct MoodQuickActionEvent: Codable, Hashable, Identifiable {
    let id: UUID
    let action: MoodQuickAction
    let timestamp: Date

    init(action: MoodQuickAction, timestamp: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.action = action
        self.timestamp = timestamp
    }
}

// MARK: - Mood Entry
struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let tradeId: UUID?
    let emotionalState: EmotionalState
    let intensity: Int // 1-10
    let notes: String?
    let timestamp: Date
    let context: MoodContext

    // ✅ Nouveaux champs (optionnels / bruts, pas d'analyse ici)
    let durationCategory: MoodDurationCategory?
    let secondaryEmotionalState: EmotionalState?
    let trigger: MoodTrigger?
    let controlLevel: Int? // 0...10
    let checklistBeforeTrade: ChecklistBeforeTrade? // uniquement si context == .beforeTrade
    let tags: [String]
    let isExceptional: Bool
    let intention: MoodIntention?

    // ✅ Préparation IA future (sans IA maintenant)
    let aiSummary: String?
    let aiSignals: [String]?
    let source: EntrySource

    // ✅ Ajouts "produit" (optionnels)
    let miniChecklist: MiniPreTradeChecklist?
    let quickActions: [MoodQuickActionEvent]

    /// Impact auto calculé (pas stocké).
    var impact: MoodImpact {
        // score -1...+1 (valence) * (0.1...1.0)
        let score = emotionalState.valenceScore * (Double(intensity) / 10.0)
        if score >= 0.25 { return .positive }
        if score <= -0.25 { return .negative }
        return .neutral
    }

    /// Phrase courte pour l'UI (sans logique métier complexe).
    var summaryLine: String {
        var parts: [String] = []
        parts.append("\(emotionalState.displayName) \(intensity)/10")
        parts.append(context.displayName)
        if let durationCategory {
            parts.append("⏱ \(durationCategory.displayName)")
        }
        if let controlLevel {
            parts.append("Ctrl \(controlLevel)/10")
        }
        return parts.joined(separator: " • ")
    }
    
    init(emotionalState: EmotionalState, intensity: Int, notes: String? = nil, tradeId: UUID? = nil, context: MoodContext = .beforeTrade) {
        self.id = UUID()
        self.tradeId = tradeId
        self.emotionalState = emotionalState
        self.intensity = max(1, min(10, intensity))
        self.notes = notes
        self.timestamp = Date()
        self.context = context

        // Defaults (compat / UX: tout reste optionnel)
        self.durationCategory = nil
        self.secondaryEmotionalState = nil
        self.trigger = nil
        self.controlLevel = nil
        self.checklistBeforeTrade = nil
        self.tags = []
        self.isExceptional = false
        self.intention = nil
        self.aiSummary = nil
        self.aiSignals = nil
        self.source = .manual

        self.miniChecklist = nil
        self.quickActions = []
    }
    
    // Initialiseur pour la mise à jour (avec ID et timestamp existants)
    init(id: UUID, tradeId: UUID?, emotionalState: EmotionalState, intensity: Int, notes: String?, context: MoodContext, timestamp: Date) {
        self.id = id
        self.tradeId = tradeId
        self.emotionalState = emotionalState
        self.intensity = max(1, min(10, intensity))
        self.notes = notes
        self.timestamp = timestamp
        self.context = context

        // Defaults (compat / UX)
        self.durationCategory = nil
        self.secondaryEmotionalState = nil
        self.trigger = nil
        self.controlLevel = nil
        self.checklistBeforeTrade = nil
        self.tags = []
        self.isExceptional = false
        self.intention = nil
        self.aiSummary = nil
        self.aiSignals = nil
        self.source = .manual

        self.miniChecklist = nil
        self.quickActions = []
    }

    /// Nouvel init (paramètres optionnels, conserve les init existants).
    init(
        id: UUID = UUID(),
        tradeId: UUID? = nil,
        emotionalState: EmotionalState,
        intensity: Int,
        notes: String? = nil,
        timestamp: Date = Date(),
        context: MoodContext = .beforeTrade,
        durationCategory: MoodDurationCategory? = nil,
        secondaryEmotionalState: EmotionalState? = nil,
        trigger: MoodTrigger? = nil,
        controlLevel: Int? = nil,
        checklistBeforeTrade: ChecklistBeforeTrade? = nil,
        tags: [String] = [],
        isExceptional: Bool = false,
        intention: MoodIntention? = nil,
        aiSummary: String? = nil,
        aiSignals: [String]? = nil,
        source: EntrySource = .manual,
        miniChecklist: MiniPreTradeChecklist? = nil,
        quickActions: [MoodQuickActionEvent] = []
    ) {
        self.id = id
        self.tradeId = tradeId
        self.emotionalState = emotionalState
        self.intensity = max(1, min(10, intensity))
        self.notes = notes
        self.timestamp = timestamp
        self.context = context
        self.durationCategory = durationCategory
        self.secondaryEmotionalState = secondaryEmotionalState
        self.trigger = trigger
        self.controlLevel = controlLevel.map { max(0, min(10, $0)) }
        self.checklistBeforeTrade = (context == .beforeTrade) ? checklistBeforeTrade : nil
        self.tags = tags
        self.isExceptional = isExceptional
        self.intention = intention
        self.aiSummary = aiSummary
        self.aiSignals = aiSignals
        self.source = source

        self.miniChecklist = (context == .beforeTrade) ? miniChecklist : nil
        self.quickActions = quickActions
    }

    // MARK: - Codable (backward compatible)
    enum CodingKeys: String, CodingKey {
        case id, tradeId, emotionalState, intensity, notes, timestamp, context
        case durationCategory, secondaryEmotionalState, trigger, controlLevel, checklistBeforeTrade, tags, isExceptional, intention
        case aiSummary, aiSignals, source
        case miniChecklist, quickActions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decode(UUID.self, forKey: .id)
        self.tradeId = try c.decodeIfPresent(UUID.self, forKey: .tradeId)
        self.emotionalState = try c.decode(EmotionalState.self, forKey: .emotionalState)

        let rawIntensity = try c.decodeIfPresent(Int.self, forKey: .intensity) ?? 5
        self.intensity = max(1, min(10, rawIntensity))

        self.notes = try c.decodeIfPresent(String.self, forKey: .notes)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.context = try c.decodeIfPresent(MoodContext.self, forKey: .context) ?? .beforeTrade

        self.durationCategory = try c.decodeIfPresent(MoodDurationCategory.self, forKey: .durationCategory)
        self.secondaryEmotionalState = try c.decodeIfPresent(EmotionalState.self, forKey: .secondaryEmotionalState)
        self.trigger = try c.decodeIfPresent(MoodTrigger.self, forKey: .trigger)

        if let cl = try c.decodeIfPresent(Int.self, forKey: .controlLevel) {
            self.controlLevel = max(0, min(10, cl))
        } else {
            self.controlLevel = nil
        }

        let decodedChecklist = try c.decodeIfPresent(ChecklistBeforeTrade.self, forKey: .checklistBeforeTrade)
        self.checklistBeforeTrade = (self.context == .beforeTrade) ? decodedChecklist : nil

        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.isExceptional = try c.decodeIfPresent(Bool.self, forKey: .isExceptional) ?? false
        self.intention = try c.decodeIfPresent(MoodIntention.self, forKey: .intention)

        self.aiSummary = try c.decodeIfPresent(String.self, forKey: .aiSummary)
        self.aiSignals = try c.decodeIfPresent([String].self, forKey: .aiSignals)
        self.source = try c.decodeIfPresent(EntrySource.self, forKey: .source) ?? .manual

        let decodedMini = try c.decodeIfPresent(MiniPreTradeChecklist.self, forKey: .miniChecklist)
        self.miniChecklist = (self.context == .beforeTrade) ? decodedMini : nil
        self.quickActions = try c.decodeIfPresent([MoodQuickActionEvent].self, forKey: .quickActions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(tradeId, forKey: .tradeId)
        try c.encode(emotionalState, forKey: .emotionalState)
        try c.encode(intensity, forKey: .intensity)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(context, forKey: .context)

        try c.encodeIfPresent(durationCategory, forKey: .durationCategory)
        try c.encodeIfPresent(secondaryEmotionalState, forKey: .secondaryEmotionalState)
        try c.encodeIfPresent(trigger, forKey: .trigger)
        try c.encodeIfPresent(controlLevel, forKey: .controlLevel)
        if context == .beforeTrade {
            try c.encodeIfPresent(checklistBeforeTrade, forKey: .checklistBeforeTrade)
        }
        try c.encode(tags, forKey: .tags)
        try c.encode(isExceptional, forKey: .isExceptional)
        try c.encodeIfPresent(intention, forKey: .intention)

        try c.encodeIfPresent(aiSummary, forKey: .aiSummary)
        try c.encodeIfPresent(aiSignals, forKey: .aiSignals)
        try c.encode(source, forKey: .source)

        if context == .beforeTrade {
            try c.encodeIfPresent(miniChecklist, forKey: .miniChecklist)
        }
        if !quickActions.isEmpty {
            try c.encode(quickActions, forKey: .quickActions)
        }
    }
}

// MARK: - Contexte du Mood
enum MoodContext: String, CaseIterable, Codable {
    case beforeTrade = "before_trade"
    case afterTrade = "after_trade"
    case duringMarket = "during_market"
    case afterLoss = "after_loss"
    case afterWin = "after_win"
    case endOfDay = "end_of_day"
    
    var displayName: String {
        switch self {
        case .beforeTrade: return "Avant le trade"
        case .afterTrade: return "Après le trade"
        case .duringMarket: return "Pendant le marché"
        case .afterLoss: return "Après une perte"
        case .afterWin: return "Après un gain"
        case .endOfDay: return "Fin de journée"
        }
    }
}

// MARK: - Analyse Émotionnelle
struct EmotionalAnalysis: Codable {
    let period: DateInterval
    let dominantEmotion: EmotionalState
    let averageIntensity: Double
    let emotionalVolatility: Double // Écart-type des émotions
    let correlationWithPerformance: Double // Corrélation émotion-performance
    let insights: [String]
    
    init(period: DateInterval, dominantEmotion: EmotionalState, averageIntensity: Double, emotionalVolatility: Double, correlationWithPerformance: Double, insights: [String]) {
        self.period = period
        self.dominantEmotion = dominantEmotion
        self.averageIntensity = averageIntensity
        self.emotionalVolatility = emotionalVolatility
        self.correlationWithPerformance = correlationWithPerformance
        self.insights = insights
    }
}



