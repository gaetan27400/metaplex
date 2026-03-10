import Foundation
import Combine

class HeatmapService: ObservableObject {
    private let tradeStore: TradeStore
    private let systemStore: SystemStore
    
    init(tradeStore: TradeStore, systemStore: SystemStore) {
        self.tradeStore = tradeStore
        self.systemStore = systemStore
    }
    
    // MARK: - Génération de Heatmap
    func generateHeatmap(configuration: HeatmapConfiguration) async throws -> HeatmapResult {
        let trades = try await tradeStore.fetchTrades(for: configuration.period)
        let systems = try await systemStore.fetchSystems()
        
        switch configuration.type {
        case .symbol:
            return try await generateSymbolHeatmap(trades: trades, configuration: configuration)
        case .session:
            return try await generateSessionHeatmap(trades: trades, configuration: configuration)
        case .system:
            return try await generateSystemHeatmap(trades: trades, systems: systems, configuration: configuration)
        case .hour:
            return try await generateHourHeatmap(trades: trades, configuration: configuration)
        case .dayOfWeek:
            return try await generateDayOfWeekHeatmap(trades: trades, configuration: configuration)
        case .month:
            return try await generateMonthHeatmap(trades: trades, configuration: configuration)
        }
    }
    
    // MARK: - Heatmap par Symbole
    private func generateSymbolHeatmap(trades: [Trade], configuration: HeatmapConfiguration) async throws -> HeatmapResult {
        let symbols = Set(trades.map { $0.symbol }).sorted()
        let months = generateMonthLabels(for: configuration.period)
        
        var data: [HeatmapData] = []
        var symbolStats: [String: [String: Double]] = [:]
        
        // Grouper les trades par symbole et mois
        for trade in trades {
            let month = monthLabel(for: trade.entryDate)
            let symbol = trade.symbol
            
            if symbolStats[symbol] == nil {
                symbolStats[symbol] = [:]
            }
            
            let currentValue = symbolStats[symbol]?[month] ?? 0.0
            let tradeValue = calculateTradeValue(trade: trade, metric: configuration.metric)
            
            switch configuration.aggregation {
            case .sum:
                symbolStats[symbol]?[month] = currentValue + tradeValue
            case .average:
                // Pour l'instant, on fait une moyenne simple
                symbolStats[symbol]?[month] = (currentValue + tradeValue) / 2
            case .max:
                symbolStats[symbol]?[month] = max(currentValue, tradeValue)
            case .min:
                symbolStats[symbol]?[month] = min(currentValue, tradeValue)
            case .count:
                symbolStats[symbol]?[month] = currentValue + 1
            }
        }
        
        // Créer les données de heatmap
        for symbol in symbols {
            for month in months {
                let value = symbolStats[symbol]?[month] ?? 0.0
                let metadata = generateMetadata(for: trades.filter { $0.symbol == symbol && monthLabel(for: $0.entryDate) == month })
                
                data.append(HeatmapData(
                    xAxis: symbol,
                    yAxis: month,
                    value: value,
                    metadata: metadata
                ))
            }
        }
        
        let minValue = data.map { $0.value }.min() ?? 0.0
        let maxValue = data.map { $0.value }.max() ?? 0.0
        let insights = generateSymbolInsights(data: data, symbols: symbols)
        
        return HeatmapResult(
            configuration: configuration,
            data: data,
            xAxisLabels: symbols,
            yAxisLabels: months,
            minValue: minValue,
            maxValue: maxValue,
            insights: insights
        )
    }
    
    // MARK: - Heatmap par Session
    private func generateSessionHeatmap(trades: [Trade], configuration: HeatmapConfiguration) async throws -> HeatmapResult {
        let sessions = TradingSession.allCases
        let daysOfWeek = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
        
        var data: [HeatmapData] = []
        var sessionStats: [String: [String: Double]] = [:]
        
        // Grouper les trades par session et jour de semaine
        for trade in trades {
            let session = TradingSession.sessionFor(time: trade.entryDate)
            let dayOfWeek = dayOfWeekLabel(for: trade.entryDate)
            
            if sessionStats[session.rawValue] == nil {
                sessionStats[session.rawValue] = [:]
            }
            
            let currentValue = sessionStats[session.rawValue]?[dayOfWeek] ?? 0.0
            let tradeValue = calculateTradeValue(trade: trade, metric: configuration.metric)
            
            switch configuration.aggregation {
            case .sum:
                sessionStats[session.rawValue]?[dayOfWeek] = currentValue + tradeValue
            case .average:
                sessionStats[session.rawValue]?[dayOfWeek] = (currentValue + tradeValue) / 2
            case .max:
                sessionStats[session.rawValue]?[dayOfWeek] = max(currentValue, tradeValue)
            case .min:
                sessionStats[session.rawValue]?[dayOfWeek] = min(currentValue, tradeValue)
            case .count:
                sessionStats[session.rawValue]?[dayOfWeek] = currentValue + 1
            }
        }
        
        // Créer les données de heatmap
        for session in sessions {
            for day in daysOfWeek {
                let value = sessionStats[session.rawValue]?[day] ?? 0.0
                let metadata = generateMetadata(for: trades.filter { 
                    TradingSession.sessionFor(time: $0.entryDate) == session && 
                    dayOfWeekLabel(for: $0.entryDate) == day 
                })
                
                data.append(HeatmapData(
                    xAxis: session.displayName,
                    yAxis: day,
                    value: value,
                    metadata: metadata
                ))
            }
        }
        
        let minValue = data.map { $0.value }.min() ?? 0.0
        let maxValue = data.map { $0.value }.max() ?? 0.0
        let insights = generateSessionInsights(data: data, sessions: sessions)
        
        return HeatmapResult(
            configuration: configuration,
            data: data,
            xAxisLabels: sessions.map { $0.displayName },
            yAxisLabels: daysOfWeek,
            minValue: minValue,
            maxValue: maxValue,
            insights: insights
        )
    }
    
    // MARK: - Heatmap par Système
    private func generateSystemHeatmap(trades: [Trade], systems: [TradingSystem], configuration: HeatmapConfiguration) async throws -> HeatmapResult {
        let systemNames = systems.map { $0.name }
        let months = generateMonthLabels(for: configuration.period)
        
        var data: [HeatmapData] = []
        var systemStats: [String: [String: Double]] = [:]
        
        // Grouper les trades par système et mois
        for trade in trades {
            guard let system = systems.first(where: { $0.id == trade.systemId }) else { continue }
            let month = monthLabel(for: trade.entryDate)
            
            if systemStats[system.name] == nil {
                systemStats[system.name] = [:]
            }
            
            let currentValue = systemStats[system.name]?[month] ?? 0.0
            let tradeValue = calculateTradeValue(trade: trade, metric: configuration.metric)
            
            switch configuration.aggregation {
            case .sum:
                systemStats[system.name]?[month] = currentValue + tradeValue
            case .average:
                systemStats[system.name]?[month] = (currentValue + tradeValue) / 2
            case .max:
                systemStats[system.name]?[month] = max(currentValue, tradeValue)
            case .min:
                systemStats[system.name]?[month] = min(currentValue, tradeValue)
            case .count:
                systemStats[system.name]?[month] = currentValue + 1
            }
        }
        
        // Créer les données de heatmap
        for systemName in systemNames {
            for month in months {
                let value = systemStats[systemName]?[month] ?? 0.0
                let metadata = generateMetadata(for: trades.filter { trade in
                    systems.first(where: { $0.id == trade.systemId })?.name == systemName && 
                    monthLabel(for: trade.entryDate) == month 
                })
                
                data.append(HeatmapData(
                    xAxis: systemName,
                    yAxis: month,
                    value: value,
                    metadata: metadata
                ))
            }
        }
        
        let minValue = data.map { $0.value }.min() ?? 0.0
        let maxValue = data.map { $0.value }.max() ?? 0.0
        let insights = generateSystemInsights(data: data, systems: systems)
        
        return HeatmapResult(
            configuration: configuration,
            data: data,
            xAxisLabels: systemNames,
            yAxisLabels: months,
            minValue: minValue,
            maxValue: maxValue,
            insights: insights
        )
    }
    
    // MARK: - Heatmap par Heure
    private func generateHourHeatmap(trades: [Trade], configuration: HeatmapConfiguration) async throws -> HeatmapResult {
        let hours = Array(0...23).map { String(format: "%02d:00", $0) }
        let daysOfWeek = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
        
        var data: [HeatmapData] = []
        var hourStats: [String: [String: Double]] = [:]
        
        // Grouper les trades par heure et jour de semaine
        for trade in trades {
            let hour = hourLabel(for: trade.entryDate)
            let dayOfWeek = dayOfWeekLabel(for: trade.entryDate)
            
            if hourStats[hour] == nil {
                hourStats[hour] = [:]
            }
            
            let currentValue = hourStats[hour]?[dayOfWeek] ?? 0.0
            let tradeValue = calculateTradeValue(trade: trade, metric: configuration.metric)
            
            switch configuration.aggregation {
            case .sum:
                hourStats[hour]?[dayOfWeek] = currentValue + tradeValue
            case .average:
                hourStats[hour]?[dayOfWeek] = (currentValue + tradeValue) / 2
            case .max:
                hourStats[hour]?[dayOfWeek] = max(currentValue, tradeValue)
            case .min:
                hourStats[hour]?[dayOfWeek] = min(currentValue, tradeValue)
            case .count:
                hourStats[hour]?[dayOfWeek] = currentValue + 1
            }
        }
        
        // Créer les données de heatmap
        for hour in hours {
            for day in daysOfWeek {
                let value = hourStats[hour]?[day] ?? 0.0
                let metadata = generateMetadata(for: trades.filter { 
                    hourLabel(for: $0.entryDate) == hour && 
                    dayOfWeekLabel(for: $0.entryDate) == day 
                })
                
                data.append(HeatmapData(
                    xAxis: hour,
                    yAxis: day,
                    value: value,
                    metadata: metadata
                ))
            }
        }
        
        let minValue = data.map { $0.value }.min() ?? 0.0
        let maxValue = data.map { $0.value }.max() ?? 0.0
        let insights = generateHourInsights(data: data)
        
        return HeatmapResult(
            configuration: configuration,
            data: data,
            xAxisLabels: hours,
            yAxisLabels: daysOfWeek,
            minValue: minValue,
            maxValue: maxValue,
            insights: insights
        )
    }
    
    // MARK: - Heatmap par Jour de Semaine
    private func generateDayOfWeekHeatmap(trades: [Trade], configuration: HeatmapConfiguration) async throws -> HeatmapResult {
        let daysOfWeek = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
        let hours = Array(0...23).map { String(format: "%02d:00", $0) }
        
        var data: [HeatmapData] = []
        var dayStats: [String: [String: Double]] = [:]
        
        // Grouper les trades par jour de semaine et heure
        for trade in trades {
            let dayOfWeek = dayOfWeekLabel(for: trade.entryDate)
            let hour = hourLabel(for: trade.entryDate)
            
            if dayStats[dayOfWeek] == nil {
                dayStats[dayOfWeek] = [:]
            }
            
            let currentValue = dayStats[dayOfWeek]?[hour] ?? 0.0
            let tradeValue = calculateTradeValue(trade: trade, metric: configuration.metric)
            
            switch configuration.aggregation {
            case .sum:
                dayStats[dayOfWeek]?[hour] = currentValue + tradeValue
            case .average:
                dayStats[dayOfWeek]?[hour] = (currentValue + tradeValue) / 2
            case .max:
                dayStats[dayOfWeek]?[hour] = max(currentValue, tradeValue)
            case .min:
                dayStats[dayOfWeek]?[hour] = min(currentValue, tradeValue)
            case .count:
                dayStats[dayOfWeek]?[hour] = currentValue + 1
            }
        }
        
        // Créer les données de heatmap
        for day in daysOfWeek {
            for hour in hours {
                let value = dayStats[day]?[hour] ?? 0.0
                let metadata = generateMetadata(for: trades.filter { 
                    dayOfWeekLabel(for: $0.entryDate) == day && 
                    hourLabel(for: $0.entryDate) == hour 
                })
                
                data.append(HeatmapData(
                    xAxis: day,
                    yAxis: hour,
                    value: value,
                    metadata: metadata
                ))
            }
        }
        
        let minValue = data.map { $0.value }.min() ?? 0.0
        let maxValue = data.map { $0.value }.max() ?? 0.0
        let insights = generateDayOfWeekInsights(data: data)
        
        return HeatmapResult(
            configuration: configuration,
            data: data,
            xAxisLabels: daysOfWeek,
            yAxisLabels: hours,
            minValue: minValue,
            maxValue: maxValue,
            insights: insights
        )
    }
    
    // MARK: - Heatmap par Mois
    private func generateMonthHeatmap(trades: [Trade], configuration: HeatmapConfiguration) async throws -> HeatmapResult {
        let months = generateMonthLabels(for: configuration.period)
        let symbols = Set(trades.map { $0.symbol }).sorted()
        
        var data: [HeatmapData] = []
        var monthStats: [String: [String: Double]] = [:]
        
        // Grouper les trades par mois et symbole
        for trade in trades {
            let month = monthLabel(for: trade.entryDate)
            let symbol = trade.symbol
            
            if monthStats[month] == nil {
                monthStats[month] = [:]
            }
            
            let currentValue = monthStats[month]?[symbol] ?? 0.0
            let tradeValue = calculateTradeValue(trade: trade, metric: configuration.metric)
            
            switch configuration.aggregation {
            case .sum:
                monthStats[month]?[symbol] = currentValue + tradeValue
            case .average:
                monthStats[month]?[symbol] = (currentValue + tradeValue) / 2
            case .max:
                monthStats[month]?[symbol] = max(currentValue, tradeValue)
            case .min:
                monthStats[month]?[symbol] = min(currentValue, tradeValue)
            case .count:
                monthStats[month]?[symbol] = currentValue + 1
            }
        }
        
        // Créer les données de heatmap
        for month in months {
            for symbol in symbols {
                let value = monthStats[month]?[symbol] ?? 0.0
                let metadata = generateMetadata(for: trades.filter { 
                    monthLabel(for: $0.entryDate) == month && 
                    $0.symbol == symbol 
                })
                
                data.append(HeatmapData(
                    xAxis: month,
                    yAxis: symbol,
                    value: value,
                    metadata: metadata
                ))
            }
        }
        
        let minValue = data.map { $0.value }.min() ?? 0.0
        let maxValue = data.map { $0.value }.max() ?? 0.0
        let insights = generateMonthInsights(data: data, months: months)
        
        return HeatmapResult(
            configuration: configuration,
            data: data,
            xAxisLabels: months,
            yAxisLabels: symbols,
            minValue: minValue,
            maxValue: maxValue,
            insights: insights
        )
    }
    
    // MARK: - Helper Methods
    private func calculateTradeValue(trade: Trade, metric: HeatmapMetric) -> Double {
        switch metric {
        case .pnl:
            return trade.pnl
        case .winRate:
            return trade.pnl > 0 ? 1.0 : 0.0
        case .tradeCount:
            return 1.0
        case .sharpeRatio:
            // Calcul simplifié - en réalité, il faudrait calculer le vrai Sharpe ratio
            let quantity = trade.quantity ?? 0.0
            let entryPrice = trade.entryPrice ?? 0.0
            return trade.pnl / max(quantity * entryPrice, 1.0)
        case .maxDrawdown:
            return trade.pnl < 0 ? abs(trade.pnl) : 0.0
        case .expectancy:
            return trade.pnl
        }
    }
    
    private func generateMetadata(for trades: [Trade]) -> HeatmapMetadata {
        guard !trades.isEmpty else {
            return HeatmapMetadata()
        }
        
        let tradeCount = trades.count
        let winCount = trades.filter { $0.pnl > 0 }.count
        let winRate = Double(winCount) / Double(tradeCount)
        let avgPnL = trades.map { $0.pnl }.reduce(0, +) / Double(tradeCount)
        let maxDrawdown = trades.map { $0.pnl }.min() ?? 0.0
        
        return HeatmapMetadata(
            tradeCount: tradeCount,
            winRate: winRate,
            avgPnL: avgPnL,
            maxDrawdown: abs(maxDrawdown)
        )
    }
    
    private func generateMonthLabels(for period: DateInterval) -> [String] {
        let calendar = Calendar.current
        var months: [String] = []
        var currentDate = period.start
        
        while currentDate <= period.end {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            months.append(formatter.string(from: currentDate))
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return months
    }
    
    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func dayOfWeekLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private func hourLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00"
        return formatter.string(from: date)
    }
    
    // MARK: - Insights Generation
    private func generateSymbolInsights(data: [HeatmapData], symbols: [String]) -> [String] {
        var insights: [String] = []
        
        // Trouver le symbole le plus performant
        let symbolPerformance = Dictionary(grouping: data, by: { $0.xAxis })
            .mapValues { $0.map { $0.value }.reduce(0, +) }
        
        if let bestSymbol = symbolPerformance.max(by: { $0.value < $1.value }) {
            insights.append("🏆 \(bestSymbol.key) est ton symbole le plus performant")
        }
        
        // Trouver le symbole le moins performant
        if let worstSymbol = symbolPerformance.min(by: { $0.value < $1.value }) {
            insights.append("⚠️ \(worstSymbol.key) nécessite une attention particulière")
        }
        
        return insights
    }
    
    private func generateSessionInsights(data: [HeatmapData], sessions: [TradingSession]) -> [String] {
        var insights: [String] = []
        
        // Analyser les performances par session
        let sessionPerformance = Dictionary(grouping: data, by: { $0.xAxis })
            .mapValues { $0.map { $0.value }.reduce(0, +) }
        
        if let bestSession = sessionPerformance.max(by: { $0.value < $1.value }) {
            insights.append("⏰ Tu performs mieux pendant la session \(bestSession.key)")
        }
        
        return insights
    }
    
    private func generateSystemInsights(data: [HeatmapData], systems: [TradingSystem]) -> [String] {
        var insights: [String] = []
        
        // Analyser les performances par système
        let systemPerformance = Dictionary(grouping: data, by: { $0.xAxis })
            .mapValues { $0.map { $0.value }.reduce(0, +) }
        
        if let bestSystem = systemPerformance.max(by: { $0.value < $1.value }) {
            insights.append("🎯 Le système '\(bestSystem.key)' est le plus efficace")
        }
        
        return insights
    }
    
    private func generateHourInsights(data: [HeatmapData]) -> [String] {
        var insights: [String] = []
        
        // Analyser les performances par heure
        let hourPerformance = Dictionary(grouping: data, by: { $0.xAxis })
            .mapValues { $0.map { $0.value }.reduce(0, +) }
        
        if let bestHour = hourPerformance.max(by: { $0.value < $1.value }) {
            insights.append("🕐 Tu performs mieux à \(bestHour.key)")
        }
        
        return insights
    }
    
    private func generateDayOfWeekInsights(data: [HeatmapData]) -> [String] {
        var insights: [String] = []
        
        // Analyser les performances par jour de semaine
        let dayPerformance = Dictionary(grouping: data, by: { $0.xAxis })
            .mapValues { $0.map { $0.value }.reduce(0, +) }
        
        if let bestDay = dayPerformance.max(by: { $0.value < $1.value }) {
            insights.append("📅 Le \(bestDay.key) est ton jour le plus performant")
        }
        
        return insights
    }
    
    private func generateMonthInsights(data: [HeatmapData], months: [String]) -> [String] {
        var insights: [String] = []
        
        // Analyser les performances par mois
        let monthPerformance = Dictionary(grouping: data, by: { $0.xAxis })
            .mapValues { $0.map { $0.value }.reduce(0, +) }
        
        if let bestMonth = monthPerformance.max(by: { $0.value < $1.value }) {
            insights.append("📈 \(bestMonth.key) a été ton meilleur mois")
        }
        
        return insights
    }
}
