import Foundation
import Combine

protocol MoodStore: ObservableObject {
    var moods: [MoodEntry] { get }
    var moodsPublisher: AnyPublisher<[MoodEntry], Never> { get }
    
    // CRUD Operations
    func addMood(_ mood: MoodEntry) async throws
    func updateMood(_ mood: MoodEntry) async throws
    func deleteMood(_ id: UUID) async throws
    
    // Queries
    func fetchMoodsForTrade(_ tradeId: UUID) async throws -> [MoodEntry]
    func fetchMoodsForPeriod(_ period: DateInterval) async throws -> [MoodEntry]
    func fetchMoodsByEmotion(_ emotion: EmotionalState) async throws -> [MoodEntry]
    func fetchMoodsByContext(_ context: MoodContext) async throws -> [MoodEntry]
    
    // Analytics
    func getEmotionalAnalysis(for period: DateInterval) async throws -> EmotionalAnalysis
    func getEmotionPerformanceCorrelation() async throws -> [EmotionalState: Double]
    func getEmotionalTrends(days: Int) async throws -> [Date: EmotionalState]
    
    // Insights
    func getEmotionalInsights() async throws -> [String]
    func getTiltAlerts() async throws -> [String]
    func getOptimalTradingEmotions() async throws -> [EmotionalState]
}






