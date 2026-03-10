//
//  FirestoreMoodStore.swift
//  Journal de trading 2025
//
//  Store Firestore pour les entrées émotionnelles (MoodEntry).
//  Suit le même pattern que FirestoreTradeStore.
//

import Foundation
import Combine

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth

final class FirestoreMoodStore: MoodStore, ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var moods: [MoodEntry] = []
    
    var moodsPublisher: AnyPublisher<[MoodEntry], Never> {
        $moods.eraseToAnyPublisher()
    }
    
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserId: String?
    
    init() {
        startAuthListener()
    }
    
    deinit {
        listener?.remove()
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }
    
    // MARK: - Auth
    
    private func startAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            let newUid = user?.uid
            if newUid != self.currentUserId {
                self.currentUserId = newUid
                self.restartListener()
            }
        }
        currentUserId = Auth.auth().currentUser?.uid
        restartListener()
    }
    
    private func restartListener() {
        listener?.remove()
        listener = nil
        
        guard let userId = currentUserId else {
            moods = []
            return
        }
        
        listener = moodsCollection(userId: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard let snapshot else {
                    print("❌ [FirestoreMoodStore] Error fetching moods: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                let decoded = snapshot.documents.compactMap { self.decodeMood(from: $0.data(), id: $0.documentID) }
                DispatchQueue.main.async {
                    self.moods = decoded
                }
            }
    }
    
    private func moodsCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("moods")
    }
    
    private func requireUserId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreMoodStoreError.notAuthenticated
        }
        return uid
    }
    
    // MARK: - CRUD
    
    func addMood(_ mood: MoodEntry) async throws {
        let userId = try requireUserId()
        let docRef = moodsCollection(userId: userId).document(mood.id.uuidString)
        try await docRef.setData(encodeMood(mood))
        print("✅ [FirestoreMoodStore] Mood saved: \(mood.emotionalState.rawValue) \(mood.intensity)/10")
    }
    
    func updateMood(_ mood: MoodEntry) async throws {
        let userId = try requireUserId()
        let docRef = moodsCollection(userId: userId).document(mood.id.uuidString)
        try await docRef.setData(encodeMood(mood), merge: true)
    }
    
    func deleteMood(_ id: UUID) async throws {
        let userId = try requireUserId()
        try await moodsCollection(userId: userId).document(id.uuidString).delete()
    }
    
    // MARK: - Queries
    
    func fetchMoodsForTrade(_ tradeId: UUID) async throws -> [MoodEntry] {
        let userId = try requireUserId()
        let snapshot = try await moodsCollection(userId: userId)
            .whereField("tradeId", isEqualTo: tradeId.uuidString)
            .getDocuments()
        return snapshot.documents.compactMap { decodeMood(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchMoodsForPeriod(_ period: DateInterval) async throws -> [MoodEntry] {
        let userId = try requireUserId()
        let snapshot = try await moodsCollection(userId: userId)
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: period.start))
            .whereField("timestamp", isLessThanOrEqualTo: Timestamp(date: period.end))
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { decodeMood(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchMoodsByEmotion(_ emotion: EmotionalState) async throws -> [MoodEntry] {
        let userId = try requireUserId()
        let snapshot = try await moodsCollection(userId: userId)
            .whereField("emotionalState", isEqualTo: emotion.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { decodeMood(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchMoodsByContext(_ context: MoodContext) async throws -> [MoodEntry] {
        let userId = try requireUserId()
        let snapshot = try await moodsCollection(userId: userId)
            .whereField("context", isEqualTo: context.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { decodeMood(from: $0.data(), id: $0.documentID) }
    }
    
    // MARK: - Analytics (computed from local cache for perf)
    
    func getEmotionalAnalysis(for period: DateInterval) async throws -> EmotionalAnalysis {
        let periodMoods = moods.filter { period.contains($0.timestamp) }
        
        guard !periodMoods.isEmpty else {
            return EmotionalAnalysis(
                period: period,
                dominantEmotion: .calm,
                averageIntensity: 5.0,
                emotionalVolatility: 0.0,
                correlationWithPerformance: 0.0,
                insights: ["Aucune donnée émotionnelle pour cette période"]
            )
        }
        
        let emotionCounts = Dictionary(grouping: periodMoods, by: { $0.emotionalState }).mapValues { $0.count }
        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key ?? .calm
        
        let intensities = periodMoods.map { Double($0.intensity) }
        let averageIntensity = intensities.reduce(0, +) / Double(intensities.count)
        let variance = intensities.map { pow($0 - averageIntensity, 2) }.reduce(0, +) / Double(intensities.count)
        let volatility = sqrt(variance)
        
        let positiveEmotions: Set<EmotionalState> = [.confident, .calm, .focused, .excited]
        let positiveRatio = Double(periodMoods.filter { positiveEmotions.contains($0.emotionalState) }.count) / Double(periodMoods.count)
        let correlation = (positiveRatio - 0.5) * 2.0 // Simplified
        
        var insights: [String] = []
        if dominantEmotion == .confident && averageIntensity > 7 {
            insights.append("💪 Zone de confiance optimale")
        }
        if volatility > 3 {
            insights.append("📈 Volatilité émotionnelle élevée — attention au risque")
        }
        
        return EmotionalAnalysis(
            period: period,
            dominantEmotion: dominantEmotion,
            averageIntensity: averageIntensity,
            emotionalVolatility: volatility,
            correlationWithPerformance: correlation,
            insights: insights
        )
    }
    
    func getEmotionPerformanceCorrelation() async throws -> [EmotionalState: Double] {
        var correlations: [EmotionalState: Double] = [:]
        for emotion in EmotionalState.allCases {
            let count = moods.filter { $0.emotionalState == emotion }.count
            if count > 0 {
                correlations[emotion] = emotion.valenceScore
            }
        }
        return correlations
    }
    
    func getEmotionalTrends(days: Int) async throws -> [Date: EmotionalState] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let periodMoods = moods.filter { $0.timestamp >= startDate }
        
        return Dictionary(grouping: periodMoods) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }.mapValues { dayMoods in
            Dictionary(grouping: dayMoods, by: { $0.emotionalState })
                .mapValues { $0.count }
                .max(by: { $0.value < $1.value })?.key ?? .calm
        }
    }
    
    // MARK: - Insights
    
    func getEmotionalInsights() async throws -> [String] {
        let recent = moods.prefix(10)
        var insights: [String] = []
        
        let stressedCount = recent.filter { $0.emotionalState == .stressed }.count
        if stressedCount > 5 { insights.append("⚠️ Tu sembles stressé récemment. Prends une pause.") }
        
        let confidentCount = recent.filter { $0.emotionalState == .confident }.count
        if confidentCount > 7 { insights.append("🎯 Bonne zone de confiance. Continue !") }
        
        let frustratedCount = recent.filter { $0.emotionalState == .frustrated }.count
        if frustratedCount > 3 { insights.append("😤 Frustration détectée. Évite de trader sur émotion.") }
        
        if insights.isEmpty {
            insights.append("📊 Continue à noter tes émotions pour enrichir l'analyse.")
        }
        
        return insights
    }
    
    func getTiltAlerts() async throws -> [String] {
        var alerts: [String] = []
        let recent = moods.prefix(5)
        let negativeEmotions: [EmotionalState] = [.stressed, .frustrated, .fearful, .impatient]
        let negativeCount = recent.filter { negativeEmotions.contains($0.emotionalState) }.count
        
        if negativeCount >= 3 {
            alerts.append("🚨 ALERTE TILT : Émotions négatives détectées. Arrête de trader.")
        }
        
        let highIntensityCount = recent.filter { $0.intensity >= 8 }.count
        if highIntensityCount >= 3 {
            alerts.append("⚡ Intensité émotionnelle élevée. Risque de sur-trading.")
        }
        
        return alerts
    }
    
    func getOptimalTradingEmotions() async throws -> [EmotionalState] {
        return [.calm, .focused, .confident]
    }
    
    // MARK: - Encode / Decode
    
    private func encodeMood(_ mood: MoodEntry) -> [String: Any] {
        var data: [String: Any] = [
            "id": mood.id.uuidString,
            "emotionalState": mood.emotionalState.rawValue,
            "intensity": mood.intensity,
            "timestamp": Timestamp(date: mood.timestamp),
            "context": mood.context.rawValue,
            "tags": mood.tags,
            "isExceptional": mood.isExceptional,
            "source": mood.source.rawValue
        ]
        
        if let tradeId = mood.tradeId { data["tradeId"] = tradeId.uuidString }
        if let notes = mood.notes { data["notes"] = notes }
        if let duration = mood.durationCategory { data["durationCategory"] = duration.rawValue }
        if let secondary = mood.secondaryEmotionalState { data["secondaryEmotionalState"] = secondary.rawValue }
        if let trigger = mood.trigger { data["trigger"] = trigger.rawValue }
        if let control = mood.controlLevel { data["controlLevel"] = control }
        if let intention = mood.intention { data["intention"] = intention.rawValue }
        if let aiSummary = mood.aiSummary { data["aiSummary"] = aiSummary }
        if let aiSignals = mood.aiSignals { data["aiSignals"] = aiSignals }
        
        // Checklist before trade
        if mood.context == .beforeTrade, let checklist = mood.checklistBeforeTrade {
            data["checklistBeforeTrade"] = [
                "planClear": checklist.planClear,
                "stopDefined": checklist.stopDefined,
                "riskAccepted": checklist.riskAccepted,
                "noRevenge": checklist.noRevenge,
                "noUrgency": checklist.noUrgency
            ]
        }
        
        // Mini checklist
        if mood.context == .beforeTrade, let mini = mood.miniChecklist {
            data["miniChecklist"] = [
                "planOK": mini.planOK,
                "sizeOK": mini.sizeOK,
                "stopDefined": mini.stopDefined
            ]
        }
        
        // Quick actions
        if !mood.quickActions.isEmpty {
            data["quickActions"] = mood.quickActions.map { event in
                [
                    "id": event.id.uuidString,
                    "action": event.action.rawValue,
                    "timestamp": Timestamp(date: event.timestamp)
                ] as [String: Any]
            }
        }
        
        return data
    }
    
    private func decodeMood(from data: [String: Any], id: String) -> MoodEntry? {
        guard
            let uuid = UUID(uuidString: id),
            let emotionalStateRaw = data["emotionalState"] as? String,
            let emotionalState = EmotionalState(rawValue: emotionalStateRaw),
            let intensity = data["intensity"] as? Int,
            let timestampTs = data["timestamp"] as? Timestamp,
            let contextRaw = data["context"] as? String,
            let context = MoodContext(rawValue: contextRaw)
        else {
            print("❌ [FirestoreMoodStore] Failed to decode mood \(id)")
            return nil
        }
        
        let tradeId: UUID? = (data["tradeId"] as? String).flatMap { UUID(uuidString: $0) }
        let notes = data["notes"] as? String
        let tags = data["tags"] as? [String] ?? []
        let isExceptional = data["isExceptional"] as? Bool ?? false
        let sourceRaw = data["source"] as? String ?? EntrySource.manual.rawValue
        let source = EntrySource(rawValue: sourceRaw) ?? .manual
        
        let durationRaw = data["durationCategory"] as? String
        let durationCategory = durationRaw.flatMap { MoodDurationCategory(rawValue: $0) }
        
        let secondaryRaw = data["secondaryEmotionalState"] as? String
        let secondaryEmotionalState = secondaryRaw.flatMap { EmotionalState(rawValue: $0) }
        
        let triggerRaw = data["trigger"] as? String
        let trigger = triggerRaw.flatMap { MoodTrigger(rawValue: $0) }
        
        let controlLevel = data["controlLevel"] as? Int
        
        let intentionRaw = data["intention"] as? String
        let intention = intentionRaw.flatMap { MoodIntention(rawValue: $0) }
        
        let aiSummary = data["aiSummary"] as? String
        let aiSignals = data["aiSignals"] as? [String]
        
        // Decode checklist
        var checklistBeforeTrade: ChecklistBeforeTrade? = nil
        if context == .beforeTrade, let checklistData = data["checklistBeforeTrade"] as? [String: Bool] {
            checklistBeforeTrade = ChecklistBeforeTrade(
                planClear: checklistData["planClear"] ?? false,
                stopDefined: checklistData["stopDefined"] ?? false,
                riskAccepted: checklistData["riskAccepted"] ?? false,
                noRevenge: checklistData["noRevenge"] ?? false,
                noUrgency: checklistData["noUrgency"] ?? false
            )
        }
        
        // Decode mini checklist
        var miniChecklist: MiniPreTradeChecklist? = nil
        if context == .beforeTrade, let miniData = data["miniChecklist"] as? [String: Bool] {
            miniChecklist = MiniPreTradeChecklist(
                planOK: miniData["planOK"] ?? false,
                sizeOK: miniData["sizeOK"] ?? false,
                stopDefined: miniData["stopDefined"] ?? false
            )
        }
        
        // Decode quick actions
        var quickActions: [MoodQuickActionEvent] = []
        if let actionsArray = data["quickActions"] as? [[String: Any]] {
            quickActions = actionsArray.compactMap { actionData in
                guard
                    let idStr = actionData["id"] as? String,
                    let actionId = UUID(uuidString: idStr),
                    let actionRaw = actionData["action"] as? String,
                    let action = MoodQuickAction(rawValue: actionRaw),
                    let ts = actionData["timestamp"] as? Timestamp
                else { return nil }
                return MoodQuickActionEvent(action: action, timestamp: ts.dateValue(), id: actionId)
            }
        }
        
        return MoodEntry(
            id: uuid,
            tradeId: tradeId,
            emotionalState: emotionalState,
            intensity: intensity,
            notes: notes,
            timestamp: timestampTs.dateValue(),
            context: context,
            durationCategory: durationCategory,
            secondaryEmotionalState: secondaryEmotionalState,
            trigger: trigger,
            controlLevel: controlLevel,
            checklistBeforeTrade: checklistBeforeTrade,
            tags: tags,
            isExceptional: isExceptional,
            intention: intention,
            aiSummary: aiSummary,
            aiSignals: aiSignals,
            source: source,
            miniChecklist: miniChecklist,
            quickActions: quickActions
        )
    }
}

enum FirestoreMoodStoreError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Utilisateur non authentifié"
        }
    }
}
#endif
