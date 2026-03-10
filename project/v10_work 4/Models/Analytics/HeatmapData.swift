import Foundation
import SwiftUI

// MARK: - Données de Heatmap
struct HeatmapData: Identifiable, Codable {
    let id: UUID
    let xAxis: String // Symbole, session, système, etc.
    let yAxis: String // Période, heure, etc.
    let value: Double // Performance, P&L, etc.
    let metadata: HeatmapMetadata
    
    init(xAxis: String, yAxis: String, value: Double, metadata: HeatmapMetadata = HeatmapMetadata()) {
        self.id = UUID()
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.value = value
        self.metadata = metadata
    }
}

struct HeatmapMetadata: Codable {
    let tradeCount: Int
    let winRate: Double
    let avgPnL: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    
    init(tradeCount: Int = 0, winRate: Double = 0.0, avgPnL: Double = 0.0, maxDrawdown: Double = 0.0, sharpeRatio: Double? = nil) {
        self.tradeCount = tradeCount
        self.winRate = winRate
        self.avgPnL = avgPnL
        self.maxDrawdown = maxDrawdown
        self.sharpeRatio = sharpeRatio
    }
}

// MARK: - Types de Heatmap
enum HeatmapType: String, CaseIterable {
    case symbol = "symbol"
    case session = "session"
    case system = "system"
    case hour = "hour"
    case dayOfWeek = "day_of_week"
    case month = "month"
    
    var displayName: String {
        switch self {
        case .symbol: return "Par Symbole"
        case .session: return "Par Session"
        case .system: return "Par Système"
        case .hour: return "Par Heure"
        case .dayOfWeek: return "Par Jour de Semaine"
        case .month: return "Par Mois"
        }
    }
    
    var icon: String {
        switch self {
        case .symbol: return "chart.bar"
        case .session: return "globe"
        case .system: return "gear"
        case .hour: return "clock"
        case .dayOfWeek: return "calendar"
        case .month: return "calendar.badge.clock"
        }
    }
}

// MARK: - Configuration de Heatmap
struct HeatmapConfiguration {
    let type: HeatmapType
    let period: DateInterval
    let metric: HeatmapMetric
    let aggregation: HeatmapAggregation
    
    init(type: HeatmapType, period: DateInterval, metric: HeatmapMetric = .pnl, aggregation: HeatmapAggregation = .sum) {
        self.type = type
        self.period = period
        self.metric = metric
        self.aggregation = aggregation
    }
}

enum HeatmapMetric: String, CaseIterable {
    case pnl = "pnl"
    case winRate = "win_rate"
    case tradeCount = "trade_count"
    case sharpeRatio = "sharpe_ratio"
    case maxDrawdown = "max_drawdown"
    case expectancy = "expectancy"
    
    var displayName: String {
        switch self {
        case .pnl: return "P&L"
        case .winRate: return "Win Rate"
        case .tradeCount: return "Nombre de Trades"
        case .sharpeRatio: return "Sharpe Ratio"
        case .maxDrawdown: return "Drawdown Max"
        case .expectancy: return "Expectancy"
        }
    }
    
    var unit: String {
        switch self {
        case .pnl: return "$"
        case .winRate: return "%"
        case .tradeCount: return "trades"
        case .sharpeRatio: return ""
        case .maxDrawdown: return "$"
        case .expectancy: return "$"
        }
    }
}

enum HeatmapAggregation: String, CaseIterable {
    case sum = "sum"
    case average = "average"
    case max = "max"
    case min = "min"
    case count = "count"
    
    var displayName: String {
        switch self {
        case .sum: return "Somme"
        case .average: return "Moyenne"
        case .max: return "Maximum"
        case .min: return "Minimum"
        case .count: return "Comptage"
        }
    }
}

// MARK: - Résultat de Heatmap
struct HeatmapResult {
    let configuration: HeatmapConfiguration
    let data: [HeatmapData]
    let xAxisLabels: [String]
    let yAxisLabels: [String]
    let minValue: Double
    let maxValue: Double
    let insights: [String]
    
    init(configuration: HeatmapConfiguration, data: [HeatmapData], xAxisLabels: [String], yAxisLabels: [String], minValue: Double, maxValue: Double, insights: [String] = []) {
        self.configuration = configuration
        self.data = data
        self.xAxisLabels = xAxisLabels
        self.yAxisLabels = yAxisLabels
        self.minValue = minValue
        self.maxValue = maxValue
        self.insights = insights
    }
    
    // Calculer la couleur basée sur la valeur
    func colorFor(value: Double) -> Color {
        let normalizedValue = (value - minValue) / (maxValue - minValue)
        
        if normalizedValue >= 0.8 {
            return .green
        } else if normalizedValue >= 0.6 {
            return .yellow
        } else if normalizedValue >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
    
    // Obtenir la valeur pour une position donnée
    func valueAt(x: String, y: String) -> Double? {
        return data.first { $0.xAxis == x && $0.yAxis == y }?.value
    }
}

// MARK: - Sessions de Trading
enum TradingSession: String, CaseIterable {
    case asian = "asian"
    case london = "london"
    case newYork = "new_york"
    case overlap = "overlap"
    
    var displayName: String {
        switch self {
        case .asian: return "Asiatique"
        case .london: return "Londres"
        case .newYork: return "New York"
        case .overlap: return "Chevauchement"
        }
    }
    
    var timeRange: String {
        switch self {
        case .asian: return "00:00 - 08:00 UTC"
        case .london: return "08:00 - 16:00 UTC"
        case .newYork: return "13:00 - 21:00 UTC"
        case .overlap: return "13:00 - 16:00 UTC"
        }
    }
    
    var color: String {
        switch self {
        case .asian: return "#FF6B6B"
        case .london: return "#4ECDC4"
        case .newYork: return "#45B7D1"
        case .overlap: return "#96CEB4"
        }
    }
    
    // Déterminer la session basée sur l'heure
    static func sessionFor(time: Date) -> TradingSession {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        
        switch hour {
        case 0..<8:
            return .asian
        case 8..<13:
            return .london
        case 13..<16:
            return .overlap
        case 16..<21:
            return .newYork
        default:
            return .asian
        }
    }
}
