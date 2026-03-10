import Foundation
import Combine

class LocalMoodStore: MoodStore, ObservableObject {
    @Published var moods: [MoodEntry] = []
    
    private let database: LocalDatabase
    private var cancellables = Set<AnyCancellable>()
    
    /// Clé UserDefaults pour la persistance locale des moods
    private static let storageKey = "local_mood_entries"
    
    var moodsPublisher: AnyPublisher<[MoodEntry], Never> {
        $moods.eraseToAnyPublisher()
    }
    
    /// Init avec database (utilisé par AppState)
    init(database: LocalDatabase) {
        self.database = database
        loadMoodsFromDisk()
    }
    
    /// Convenience init (pour compatibilité)
    convenience init() {
        self.init(database: LocalDatabase.shared)
    }
    
    // MARK: - Persistence (UserDefaults/JSON)
    
    private func loadMoodsFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            moods = []
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            moods = try decoder.decode([MoodEntry].self, from: data)
            print("✅ [LocalMoodStore] Loaded \(moods.count) moods from disk")
        } catch {
            print("❌ [LocalMoodStore] Failed to decode moods: \(error)")
            moods = []
        }
    }
    
    private func saveMoodsToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(moods)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("❌ [LocalMoodStore] Failed to encode moods: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    func addMood(_ mood: MoodEntry) async throws {
        await MainActor.run {
            moods.append(mood)
            saveMoodsToDisk()
        }
        print("✅ [LocalMoodStore] Mood added: \(mood.emotionalState.rawValue) \(mood.intensity)/10")
    }
    
    func updateMood(_ mood: MoodEntry) async throws {
        await MainActor.run {
            if let index = moods.firstIndex(where: { $0.id == mood.id }) {
                moods[index] = mood
                saveMoodsToDisk()
            }
        }
    }
    
    func deleteMood(_ id: UUID) async throws {
        await MainActor.run {
            moods.removeAll { $0.id == id }
            saveMoodsToDisk()
        }
    }
    
    // MARK: - Queries
    func fetchMoodsForTrade(_ tradeId: UUID) async throws -> [MoodEntry] {
        return moods.filter { $0.tradeId == tradeId }
    }
    
    func fetchMoodsForPeriod(_ period: DateInterval) async throws -> [MoodEntry] {
        return moods.filter { period.contains($0.timestamp) }
    }
    
    func fetchMoodsByEmotion(_ emotion: EmotionalState) async throws -> [MoodEntry] {
        return moods.filter { $0.emotionalState == emotion }
    }
    
    func fetchMoodsByContext(_ context: MoodContext) async throws -> [MoodEntry] {
        return moods.filter { $0.context == context }
    }
    
    // MARK: - Analytics
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
        
        let emotionCounts = Dictionary(grouping: periodMoods, by: { $0.emotionalState })
            .mapValues { $0.count }
        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key ?? .calm
        
        let intensities = periodMoods.map { Double($0.intensity) }
        let averageIntensity = intensities.reduce(0, +) / Double(intensities.count)
        let variance = intensities.map { pow($0 - averageIntensity, 2) }.reduce(0, +) / Double(intensities.count)
        let emotionalVolatility = sqrt(variance)
        
        let positiveEmotions: Set<EmotionalState> = [.confident, .calm, .focused, .excited]
        let positiveRatio = Double(periodMoods.filter { positiveEmotions.contains($0.emotionalState) }.count) / Double(periodMoods.count)
        let correlationWithPerformance = (positiveRatio - 0.5) * 2.0
        
        var insights: [String] = []
        if dominantEmotion == .confident && averageIntensity > 7 {
            insights.append("💪 Tu es dans une zone de confiance optimale")
        }
        if emotionalVolatility > 3 {
            insights.append("📈 Volatilité émotionnelle élevée — attention au risque")
        }
        if correlationWithPerformance > 0.3 {
            insights.append("🎯 Tes émotions influencent positivement tes performances")
        } else if correlationWithPerformance < -0.3 {
            insights.append("⚠️ Tes émotions affectent négativement tes performances")
        }
        
        return EmotionalAnalysis(
            period: period,
            dominantEmotion: dominantEmotion,
            averageIntensity: averageIntensity,
            emotionalVolatility: emotionalVolatility,
            correlationWithPerformance: correlationWithPerformance,
            insights: insights
        )
    }
    
    func getEmotionPerformanceCorrelation() async throws -> [EmotionalState: Double] {
        var correlations: [EmotionalState: Double] = [:]
        for emotion in EmotionalState.allCases {
            let emotionMoods = moods.filter { $0.emotionalState == emotion }
            if !emotionMoods.isEmpty {
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
        let recentMoods = moods.suffix(10)
        var insights: [String] = []
        
        let stressedCount = recentMoods.filter { $0.emotionalState == .stressed }.count
        if stressedCount > 5 {
            insights.append("⚠️ Tu sembles stressé récemment. Prends une pause.")
        }
        
        let confidentCount = recentMoods.filter { $0.emotionalState == .confident }.count
        if confidentCount > 7 {
            insights.append("🎯 Tu es dans une bonne zone de confiance. Continue !")
        }
        
        let frustratedCount = recentMoods.filter { $0.emotionalState == .frustrated }.count
        if frustratedCount > 3 {
            insights.append("😤 Frustration détectée. Évite de trader sur émotion.")
        }
        
        if insights.isEmpty {
            insights.append("📊 Continue à noter tes émotions pour enrichir l'analyse.")
        }
        
        return insights
    }
    
    func getTiltAlerts() async throws -> [String] {
        var alerts: [String] = []
        let recentMoods = moods.suffix(5)
        let negativeEmotions: [EmotionalState] = [.stressed, .frustrated, .fearful, .impatient]
        let negativeCount = recentMoods.filter { negativeEmotions.contains($0.emotionalState) }.count
        
        if negativeCount >= 3 {
            alerts.append("🚨 ALERTE TILT : Émotions négatives détectées. Arrête de trader.")
        }
        
        let highIntensityCount = recentMoods.filter { $0.intensity >= 8 }.count
        if highIntensityCount >= 3 {
            alerts.append("⚡ Intensité émotionnelle élevée. Risque de sur-trading.")
        }
        
        return alerts
    }
    
    func getOptimalTradingEmotions() async throws -> [EmotionalState] {
        return [.calm, .focused, .confident]
    }
}

// MARK: - LocalDatabase Extension
extension LocalDatabase {
    func saveMood(_ mood: MoodEntry) async throws {
        // Handled by LocalMoodStore directly via UserDefaults
    }
    
    func updateMood(_ mood: MoodEntry) async throws {
        // Handled by LocalMoodStore directly via UserDefaults
    }
    
    func deleteMood(_ id: UUID) async throws {
        // Handled by LocalMoodStore directly via UserDefaults
    }
}
