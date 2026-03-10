import Foundation
import Combine

// MARK: - Dashboard Analytics Cache

@MainActor
final class DashboardAnalyticsCache: ObservableObject {
    
    @Published private(set) var pnlHeatmapByPeriod: [DashboardHeatmapPeriod: [[DashboardHeatmapCell]]] = [:]
    @Published private(set) var emotionalHeatmapByPeriod: [DashboardHeatmapPeriod: [[DashboardHeatmapCell]]] = [:]
    
    @Published private(set) var pnlCurve: [DashboardCurvePoint] = []
    @Published private(set) var emotionalCurve: [DashboardCurvePoint] = []
    @Published private(set) var pnlCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
    @Published private(set) var emotionalCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
    @Published private(set) var normalizedPnLCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
    @Published private(set) var normalizedEmotionalCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
    @Published private(set) var weightedPnlCurve: [DashboardCurvePoint] = []
    @Published private(set) var pnlBarsByRange: [CurveTimeRange: [DashboardBarPoint]] = [:]
    
    // ✅ Precomputed domains (Views must not compute min/max/padding)
    @Published private(set) var pnlCurveYDomain: ClosedRange<Double> = (-100)...(100)
    @Published private(set) var pnlCurveYDomainByRange: [CurveTimeRange: ClosedRange<Double>] = [:]
    @Published private(set) var pnlAxisTickCountByRange: [CurveTimeRange: Int] = [:]
    @Published private(set) var weightedPnlCurveYDomain: ClosedRange<Double> = (-100)...(100)
    @Published private(set) var emotionalCurveYDomain: ClosedRange<Double> = 0...100
    @Published private(set) var xAxisStrideByRange: [CurveTimeRange: Int] = [:]
    @Published private(set) var xAxisUnitByRange: [CurveTimeRange: CurveXAxisUnit] = [:]
    @Published private(set) var displayDateRangeByRange: [CurveTimeRange: CurveDateRange] = [:]
    
    @Published private(set) var pnlInsightsByRange: [CurveTimeRange: [CurveInsight]] = [:]
    @Published private(set) var emotionalInsightsByRange: [CurveTimeRange: [CurveInsight]] = [:]
    @Published private(set) var correlationInsightsByRange: [CurveTimeRange: [CurveInsight]] = [:]
    
    @Published private(set) var isReady: Bool = false
    
    func rebuild(
        trades: [Trade],
        moodEntries: [MoodEntry],
        emotionalLoadByDay: [Date: Double],
        language: Localizable.Language = LanguageManager.shared.currentLanguage
    ) {
        Task.detached(priority: .utility) {
            let result = DashboardAnalyticsCompute.compute(
                trades: trades,
                moodEntries: moodEntries,
                emotionalLoadByDay: emotionalLoadByDay,
                language: language
            )

            await MainActor.run {
                self.pnlHeatmapByPeriod = result.pnlHeatmap
                self.emotionalHeatmapByPeriod = result.emotionalHeatmap
                self.pnlCurve = result.pnlCurve
                self.emotionalCurve = result.emotionalCurve
                self.pnlCurveByRange = result.pnlCurveByRange
                self.emotionalCurveByRange = result.emotionalCurveByRange
                self.normalizedPnLCurveByRange = result.normalizedPnLCurveByRange
                self.normalizedEmotionalCurveByRange = result.normalizedEmotionalCurveByRange
                self.weightedPnlCurve = result.weightedPnlCurve
                self.pnlBarsByRange = result.pnlBarsByRange
                self.pnlCurveYDomain = result.pnlYDomain
                self.pnlCurveYDomainByRange = result.pnlYDomainByRange
                self.pnlAxisTickCountByRange = result.pnlAxisTickCountByRange
                self.weightedPnlCurveYDomain = result.weightedPnlYDomain
                self.emotionalCurveYDomain = result.emotionalYDomain
                self.xAxisStrideByRange = result.xAxisStrideByRange
                self.xAxisUnitByRange = result.xAxisUnitByRange
                self.displayDateRangeByRange = result.displayDateRangeByRange
                self.pnlInsightsByRange = result.pnlInsightsByRange
                self.emotionalInsightsByRange = result.emotionalInsightsByRange
                self.correlationInsightsByRange = result.correlationInsightsByRange
                self.isReady = true
            }
        }
    }
}
