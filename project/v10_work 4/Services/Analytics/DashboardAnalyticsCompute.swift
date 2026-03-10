import Foundation

/// Foundation-only analytics compute for the Dashboard (Swift 6 safe).
/// - No @MainActor
/// - No SwiftUI
/// - No AppColors
/// Types are defined in DashboardAnalyticsTypes.swift (nonisolated)

// MARK: - Analytics Compute

enum DashboardAnalyticsCompute {

    // MARK: - Calendar (background-safe)
    nonisolated static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        cal.firstWeekday = 1
        return cal
    }

    // MARK: - Heatmap grid dates
    nonisolated static func makeHeatmapGridDates(
        period: DashboardHeatmapPeriod,
        now: Date
    ) -> [[Date]] {

        let cal = calendar
        let rows = max(1, period.weeksCount)

        guard let refWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            let today = cal.startOfDay(for: now)
            return Array(repeating: Array(repeating: today, count: 7), count: rows)
        }

        var out: [[Date]] = Array(repeating: [], count: rows)

        for w in 0..<rows {
            let weekOffset = w - (rows - 1)
            let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: refWeekStart) ?? refWeekStart
            out[w] = (0..<7).map {
                cal.startOfDay(
                    for: cal.date(byAdding: .day, value: $0, to: weekStart)!
                )
            }
        }

        return out
    }

    // MARK: - Compute result (dashboard cache payload)
    struct Result {
        let pnlHeatmap: [DashboardHeatmapPeriod: [[DashboardHeatmapCell]]]
        let emotionalHeatmap: [DashboardHeatmapPeriod: [[DashboardHeatmapCell]]]
        let pnlCurve: [DashboardCurvePoint]
        let weightedPnlCurve: [DashboardCurvePoint]
        let emotionalCurve: [DashboardCurvePoint]
        let pnlYDomain: ClosedRange<Double>
        let pnlCurveByRange: [CurveTimeRange: [DashboardCurvePoint]]
        let emotionalCurveByRange: [CurveTimeRange: [DashboardCurvePoint]]
        let normalizedPnLCurveByRange: [CurveTimeRange: [DashboardCurvePoint]]
        let normalizedEmotionalCurveByRange: [CurveTimeRange: [DashboardCurvePoint]]
        let pnlBarsByRange: [CurveTimeRange: [DashboardBarPoint]]
        let pnlYDomainByRange: [CurveTimeRange: ClosedRange<Double>]
        let pnlAxisTickCountByRange: [CurveTimeRange: Int]
        let weightedPnlYDomain: ClosedRange<Double>
        let emotionalYDomain: ClosedRange<Double>
        let pnlInsightsByRange: [CurveTimeRange: [CurveInsight]]
        let emotionalInsightsByRange: [CurveTimeRange: [CurveInsight]]
        let correlationInsightsByRange: [CurveTimeRange: [CurveInsight]]
        let xAxisStrideByRange: [CurveTimeRange: Int]
        let xAxisUnitByRange: [CurveTimeRange: CurveXAxisUnit]
        let displayDateRangeByRange: [CurveTimeRange: CurveDateRange]
    }

    nonisolated static func compute(
        trades: [Trade],
        moodEntries: [MoodEntry],
        emotionalLoadByDay: [Date: Double],
        language: Localizable.Language = .french
    ) -> Result {
        let loc: (String) -> String = { key in Localizable.text(key, language: language) }
        let cal = calendar
        let now = Date()
        let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start
        let currentWeekEnd = currentWeekStart.flatMap { cal.date(byAdding: .day, value: 6, to: $0) }

        // --- Pre-index trades by day (P&L source: Trade fields only)
        let tradesByDay: [Date: [Trade]] = Dictionary(
            grouping: trades,
            by: { cal.startOfDay(for: $0.date) }
        )
        
        let moodsByDay: [Date: [MoodEntry]] = Dictionary(
            grouping: moodEntries,
            by: { cal.startOfDay(for: $0.timestamp) }
        )

        // --- Curves (base series)
        let curveTrades = trades
            .sorted { $0.date < $1.date }

        var cumulativePnL = 0.0
        var pnlCurve: [DashboardCurvePoint] = []
        pnlCurve.reserveCapacity(curveTrades.count)
        for t in curveTrades {
            let pnl = t.flashPnLNet ?? t.pnl
            cumulativePnL += pnl
            pnlCurve.append(DashboardCurvePoint(date: t.date, value: cumulativePnL))
        }

        // weighted P&L curve (emotion factor per day, no normalization)
        func emotionFactor(for load: Double) -> Double {
            switch load {
            case ..<30: return 1.00
            case ..<60: return 0.85
            case ..<80: return 0.65
            default: return 0.45
            }
        }
        
        var cumulativeWeightedPnL = 0.0
        var weightedPnlCurve: [DashboardCurvePoint] = []
        weightedPnlCurve.reserveCapacity(curveTrades.count)
        for t in curveTrades {
            let pnl = t.flashPnLNet ?? t.pnl
            let day = cal.startOfDay(for: t.date)
            let load = emotionalLoadByDay[day] ?? 0
            let weighted = pnl * emotionFactor(for: load)
            cumulativeWeightedPnL += weighted
            weightedPnlCurve.append(DashboardCurvePoint(date: t.date, value: cumulativeWeightedPnL))
        }

        let pnlValues = pnlCurve.map(\.value)
        let pnlMin = pnlValues.min() ?? 0
        let pnlMax = pnlValues.max() ?? 0
        let pnlPad = max(50, (pnlMax - pnlMin) * 0.15)
        let pnlYDomain: ClosedRange<Double> = (pnlMin - pnlPad)...(pnlMax + pnlPad)

        // emotional curve (daily points, already 0..100)
        let curveDays = emotionalLoadByDay.keys.sorted()
        let emotionalCurve: [DashboardCurvePoint] = curveDays.map { day in
            DashboardCurvePoint(date: day, value: emotionalLoadByDay[day] ?? 0)
        }
        
        // --- Curves by time range (daily points, 1 point = 1 day)
        let dayPnLByDay: [Date: Double] = Dictionary(
            tradesByDay.map { (day, dayTrades) in
                (day, dayTrades.reduce(0.0) { acc, t in acc + (t.flashPnLNet ?? t.pnl) })
            },
            uniquingKeysWith: { $1 }
        )
        
        func dayList(for range: CurveTimeRange) -> [Date] {
            switch range {
            case .all:
                let minTradeDay = dayPnLByDay.keys.min()
                let minMoodDay = emotionalLoadByDay.keys.min()
                let start = [minTradeDay, minMoodDay].compactMap { $0 }.min() ?? cal.startOfDay(for: now)
                let end = cal.startOfDay(for: now)
                let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
                return (0...days).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
            default:
                let days: Int
                switch range {
                case .daily: days = 0
                case .week: days = 6
                case .twoWeeks: days = 13
                case .month: days = 29
                case .threeMonths: days = 89
                case .sixMonths: days = 179
                case .year: days = 364
                case .all: days = 0
                }
                let end = cal.startOfDay(for: now)
                let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
                return (0...days).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
            }
        }
        
        var pnlCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
        var emotionalCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
        var normalizedPnLCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
        var normalizedEmotionalCurveByRange: [CurveTimeRange: [DashboardCurvePoint]] = [:]
        var pnlBarsByRange: [CurveTimeRange: [DashboardBarPoint]] = [:]
        var pnlYDomainByRange: [CurveTimeRange: ClosedRange<Double>] = [:]
        var pnlAxisTickCountByRange: [CurveTimeRange: Int] = [:]
        var pnlInsightsByRange: [CurveTimeRange: [CurveInsight]] = [:]
        var emotionalInsightsByRange: [CurveTimeRange: [CurveInsight]] = [:]
        var correlationInsightsByRange: [CurveTimeRange: [CurveInsight]] = [:]
        var xAxisStrideByRange: [CurveTimeRange: Int] = [:]
        var xAxisUnitByRange: [CurveTimeRange: CurveXAxisUnit] = [:]
        var displayDateRangeByRange: [CurveTimeRange: CurveDateRange] = [:]
        
        func percent(_ value: Double, total: Double) -> Int? {
            guard total > 0 else { return nil }
            let pct = (value / total) * 100.0
            return Int(pct.rounded())
        }
        
        func clampPercent(_ value: Int) -> Int {
            max(0, min(100, value))
        }
        
        func makePnlInsights(points: [DashboardCurvePoint]) -> [CurveInsight] {
            guard points.count >= 2 else { return [] }
            var insights: [CurveInsight] = []
            
            let first = points.first?.value ?? 0
            let last = points.last?.value ?? 0
            let totalMove = last - first
            
            if points.count >= 6, totalMove != 0 {
                let startIndex = Int(Double(points.count - 1) * 0.7)
                let startValue = points[startIndex].value
                let segmentMove = last - startValue
                if let pct = percent(abs(segmentMove), total: abs(totalMove)) {
                    let label = totalMove > 0
                    ? loc("insightPnlLastSegmentUp").replacingOccurrences(of: "{pct}", with: "\(clampPercent(pct))")
                    : loc("insightPnlLastSegmentNet").replacingOccurrences(of: "{pct}", with: "\(clampPercent(pct))")
                    insights.append(CurveInsight(id: "pnl_last_segment", text: label))
                }
            }
            
            var positiveSteps = 0
            var negativeSteps = 0
            for idx in 1..<points.count {
                let delta = points[idx].value - points[idx - 1].value
                if delta > 0 { positiveSteps += 1 }
                if delta < 0 { negativeSteps += 1 }
            }
            let totalSteps = max(1, positiveSteps + negativeSteps)
            let ratioUp = Double(positiveSteps) / Double(totalSteps)
            if ratioUp >= 0.6 {
                insights.append(CurveInsight(id: "pnl_trend_up", text: loc("insightPnlTrendUp")))
            } else if ratioUp <= 0.4 {
                insights.append(CurveInsight(id: "pnl_trend_down", text: loc("insightPnlTrendDown")))
            }
            
            var peakValue = points.first?.value ?? 0
            var peakIndex = 0
            var maxDrawdownLength = 0
            var maxDrawdownStartIndex = 0
            for i in 1..<points.count {
                let v = points[i].value
                if v >= peakValue {
                    peakValue = v
                    peakIndex = i
                } else {
                    let length = i - peakIndex
                    if length > maxDrawdownLength {
                        maxDrawdownLength = length
                        maxDrawdownStartIndex = peakIndex
                    }
                }
            }
            if maxDrawdownLength >= 3 {
                let mid = points.count / 2
                let placement = maxDrawdownStartIndex < mid ? loc("periodStart") : loc("periodEnd")
                insights.append(CurveInsight(id: "pnl_drawdown", text: loc("insightPnlDrawdown").replacingOccurrences(of: "{placement}", with: placement)))
            }
            
            return Array(insights.prefix(3))
        }
        
        func makeEmotionalInsights(points: [DashboardCurvePoint]) -> [CurveInsight] {
            guard !points.isEmpty else { return [] }
            var insights: [CurveInsight] = []
            
            let values = points.map(\.value)
            let total = Double(values.count)
            let calmCount = values.filter { $0 <= 60 }.count
            if let pct = percent(Double(calmCount), total: total) {
                insights.append(CurveInsight(id: "emo_calm_share", text: loc("insightEmoCalmShare").replacingOccurrences(of: "{pct}", with: "\(clampPercent(pct))")))
            }
            
            let tensionCount = values.filter { $0 > 60 }.count
            if let pct = percent(Double(tensionCount), total: total), pct > 0 {
                insights.append(CurveInsight(id: "emo_tension_share", text: loc("insightEmoTensionShare").replacingOccurrences(of: "{pct}", with: "\(clampPercent(pct))")))
            }
            
            var runs: [Int] = []
            var current = 0
            for v in values {
                if v >= 80 {
                    current += 1
                } else if current > 0 {
                    runs.append(current)
                    current = 0
                }
            }
            if current > 0 { runs.append(current) }
            if runs.count >= 2 {
                let avg = Double(runs.reduce(0, +)) / Double(runs.count)
                if avg <= 2.2 {
                    insights.append(CurveInsight(id: "emo_spikes", text: loc("insightEmoSpikes")))
                }
            }
            
            return Array(insights.prefix(3))
        }
        
        func makeCorrelationInsights(
            pnlPoints: [DashboardCurvePoint],
            emoNormalized: [DashboardCurvePoint]
        ) -> [CurveInsight] {
            guard pnlPoints.count >= 2, pnlPoints.count == emoNormalized.count else { return [] }
            var insights: [CurveInsight] = []
            
            var lossDays = 0
            var lossDaysHighPressure = 0
            var gainDays = 0
            var gainDaysCalm = 0
            
            var highPressureDeltas: [Double] = []
            var lowPressureDeltas: [Double] = []
            
            for idx in 1..<pnlPoints.count {
                let delta = pnlPoints[idx].value - pnlPoints[idx - 1].value
                let pressure = emoNormalized[idx].value
                if delta < 0 {
                    lossDays += 1
                    if pressure >= 0.6 { lossDaysHighPressure += 1 }
                }
                if delta > 0 {
                    gainDays += 1
                    if pressure <= 0.3 { gainDaysCalm += 1 }
                }
                
                if pressure >= 0.6 {
                    highPressureDeltas.append(delta)
                } else {
                    lowPressureDeltas.append(delta)
                }
            }
            
            if lossDays > 0, let pct = percent(Double(lossDaysHighPressure), total: Double(lossDays)), pct > 0 {
                insights.append(CurveInsight(id: "corr_loss_high_pressure", text: loc("insightCorrLossHighPressure").replacingOccurrences(of: "{pct}", with: "\(clampPercent(pct))")))
            }
            
            if gainDays > 0, let pct = percent(Double(gainDaysCalm), total: Double(gainDays)), pct >= 55 {
                insights.append(CurveInsight(id: "corr_gains_calm", text: loc("insightCorrGainsCalm")))
            }
            
            if !highPressureDeltas.isEmpty, !lowPressureDeltas.isEmpty {
                let avgHigh = highPressureDeltas.reduce(0, +) / Double(highPressureDeltas.count)
                let avgLow = lowPressureDeltas.reduce(0, +) / Double(lowPressureDeltas.count)
                if avgHigh < avgLow {
                    insights.append(CurveInsight(id: "corr_performance_pressure", text: loc("insightCorrPerformancePressure")))
                }
            }
            
            return Array(insights.prefix(3))
        }
        
        for range in CurveTimeRange.allCases {
            let days = dayList(for: range)
            
            var cumulative = 0.0
            var pnlPoints: [DashboardCurvePoint] = []
            pnlPoints.reserveCapacity(days.count)
            for day in days {
                cumulative += dayPnLByDay[day] ?? 0
                pnlPoints.append(DashboardCurvePoint(date: day, value: cumulative))
            }
            pnlCurveByRange[range] = pnlPoints
            
            let emoPoints: [DashboardCurvePoint] = days.map { day in
                DashboardCurvePoint(date: day, value: emotionalLoadByDay[day] ?? 0)
            }
            emotionalCurveByRange[range] = emoPoints
            
            let maxAbs = pnlPoints.map { abs($0.value) }.max() ?? 0
            let normalizedPnl = pnlPoints.map { p in
                let v = maxAbs == 0 ? 0 : (p.value / maxAbs)
                return DashboardCurvePoint(date: p.date, value: v)
            }
            normalizedPnLCurveByRange[range] = normalizedPnl
            
            let normalizedEmo = emoPoints.map { p in
                DashboardCurvePoint(date: p.date, value: p.value / 100.0)
            }
            normalizedEmotionalCurveByRange[range] = normalizedEmo
            
            let bars: [DashboardBarPoint] = {
                switch range {
                case .daily, .week, .twoWeeks, .month:
                    return days.map { day in
                        DashboardBarPoint(date: day, value: dayPnLByDay[day] ?? 0)
                    }
                case .threeMonths, .sixMonths, .year, .all:
                    var weekSums: [Date: Double] = [:]
                    var weekOrder: [Date] = []
                    weekOrder.reserveCapacity(max(1, days.count / 7))
                    for day in days {
                        let weekStart = cal.dateInterval(of: .weekOfYear, for: day)?.start ?? day
                        if weekSums[weekStart] == nil {
                            weekOrder.append(weekStart)
                        }
                        weekSums[weekStart, default: 0] += dayPnLByDay[day] ?? 0
                    }
                    return weekOrder.map { DashboardBarPoint(date: $0, value: weekSums[$0] ?? 0) }
                }
            }()
            pnlBarsByRange[range] = bars
            
            let pnlValues = pnlPoints.map(\.value)
            let pnlMin = pnlValues.min() ?? 0
            let pnlMax = pnlValues.max() ?? 0
            let pnlPad = max(50, (pnlMax - pnlMin) * 0.15)
            pnlYDomainByRange[range] = (pnlMin - pnlPad)...(pnlMax + pnlPad)
            
            let tickCount: Int = {
                switch range {
                case .daily: return 3
                case .week: return 4
                case .twoWeeks: return 4
                case .month: return 5
                case .threeMonths: return 5
                case .sixMonths: return 6
                case .year: return 6
                case .all: return 6
                }
            }()
            pnlAxisTickCountByRange[range] = tickCount
            
            let (unit, stride): (CurveXAxisUnit, Int) = {
                switch range {
                case .daily: return (.day, 1)
                case .week: return (.day, 1)
                case .twoWeeks: return (.day, 2)
                case .month: return (.day, 7)
                case .threeMonths: return (.month, 1)
                case .sixMonths: return (.month, 1)
                case .year: return (.month, 2)
                case .all: return (.month, 3)
                }
            }()
            xAxisUnitByRange[range] = unit
            xAxisStrideByRange[range] = stride
            
            if let start = days.first, let end = days.last {
                displayDateRangeByRange[range] = CurveDateRange(start: start, end: end)
            }
            
            correlationInsightsByRange[range] = makeCorrelationInsights(
                pnlPoints: pnlPoints,
                emoNormalized: normalizedEmo
            )
            pnlInsightsByRange[range] = makePnlInsights(points: pnlPoints)
            emotionalInsightsByRange[range] = makeEmotionalInsights(points: emoPoints)
        }

        // --- Heatmaps (all periods)
        var pnlHeatmapByPeriod: [DashboardHeatmapPeriod: [[DashboardHeatmapCell]]] = [:]
        var emotionalHeatmapByPeriod: [DashboardHeatmapPeriod: [[DashboardHeatmapCell]]] = [:]
        pnlHeatmapByPeriod.reserveCapacity(DashboardHeatmapPeriod.allCases.count)
        emotionalHeatmapByPeriod.reserveCapacity(DashboardHeatmapPeriod.allCases.count)

        for period in DashboardHeatmapPeriod.allCases {
            let gridDates = makeHeatmapGridDates(period: period, now: now)

            // PnL values grid (sum per day)
            let pnlValuesGrid: [[Double]] = gridDates.map { row in
                row.map { day in
                    let dayTrades = tradesByDay[day] ?? []
                    return dayTrades.reduce(0.0) { acc, t in acc + (t.flashPnLNet ?? t.pnl) }
                }
            }

            // scale for pnl intensity (avoid division by zero)
            var maxAbs = 1.0
            for row in pnlValuesGrid {
                for v in row {
                    maxAbs = max(maxAbs, abs(v))
                }
            }
            
            // best/worst indices (only if period has some non-zero values)
            var bestIndex: (r: Int, c: Int)?
            var worstIndex: (r: Int, c: Int)?
            if maxAbs > 0.0001 {
                var bestV = -Double.greatestFiniteMagnitude
                var worstV = Double.greatestFiniteMagnitude
                for r in 0..<pnlValuesGrid.count {
                    for c in 0..<pnlValuesGrid[r].count {
                        let v = pnlValuesGrid[r][c]
                        if v > bestV { bestV = v; bestIndex = (r, c) }
                        if v < worstV { worstV = v; worstIndex = (r, c) }
                    }
                }
            }

            // PnL heatmap cells pre-styled (hex/opacities) - GRADIENT ENRICHI
            let pnlCells: [[DashboardHeatmapCell]] = zip(gridDates, pnlValuesGrid).map { (datesRow, valuesRow) in
                zip(datesRow, valuesRow).map { (day, v) in
                    let t = min(1.0, abs(v) / maxAbs)
                    let intensity = pow(t, 0.65)

                    // 🎨 Gradient enrichi pour P&L (9 nuances au lieu de 3)
                    let hex: String
                    if v > 0 {
                        // Vert progressif selon l'intensité
                        switch intensity {
                        case 0..<0.2:    hex = "#6EE7B7"  // Vert très clair (emerald-300)
                        case 0.2..<0.35: hex = "#34D399"  // Vert clair (emerald-400)
                        case 0.35..<0.5: hex = "#10B981"  // Vert moyen (emerald-500)
                        case 0.5..<0.65: hex = "#059669"  // Vert foncé (emerald-600)
                        case 0.65..<0.8: hex = "#047857"  // Vert très foncé (emerald-700)
                        default:         hex = "#065F46"  // Vert intense (emerald-800)
                        }
                    } else if v < 0 {
                        // Rouge progressif selon l'intensité
                        switch intensity {
                        case 0..<0.2:    hex = "#FCA5A5"  // Rouge très clair (red-300)
                        case 0.2..<0.35: hex = "#F87171"  // Rouge clair (red-400)
                        case 0.35..<0.5: hex = "#EF4444"  // Rouge moyen (red-500)
                        case 0.5..<0.65: hex = "#DC2626"  // Rouge foncé (red-600)
                        case 0.65..<0.8: hex = "#B91C1C"  // Rouge très foncé (red-700)
                        default:         hex = "#991B1B"  // Rouge intense (red-800)
                        }
                    } else {
                        hex = "#2A2A2A"  // Neutre (gris foncé)
                    }

                    let opacity = v == 0 ? 0.22 : (0.10 + 0.75 * intensity)
                    let dayTrades = tradesByDay[day] ?? []
                    let tradeCount = dayTrades.count
                    
                    // dominant symbol + direction (precomputed to keep Views dumb)
                    var symbolCounts: [String: Int] = [:]
                    symbolCounts.reserveCapacity(min(6, tradeCount))
                    var longCount = 0
                    var shortCount = 0
                    for t in dayTrades {
                        symbolCounts[t.symbol, default: 0] += 1
                        switch t.type {
                        case .long:
                            longCount += 1
                        case .short:
                            shortCount += 1
                        @unknown default:
                            break
                        }
                    }
                    let dominantSymbol = symbolCounts.max(by: { $0.value < $1.value })?.key
                    let dominantSide: String? = (longCount == 0 && shortCount == 0) ? nil : (longCount >= shortCount ? "LONG" : "SHORT")
                    
                    let isCurrentWeek: Bool = {
                        guard let s = currentWeekStart, let e = currentWeekEnd else { return false }
                        return day >= cal.startOfDay(for: s) && day <= cal.startOfDay(for: e)
                    }()
                    
                    let title = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    let primary = (v >= 0 ? "+" : "") + String(format: "%.0f", v)
                    let secondaryParts = [
                        "\(tradeCount) trade\(tradeCount > 1 ? "s" : "")",
                        dominantSymbol,
                        dominantSide
                    ].compactMap { $0 }
                    let secondary = secondaryParts.joined(separator: " • ")
                    
                    let label = "\(title), P&L \(primary)"


                    return DashboardHeatmapCell(
                        date: day,
                        value: v,
                        fillHex: hex,
                        fillOpacity: opacity,
                        strokeOpacity: 0.08,
                        accessibilityLabel: label,
                        title: title,
                        primaryText: primary,
                        secondaryText: secondary,
                        count: tradeCount,
                        isBest: false,
                        isWorst: false,
                        isCurrentWeek: isCurrentWeek
                    )
                }
            }
            let pnlCellsFlagged: [[DashboardHeatmapCell]] = pnlCells.enumerated().map { r, row in
                row.enumerated().map { c, cell in
                    DashboardHeatmapCell(
                        date: cell.date,
                        value: cell.value,
                        fillHex: cell.fillHex,
                        fillOpacity: cell.fillOpacity,
                        strokeOpacity: cell.strokeOpacity,
                        accessibilityLabel: cell.accessibilityLabel,
                        title: cell.title,
                        primaryText: cell.primaryText,
                        secondaryText: cell.secondaryText,
                        count: cell.count,
                        isBest: (bestIndex?.r == r && bestIndex?.c == c),
                        isWorst: (worstIndex?.r == r && worstIndex?.c == c),
                        isCurrentWeek: cell.isCurrentWeek,
                        id: cell.id
                    )
                }
            }

            // Emotional heatmap cells (value 0..100)
            let emoValuesGrid: [[Double]] = gridDates.map { row in
                row.map { day in emotionalLoadByDay[day] ?? 0 }
            }
            
            // max load (highlight) — ignore 0s
            var emoMaxIndex: (r: Int, c: Int)?
            var emoMaxV = 0.0
            for r in 0..<emoValuesGrid.count {
                for c in 0..<emoValuesGrid[r].count {
                    let v = emoValuesGrid[r][c]
                    if v > emoMaxV {
                        emoMaxV = v
                        emoMaxIndex = (r, c)
                    }
                }
            }
            
            let emoCells: [[DashboardHeatmapCell]] = gridDates.enumerated().map { r, row in
                row.enumerated().map { c, day in
                    let v = emoValuesGrid[r][c]
                    let t = max(0.0, min(1.0, v / 100.0))
                    // ✅ plus lisible pour les petits scores (dev/early data)
                    let intensity = pow(t, 0.65)

                    // 🎨 Gradient enrichi pour charge émotionnelle (10 nuances)
                    let hex: String
                    if v <= 0.0001 {
                        hex = "#2A2A2A"  // Neutre (pas de données)
                    } else {
                        switch v {
                        case ..<10:  hex = "#5EEAD4"  // Teal très clair (teal-300) - Très calme
                        case ..<20:  hex = "#2DD4BF"  // Teal clair (teal-400) - Calme
                        case ..<30:  hex = "#14B8A6"  // Teal moyen (teal-500) - Calme stable
                        case ..<40:  hex = "#7DD3FC"  // Sky clair (sky-300) - Début vigilance
                        case ..<50:  hex = "#38BDF8"  // Sky moyen (sky-400) - Vigilance
                        case ..<60:  hex = "#FACC15"  // Yellow (yellow-400) - Attention
                        case ..<70:  hex = "#FB923C"  // Orange clair (orange-400) - Tension
                        case ..<80:  hex = "#F97316"  // Orange foncé (orange-500) - Tension élevée
                        case ..<90:  hex = "#F87171"  // Red clair (red-400) - Danger
                        default:     hex = "#DC2626"  // Red foncé (red-600) - Danger critique
                        }
                    }

                    // ✅ baseline un peu plus haute pour voir quelque chose en heatmap
                    let opacity = v <= 0.0001 ? 0.22 : (0.14 + 0.76 * intensity)
                    let moodCount = (moodsByDay[day] ?? []).count
                    let isCurrentWeek: Bool = {
                        guard let s = currentWeekStart, let e = currentWeekEnd else { return false }
                        return day >= cal.startOfDay(for: s) && day <= cal.startOfDay(for: e)
                    }()
                    
                    let title = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    let primary = "\(Int(round(v)))/100"
                    let pressure: String = {
                        switch v {
                        case ..<20: return "faible"
                        case ..<50: return "modérée"
                        case ..<75: return "élevée"
                        default: return "très élevée"
                        }
                    }()
                    let secondary = "\(moodCount) entrée\(moodCount > 1 ? "s" : "") • pression \(pressure)"
                    
                    let label = "\(title), charge \(primary)"

                    return DashboardHeatmapCell(
                        date: day,
                        value: v,
                        fillHex: hex,
                        fillOpacity: opacity,
                        strokeOpacity: 0.08,
                        accessibilityLabel: label,
                        title: title,
                        primaryText: primary,
                        secondaryText: secondary,
                        count: moodCount,
                        isBest: (emoMaxIndex?.r == r && emoMaxIndex?.c == c && emoMaxV > 0.0001),
                        isWorst: false,
                        isCurrentWeek: isCurrentWeek
                    )
                }
            }

            pnlHeatmapByPeriod[period] = pnlCellsFlagged
            emotionalHeatmapByPeriod[period] = emoCells
        }

        return Result(
            pnlHeatmap: pnlHeatmapByPeriod,
            emotionalHeatmap: emotionalHeatmapByPeriod,
            pnlCurve: pnlCurve,
            weightedPnlCurve: weightedPnlCurve,
            emotionalCurve: emotionalCurve,
            pnlYDomain: pnlYDomain,
            pnlCurveByRange: pnlCurveByRange,
            emotionalCurveByRange: emotionalCurveByRange,
            normalizedPnLCurveByRange: normalizedPnLCurveByRange,
            normalizedEmotionalCurveByRange: normalizedEmotionalCurveByRange,
            pnlBarsByRange: pnlBarsByRange,
            pnlYDomainByRange: pnlYDomainByRange,
            pnlAxisTickCountByRange: pnlAxisTickCountByRange,
            weightedPnlYDomain: pnlYDomain,
            emotionalYDomain: 0...100,
            pnlInsightsByRange: pnlInsightsByRange,
            emotionalInsightsByRange: emotionalInsightsByRange,
            correlationInsightsByRange: correlationInsightsByRange,
            xAxisStrideByRange: xAxisStrideByRange,
            xAxisUnitByRange: xAxisUnitByRange,
            displayDateRangeByRange: displayDateRangeByRange
        )
    }
}
