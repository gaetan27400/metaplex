import SwiftUI
import Charts

enum CurveMode: CaseIterable, Identifiable {
    case pnl
    case emotional
    case correlation
    case pnlContext
    
    var id: Self { self }
    
    func localizedTitle(language: Localizable.Language) -> String {
        switch self {
        case .pnl:         return Localizable.text("curveModePnl", language: language)
        case .emotional:   return Localizable.text("curveModeEmotional", language: language)
        case .correlation: return Localizable.text("curveModeCorrelation", language: language)
        case .pnlContext:  return Localizable.text("curveModePnlContext", language: language)
        }
    }
    
    // Kept for backward compat (non-localized fallback)
    var title: String {
        switch self {
        case .pnl: return "P&L"
        case .emotional: return "Emotional load"
        case .correlation: return "Correlation"
        case .pnlContext: return "P&L + Context"
        }
    }
}

struct UnifiedCurveBlock: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @ObservedObject var cache: DashboardAnalyticsCache
    let onOpenDetails: (() -> Void)?
    @State private var mode: CurveMode = .pnl
    @State private var range: CurveTimeRange = .month
    @State private var showInsights: Bool = false
    
    init(cache: DashboardAnalyticsCache, onOpenDetails: (() -> Void)? = nil) {
        self.cache = cache
        self.onOpenDetails = onOpenDetails
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            chart
            insightsToggleRow
            if showInsights {
                insightsList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.30), value: mode)
        .animation(.easeInOut(duration: 0.22), value: showInsights)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("courbe"))
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    Text(mode == .pnl
                         ? t("curveSubPnl")
                         : mode == .emotional
                         ? t("curveSubEmotional")
                         : mode == .correlation
                         ? t("curveSubCorrelation")
                         : t("curveSubPnlContext")
                    )
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                
                Menu {
                    ForEach(CurveMode.allCases) { m in
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.easeInOut(duration: 0.18)) {
                                mode = m
                                showInsights = false
                            }
                        } label: {
                            if mode == m {
                                Label(m.localizedTitle(language: languageManager.currentLanguage), systemImage: "checkmark")
                            } else {
                                Text(m.localizedTitle(language: languageManager.currentLanguage))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(mode.localizedTitle(language: languageManager.currentLanguage))
                            .font(AppTypography.captionMedium.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppColors.cardBackground.opacity(0.9))
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .accessibilityLabel("Mode courbe")
                .accessibilityValue(mode.title)
                
                if let onOpenDetails {
                    Button {
                        HapticFeedback.selection()
                        onOpenDetails()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppColors.cardBackground.opacity(0.9))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                                    )
                            )
                    }
                    .accessibilityLabel("Ouvrir en plein écran")
                }
            }
            
            Picker("Période", selection: $range) {
                ForEach(CurveTimeRange.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: range) { _, _ in
                HapticFeedback.selection()
            }
            .accessibilityLabel("Période courbe")
            .accessibilityValue(range.displayName)
            
            if let dateRange = cache.displayDateRangeByRange[range] {
                Text(periodLabel(for: dateRange))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
        }
    }
    
    private var helperText: String {
        switch mode {
        case .pnl:         return t("curveHelperPnl")
        case .emotional:   return t("curveHelperEmotional")
        case .correlation: return t("curveHelperCorrelation")
        case .pnlContext:  return t("curveHelperPnlContext")
        }
    }
    
    private var insights: [CurveInsight] {
        switch mode {
        case .pnl:
            return cache.pnlInsightsByRange[range] ?? []
        case .emotional:
            return cache.emotionalInsightsByRange[range] ?? []
        case .correlation:
            return cache.correlationInsightsByRange[range] ?? []
        case .pnlContext:
            return []
        }
    }
    
    // Toggle row: helperText summary + bouton expand/collapse
    private var insightsToggleRow: some View {
        let hasContent = !insights.isEmpty || !helperText.isEmpty
        return Group {
            if hasContent {
                Button {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showInsights.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showInsights ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(showInsights ? .yellow : AppColors.textSecondary.opacity(0.5))
                        Text(showInsights ? t("hideInsights") : t("showInsights"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        Spacer()
                        Image(systemName: showInsights ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary.opacity(0.4))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.cardBackground.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.border.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private var insightsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(helperText)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 2)
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(AppColors.textSecondary.opacity(0.35))
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)
                    Text(insight.text)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .opacity(0.85)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.cardBackground.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Insights")
    }
    
    private func periodLabel(for range: CurveDateRange) -> String {
        let format: Date.FormatStyle = {
            switch self.range {
            case .year, .all:
                return .dateTime.day().month(.abbreviated).year()
            default:
                return .dateTime.day().month(.abbreviated)
            }
        }()
        return "Période : \(self.range.displayName) (du \(range.start.formatted(format)) au \(range.end.formatted(format)))"
    }
    
    @ViewBuilder
    private var chart: some View {
        switch mode {
        case .pnl:
            pnlChart
        case .emotional:
            emotionalChart
        case .correlation:
            correlationChart
        case .pnlContext:
            pnlContextChart
        }
    }
    
    private var pnlChart: some View {
        let points = cache.pnlCurveByRange[range] ?? cache.pnlCurve
        let yDomain = cache.pnlCurveYDomainByRange[range] ?? cache.pnlCurveYDomain
        let tickCount = cache.pnlAxisTickCountByRange[range] ?? 4
        let stride = cache.xAxisStrideByRange[range] ?? 7
        let unit = cache.xAxisUnitByRange[range] ?? .day
        if points.isEmpty || !cache.isReady {
            return AnyView(loadingChart(height: 220))
        }
        return AnyView(PnlChartView(points: points, yDomain: yDomain, tickCount: tickCount, xStride: stride, xUnit: unit, range: range))
    }
    
    private var emotionalChart: some View {
        let points = cache.emotionalCurveByRange[range] ?? cache.emotionalCurve
        let stride = cache.xAxisStrideByRange[range] ?? 7
        let unit = cache.xAxisUnitByRange[range] ?? .day
        if points.isEmpty || !cache.isReady {
            return AnyView(loadingChart(height: 260))
        }
        return AnyView(EmotionalChartView(points: points, xStride: stride, xUnit: unit, range: range))
    }
    
    private var correlationChart: some View {
        let pnlPoints = cache.normalizedPnLCurveByRange[range] ?? []
        let emoPoints = cache.normalizedEmotionalCurveByRange[range] ?? []
        let tickCount = cache.pnlAxisTickCountByRange[range] ?? 4
        let stride = cache.xAxisStrideByRange[range] ?? 7
        let unit = cache.xAxisUnitByRange[range] ?? .day
        if pnlPoints.isEmpty || emoPoints.isEmpty || !cache.isReady {
            return AnyView(loadingChart(height: 260))
        }
        return AnyView(CorrelationChartView(pnlPoints: pnlPoints, emoPoints: emoPoints, tickCount: tickCount, xStride: stride, xUnit: unit, range: range))
    }
    
    private var pnlContextChart: some View {
        let bars = cache.pnlBarsByRange[range] ?? []
        let emoPoints = cache.emotionalCurveByRange[range] ?? cache.emotionalCurve
        let yDomain = cache.pnlCurveYDomainByRange[range] ?? cache.pnlCurveYDomain
        let tickCount = cache.pnlAxisTickCountByRange[range] ?? 4
        let stride = cache.xAxisStrideByRange[range] ?? 7
        let unit = cache.xAxisUnitByRange[range] ?? .day
        if bars.isEmpty || emoPoints.isEmpty || !cache.isReady {
            return AnyView(loadingChart(height: 260))
        }
        return AnyView(PnlContextChartView(
            bars: bars,
            emoPoints: emoPoints,
            yDomain: yDomain,
            tickCount: tickCount,
            xStride: stride,
            xUnit: unit,
            range: range
        ))
    }
    
    private func loadingChart(height: CGFloat) -> some View {
        HStack(spacing: 10) {
            ProgressView().scaleEffect(0.9)
            Text(t("calculEnCours"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .frame(height: height)
    }
    
}

private struct PnlChartView: View {
    let points: [DashboardCurvePoint]
    let yDomain: ClosedRange<Double>
    let tickCount: Int
    let xStride: Int
    let xUnit: CurveXAxisUnit
    let range: CurveTimeRange
    
    // Domaine Y adaptatif avec marge de 20%
    private var adaptiveYDomain: ClosedRange<Double> {
        let minVal = points.map(\.value).min() ?? 0
        let maxVal = points.map(\.value).max() ?? 0
        
        let range = max(abs(maxVal - minVal), 100)
        let margin = range * 0.2
        
        let lower = min(minVal - margin, -margin)
        let upper = max(maxVal + margin, margin)
        
        return lower...upper
    }
    
    // Stride adaptatif - calcul intelligent pour 4-6 ticks optimaux
    private var strideValue: Double {
        let range = adaptiveYDomain.upperBound - adaptiveYDomain.lowerBound
        guard range > 0 else { return 1000 }
        
        // Objectif : 4-6 ticks sur l'axe Y
        let targetTicks = 5.0
        let rawStride = range / targetTicks
        
        // Arrondir à une valeur "ronde" selon l'ordre de grandeur
        let magnitude = pow(10.0, floor(log10(rawStride)))
        let normalized = rawStride / magnitude
        
        // Arrondir à 1, 2, 5, 10 (valeurs "rondes")
        let rounded: Double
        if normalized <= 1.5 {
            rounded = 1.0
        } else if normalized <= 3.0 {
            rounded = 2.0
        } else if normalized <= 7.0 {
            rounded = 5.0
        } else {
            rounded = 10.0
        }
        
        return rounded * magnitude
    }
    
    // Valeurs d'axe Y calculées intelligemment (évite les doublons)
    private var yAxisValues: [Double] {
        let stride = strideValue
        let lower = adaptiveYDomain.lowerBound
        let upper = adaptiveYDomain.upperBound
        
        // Arrondir le min vers le bas au stride le plus proche
        let minRounded = floor(lower / stride) * stride
        // Arrondir le max vers le haut au stride le plus proche
        let maxRounded = ceil(upper / stride) * stride
        
        var values: [Double] = []
        var current = minRounded
        
        while current <= maxRounded {
            // Vérifier que la valeur est dans le domaine
            if current >= lower - stride * 0.1 && current <= upper + stride * 0.1 {
                values.append(current)
            }
            current += stride
        }
        
        return values
    }
    
    // Formatage P&L amélioré (évite les doublons)
    private func formatPnL(_ value: Double) -> String {
        let absValue = abs(value)
        
        // Format adaptatif selon la valeur
        if absValue >= 1_000_000 {
            // Millions : "1.5M"
            return String(format: "%.1fM", value / 1_000_000)
        } else if absValue >= 100_000 {
            // Centaines de milliers : "150k" (pas de décimale pour éviter doublons)
            return String(format: "%.0fk", value / 1000)
        } else if absValue >= 10_000 {
            // Dizaines de milliers : "15k" ou "15.5k" selon le stride
            // Si le stride est grand (ex: 10k), pas de décimale
            if strideValue >= 10_000 {
                return String(format: "%.0fk", value / 1000)
            } else {
                return String(format: "%.1fk", value / 1000)
            }
        } else if absValue >= 1_000 {
            // Milliers : "1.5k"
            return String(format: "%.1fk", value / 1000)
        } else {
            // Unités : "500"
            return String(format: "%.0f", value)
        }
    }
    
    var body: some View {
        Chart {
            pnlLineMarks
            pnlRuleMarks
        }
        .chartYScale(domain: adaptiveYDomain)
        .chartPlotStyle { plot in
            plot.padding(.top, 18)
                .padding(.bottom, 48)
                .padding(.trailing, 6)
        }
        .chartYAxis {
            // Calcul intelligent des valeurs d'axe Y (évite les doublons)
            AxisMarks(position: .leading, values: yAxisValues) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.05))
                if let val = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatPnL(val))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .font(.caption2)
                            .monospacedDigit() // Évite le décalage visuel
                    }
                }
            }
        }
        .chartXAxis {
            switch range {
            case .daily, .week, .twoWeeks:
                AxisMarks(values: .stride(by: .day, count: max(1, xStride))) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.04))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: shortRangeFormat)
                        }
                    }
                    .foregroundStyle(Color.white.opacity(0.45))
                    .font(.caption2)
                    .offset(y: 6)
                }
            case .month, .threeMonths:
                let anchors = axisAnchors(for: points)
                AxisMarks(values: axisValues(for: points)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.04))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(labelForMonthRange(date: date, anchors: anchors))
                        }
                    }
                    .foregroundStyle(Color.white.opacity(0.5))
                    .font(.caption2)
                    .offset(y: 6)
                }
            case .sixMonths, .year, .all:
                AxisMarks(values: axisValues(for: points)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.04))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(labelForLongRange(date: date))
                        }
                    }
                    .foregroundStyle(Color.white.opacity(0.45))
                    .font(.caption2)
                    .offset(y: 6)
                }
            }
        }
        .chartBackground { _ in
            VStack(spacing: 0) {
                Color.green.opacity(0.03)
                Color.red.opacity(0.03)
            }
        }
        .frame(height: 260)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Courbe P&L")
        .accessibilityHint("Résultat cumulé.")
    }
    
    @ChartContentBuilder
    private var pnlLineMarks: some ChartContent {
        ForEach(points) { p in
            LineMark(
                x: .value("Date", p.date),
                y: .value("P&L", p.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.white)
            .lineStyle(.init(lineWidth: 4.8, lineCap: .round, lineJoin: .round))
            .shadow(color: Color.black.opacity(0.6), radius: 3, x: 0, y: 1)
        }
    }
    
    @ChartContentBuilder
    private var pnlRuleMarks: some ChartContent {
        RuleMark(y: .value("BreakEven", 0))
            .foregroundStyle(Color.white.opacity(0.45))
            .lineStyle(.init(lineWidth: 1.4, dash: [6, 4]))
        RuleMark(y: .value("Baseline", 0))
            .foregroundStyle(.clear)
    }
    
    private var calendar: Calendar { Calendar.current }
    
    private var shortRangeFormat: Date.FormatStyle {
        switch range {
        case .daily:
            return .dateTime.hour().minute()
        case .week, .twoWeeks:
            return .dateTime.weekday(.abbreviated)
        default:
            return .dateTime.day().month(.abbreviated)
        }
    }
    
    private func axisAnchors(for points: [DashboardCurvePoint]) -> (start: Date, mid: Date, end: Date)? {
        guard let start = points.first?.date, let end = points.last?.date else { return nil }
        let mid = points[points.count / 2].date
        return (start, mid, end)
    }
    
    private func axisValues(for points: [DashboardCurvePoint]) -> [Date] {
        guard let start = points.first?.date, let end = points.last?.date else { return [] }
        switch range {
        case .month:
            let mid = points[points.count / 2].date
            return [start, mid, end]
        case .threeMonths:
            // Pour 3 mois, générer un point par mois
            var values: [Date] = [start]
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            var current = monthStart
            while let next = calendar.date(byAdding: .month, value: 1, to: current), next <= end {
                if next > start { values.append(next) }
                current = next
            }
            if let last = values.last, !calendar.isDate(end, inSameDayAs: last) {
                values.append(end)
            }
            return values
        case .sixMonths, .year, .all:
            var values: [Date] = [start]
            let strideMonths = max(1, xStride)
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            var current = monthStart
            while let next = calendar.date(byAdding: .month, value: strideMonths, to: current), next < end {
                if next > start { values.append(next) }
                current = next
            }
            if let last = values.last, !calendar.isDate(end, inSameDayAs: last) {
                values.append(end)
            }
            return values
        default:
            return []
        }
    }
    
    private func labelForMonthRange(date: Date, anchors: (start: Date, mid: Date, end: Date)?) -> String {
        // Pour les périodes mensuelles, afficher toujours la date formatée
        switch range {
        case .month:
            return date.formatted(.dateTime.day().month(.abbreviated))
        case .threeMonths:
            // Pour 3 mois, afficher le mois (plus lisible avec plusieurs points)
            return date.formatted(.dateTime.month(.abbreviated))
        default:
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }
    
    private func labelForLongRange(date: Date) -> String {
        // Pour les longues périodes, afficher toujours le mois (et l'année si nécessaire)
        switch range {
        case .sixMonths:
            return date.formatted(.dateTime.month(.abbreviated))
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        case .all:
            return date.formatted(.dateTime.month(.abbreviated).year())
        default:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

// MARK: - 🔧 FIX 1 : EmotionalChartView Refactorisé

private struct EmotionalChartView: View {
    let points: [DashboardCurvePoint]
    let xStride: Int
    let xUnit: CurveXAxisUnit
    let range: CurveTimeRange
    
    // Zones émotionnelles avec couleurs distinctes
    private let emotionZones: [(threshold: Double, label: String, color: Color)] = [
        (25, "Calme", .green),
        (50, "Attention", .yellow),
        (75, "Tension", .orange),
        (100, "Danger", .red)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Légende compacte AVANT le graphique
            emotionLegend
            
            // Chart principal
            chart
        }
    }
    
    private var emotionLegend: some View {
        HStack(spacing: 12) {
            ForEach(emotionZones, id: \.threshold) { zone in
                HStack(spacing: 4) {
                    Circle()
                        .fill(zone.color.opacity(0.7))
                        .frame(width: 8, height: 8)
                    Text(zone.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
        }
    }
    
    // Max adaptatif pour l'axe Y (arrondi au multiple de 25 supérieur)
    private var maxEmotion: Double {
        let maxValue = points.map(\.value).max() ?? 0
        if maxValue <= 25 { return 25 }
        if maxValue <= 50 { return 50 }
        if maxValue <= 75 { return 75 }
        return 100
    }
    
    private var chart: some View {
        let gradient = LinearGradient(
            stops: [
                .init(color: Color.green.opacity(0.05), location: 0.0),    // 0 = Très calme
                .init(color: Color.green.opacity(0.2), location: 0.25),   // 25 = Calme
                .init(color: Color.yellow.opacity(0.3), location: 0.5),   // 50 = Attention
                .init(color: Color.orange.opacity(0.4), location: 0.75),  // 75 = Tension
                .init(color: Color.red.opacity(0.5), location: 1.0)       // 100 = Danger
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        
        let thresholds: [Double] = [25.0, 50.0, 75.0].filter { $0 <= maxEmotion }
        
        return Chart {
            // Area marks
            ForEach(points) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    yStart: .value("Bas", 0),
                    yEnd: .value("Charge", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(gradient)
            }
            
            // Line marks
            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Charge", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.blue)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
            }
            
            // Rule marks (seuils adaptatifs)
            ForEach(thresholds, id: \.self) { threshold in
                RuleMark(y: .value("Seuil", threshold))
                    .foregroundStyle(Color.white.opacity(0.15))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYScale(domain: 0...maxEmotion)
        .chartPlotStyle { plot in
            plot.padding(.top, 18)
                .padding(.bottom, 48)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: max(maxEmotion / 4, 25))) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.06))
                if let val = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", val))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            xAxisMarks(points: points)
        }
        .frame(height: 260)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Courbe charge émotionnelle")
    }
    
    @AxisContentBuilder
    private func xAxisMarks(points: [DashboardCurvePoint]) -> some AxisContent {
        switch range {
        case .daily, .week, .twoWeeks:
            AxisMarks(values: .stride(by: .day, count: max(1, xStride))) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: shortRangeFormat)
                    }
                }
                .foregroundStyle(Color.white.opacity(0.45))
                .font(.caption2)
                .offset(y: 6)
            }
        case .month, .threeMonths:
            let anchors = axisAnchors(for: points)
            AxisMarks(values: axisValues(for: points)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(labelForMonthRange(date: date, anchors: anchors))
                    }
                }
                .foregroundStyle(Color.white.opacity(0.5))
                .font(.caption2)
                .offset(y: 6)
            }
        case .sixMonths, .year, .all:
            AxisMarks(values: axisValues(for: points)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(labelForLongRange(date: date))
                    }
                }
                .foregroundStyle(Color.white.opacity(0.45))
                .font(.caption2)
                .offset(y: 6)
            }
        }
    }
    
    // MARK: - Helpers
    private var calendar: Calendar { Calendar.current }
    
    private var shortRangeFormat: Date.FormatStyle {
        switch range {
        case .daily: return .dateTime.hour().minute()
        case .week, .twoWeeks: return .dateTime.weekday(.abbreviated)
        default: return .dateTime.day().month(.abbreviated)
        }
    }
    
    private func axisAnchors(for points: [DashboardCurvePoint]) -> (start: Date, mid: Date, end: Date)? {
        guard let start = points.first?.date, let end = points.last?.date else { return nil }
        let mid = points[points.count / 2].date
        return (start, mid, end)
    }
    
    private func axisValues(for points: [DashboardCurvePoint]) -> [Date] {
        guard let start = points.first?.date, let end = points.last?.date else { return [] }
        switch range {
        case .month:
            let mid = points[points.count / 2].date
            return [start, mid, end]
        case .threeMonths:
            // Pour 3 mois, générer un point par mois
            var values: [Date] = [start]
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            var current = monthStart
            while let next = calendar.date(byAdding: .month, value: 1, to: current), next <= end {
                if next > start { values.append(next) }
                current = next
            }
            if let last = values.last, !calendar.isDate(end, inSameDayAs: last) {
                values.append(end)
            }
            return values
        case .sixMonths, .year, .all:
            var values: [Date] = [start]
            let strideMonths = max(1, xStride)
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            var current = monthStart
            while let next = calendar.date(byAdding: .month, value: strideMonths, to: current), next < end {
                if next > start { values.append(next) }
                current = next
            }
            if let last = values.last, !calendar.isDate(end, inSameDayAs: last) {
                values.append(end)
            }
            return values
        default:
            return []
        }
    }
    
    private func labelForMonthRange(date: Date, anchors: (start: Date, mid: Date, end: Date)?) -> String {
        // Pour les périodes mensuelles, afficher toujours la date formatée
        switch range {
        case .month:
            return date.formatted(.dateTime.day().month(.abbreviated))
        case .threeMonths:
            // Pour 3 mois, afficher le mois (plus lisible avec plusieurs points)
            return date.formatted(.dateTime.month(.abbreviated))
        default:
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }
    
    private func labelForLongRange(date: Date) -> String {
        // Pour les longues périodes, afficher toujours le mois (et l'année si nécessaire)
        switch range {
        case .sixMonths:
            return date.formatted(.dateTime.month(.abbreviated))
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        case .all:
            return date.formatted(.dateTime.month(.abbreviated).year())
        default:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

// MARK: - 🔧 FIX 2 : CorrelationChartView Refactorisé

private struct CorrelationChartView: View {
    let pnlPoints: [DashboardCurvePoint]
    let emoPoints: [DashboardCurvePoint]
    let tickCount: Int
    let xStride: Int
    let xUnit: CurveXAxisUnit
    let range: CurveTimeRange
    
    var body: some View {
        VStack(spacing: 12) {
            // ✅ Légende améliorée avec coefficient de corrélation
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 14, height: 2.5)
                        .cornerRadius(1)
                    Text(t("no"))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.3), Color.yellow.opacity(0.3), Color.red.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: 14, height: 8)
                        .cornerRadius(2)
                    Text(t("chargemotionnelle"))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                // Coefficient de corrélation
                if !pnlPoints.isEmpty && !emoPoints.isEmpty {
                    Text(correlationText)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(correlationColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(correlationColor.opacity(0.15))
                        )
                }
            }
            
            chart
        }
    }
    
    // Calcul du coefficient de corrélation
    private var correlation: Double {
        guard pnlPoints.count == emoPoints.count, !pnlPoints.isEmpty else { return 0 }
        
        let pnlValues = pnlPoints.map(\.value)
        let emoValues = emoPoints.map(\.value)
        
        let pnlMean = pnlValues.reduce(0, +) / Double(pnlValues.count)
        let emoMean = emoValues.reduce(0, +) / Double(emoValues.count)
        
        var numerator: Double = 0
        var pnlSumSq: Double = 0
        var emoSumSq: Double = 0
        
        for i in 0..<pnlValues.count {
            let pnlDiff = pnlValues[i] - pnlMean
            let emoDiff = emoValues[i] - emoMean
            numerator += pnlDiff * emoDiff
            pnlSumSq += pnlDiff * pnlDiff
            emoSumSq += emoDiff * emoDiff
        }
        
        let denominator = sqrt(pnlSumSq * emoSumSq)
        return denominator > 0 ? numerator / denominator : 0
    }
    
    private var correlationText: String {
        let r = correlation
        let val = String(format: "%.2f", r)
        if r >= 0.7  { return t("corrStrong") + " (\(val))" }
        if r >= 0.4  { return t("corrModerate") + " (\(val))" }
        if r >= 0.1  { return t("corrWeak") + " (\(val))" }
        if r >= -0.1 { return t("corrNone") + " (\(val))" }
        if r >= -0.4 { return t("corrNegWeak") + " (\(val))" }
        if r >= -0.7 { return t("corrNegModerate") + " (\(val))" }
        return t("corrNegStrong") + " (\(val))"
    }
    
    private var correlationColor: Color {
        let r = abs(correlation)
        if r >= 0.7 { return .orange }
        if r >= 0.4 { return .yellow }
        return .gray
    }
    
    private var chart: some View {
        let emotionGradient = LinearGradient(
            stops: [
                .init(color: Color.green.opacity(0.02), location: 0.0),
                .init(color: Color.green.opacity(0.1), location: 0.25),
                .init(color: Color.yellow.opacity(0.15), location: 0.5),
                .init(color: Color.orange.opacity(0.2), location: 0.75),
                .init(color: Color.red.opacity(0.25), location: 1.0)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        
        let thresholds: [Double] = [0.25, 0.5, 0.75]
        
        return HStack(spacing: 8) {
            Chart {
                // ✅ Area pour l'émotion (en arrière-plan, opacité faible)
                ForEach(emoPoints) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        yStart: .value("Bas", 0),
                        yEnd: .value("Charge", p.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(emotionGradient)
                }
                
                // ✅ Ligne P&L DOMINANTE (épaisse, blanche, devant)
                ForEach(pnlPoints) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("P&L normalisé", p.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.white)
                    .lineStyle(.init(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 1)
                }
                
                // ✅ Lignes de référence émotionnelles (subtiles)
                ForEach(thresholds, id: \.self) { threshold in
                    RuleMark(y: .value("Seuil", threshold))
                        .foregroundStyle(Color.white.opacity(0.12))
                        .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartYScale(domain: 0...1)
            .chartPlotStyle { plot in
                plot.padding(.top, 18)
                    .padding(.bottom, 48)
            }
            .chartYAxis {
                // ✅ Axe gauche : labels émotionnels
                AxisMarks(position: .leading, values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.05))
                    if let val = value.as(Double.self) {
                        AxisValueLabel {
                            Text(emotionLabel(for: val))
                                .font(.caption2)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            .chartXAxis {
                xAxisMarks(points: pnlPoints)
            }
            .frame(height: 260)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Corrélation P&L et charge émotionnelle")
            
            // Axe droit externe : P&L normalisé
            VStack(spacing: 0) {
                ForEach([1.0, 0.75, 0.5, 0.25, 0.0], id: \.self) { val in
                    Text(String(format: "%.1f", val))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.white.opacity(0.65))
                        .frame(width: 30)
                    if val > 0.0 {
                        Spacer()
                    }
                }
            }
            .frame(height: 212)
            .padding(.bottom, 48)
        }
    }
    
    private func emotionLabel(for value: Double) -> String {
        switch value {
        case 0: return "Calme"
        case 0.25: return "Attention"
        case 0.5: return "Tension"
        case 0.75: return "Danger"
        case 1.0: return "Max"
        default: return ""
        }
    }
    
    @AxisContentBuilder
    private func xAxisMarks(points: [DashboardCurvePoint]) -> some AxisContent {
        switch range {
        case .daily, .week, .twoWeeks:
            AxisMarks(values: .stride(by: .day, count: max(1, xStride))) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: shortRangeFormat)
                    }
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .font(.caption2)
            }
        case .month, .threeMonths:
            let anchors = axisAnchors(for: points)
            AxisMarks(values: axisValues(for: points)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(labelForMonthRange(date: date, anchors: anchors))
                    }
                }
                .foregroundStyle(Color.white.opacity(0.5))
                .font(.caption2)
                .offset(y: 6)
            }
        case .sixMonths, .year, .all:
            AxisMarks(values: axisValues(for: points)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(labelForLongRange(date: date))
                    }
                }
                .foregroundStyle(Color.white.opacity(0.45))
                .font(.caption2)
                .offset(y: 6)
            }
        }
    }
    
    // MARK: - Helpers (identiques à EmotionalChartView)
    private var calendar: Calendar { Calendar.current }
    
    private var shortRangeFormat: Date.FormatStyle {
        switch range {
        case .daily: return .dateTime.hour().minute()
        case .week, .twoWeeks: return .dateTime.weekday(.abbreviated)
        default: return .dateTime.day().month(.abbreviated)
        }
    }
    
    private func axisAnchors(for points: [DashboardCurvePoint]) -> (start: Date, mid: Date, end: Date)? {
        guard let start = points.first?.date, let end = points.last?.date else { return nil }
        let mid = points[points.count / 2].date
        return (start, mid, end)
    }
    
    private func axisValues(for points: [DashboardCurvePoint]) -> [Date] {
        guard let start = points.first?.date, let end = points.last?.date else { return [] }
        switch range {
        case .month:
            let mid = points[points.count / 2].date
            return [start, mid, end]
        case .threeMonths:
            // Pour 3 mois, générer un point par mois
            var values: [Date] = [start]
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            var current = monthStart
            while let next = calendar.date(byAdding: .month, value: 1, to: current), next <= end {
                if next > start { values.append(next) }
                current = next
            }
            if let last = values.last, !calendar.isDate(end, inSameDayAs: last) {
                values.append(end)
            }
            return values
        case .sixMonths, .year, .all:
            var values: [Date] = [start]
            let strideMonths = max(1, xStride)
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            var current = monthStart
            while let next = calendar.date(byAdding: .month, value: strideMonths, to: current), next < end {
                if next > start { values.append(next) }
                current = next
            }
            if let last = values.last, !calendar.isDate(end, inSameDayAs: last) {
                values.append(end)
            }
            return values
        default:
            return []
        }
    }
    
    private func labelForMonthRange(date: Date, anchors: (start: Date, mid: Date, end: Date)?) -> String {
        guard let anchors else { return date.formatted(.dateTime.day().month(.abbreviated)) }
        if calendar.isDate(date, inSameDayAs: anchors.start) { return "Début" }
        if calendar.isDate(date, inSameDayAs: anchors.mid) { return "Milieu" }
        if calendar.isDate(date, inSameDayAs: anchors.end) { return "Fin" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
    
    private func labelForLongRange(date: Date) -> String {
        guard let start = pnlPoints.first?.date, let end = pnlPoints.last?.date else {
            return date.formatted(.dateTime.month(.abbreviated))
        }
        if calendar.isDate(date, inSameDayAs: start) { return "Début" }
        if calendar.isDate(date, inSameDayAs: end) { return "Fin" }
        switch range {
        case .all: return date.formatted(.dateTime.month(.abbreviated).year())
        default: return date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

// MARK: - 🔧 FIX 3 : PnlContextChartView Simplifié

private struct PnlContextChartView: View {
    let bars: [DashboardBarPoint]
    let emoPoints: [DashboardCurvePoint]
    let yDomain: ClosedRange<Double>
    let tickCount: Int
    let xStride: Int
    let xUnit: CurveXAxisUnit
    let range: CurveTimeRange
    
    var body: some View {
        VStack(spacing: 12) {
            // ✅ Légende avec bonnes couleurs
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(AppColors.success.opacity(0.7))
                        .frame(width: 12, height: 8)
                        .cornerRadius(2)
                    Text(t("plPriode"))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Rectangle()
                        .fill(Color.orange.opacity(0.85))
                        .frame(width: 12, height: 2)
                    Text(t("chargemotionnelle"))
                        .font(.caption2)
                        .foregroundColor(Color.orange.opacity(0.8))
                }
            }
            
            // ✅ Chart avec axe droit externe et dynamique
            HStack(spacing: 8) {
                Chart {
                    // Barres P&L
                    ForEach(bars) { bar in
                        BarMark(
                            x: .value("Date", bar.date),
                            y: .value("P&L", bar.value)
                        )
                        .foregroundStyle(bar.value >= 0 ? AppColors.success.opacity(0.7) : AppColors.error.opacity(0.7))
                    }
                    
                    // Ligne émotionnelle normalisée sur l'échelle P&L
                    ForEach(emoPoints) { p in
                        let normalizedValue = normalizeEmotionToPnL(p.value)
                        
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Charge", normalizedValue)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.orange.opacity(0.85))
                        .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
                        
                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Charge", normalizedValue)
                        )
                        .symbolSize(40)
                        .foregroundStyle(Color.orange)
                    }
                    
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .lineStyle(.init(lineWidth: 1.5, dash: [4, 4]))
                }
                .chartYScale(domain: adaptiveYDomain)
                .chartYAxis {
                    // Utiliser des valeurs explicites pour éviter les doublons
                    AxisMarks(position: .leading, values: yAxisValues) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        if let val = value.as(Double.self) {
                            AxisValueLabel {
                                Text(formatPnL(val))
                                    .foregroundStyle(Color.white.opacity(0.7))
                                    .font(.caption2)
                                    .monospacedDigit() // Évite le décalage visuel
                            }
                        }
                    }
                }
                .chartXAxis {
                    xAxisMarks(points: bars)
                }
                .frame(height: 260)
                
                // Axe Y droit externe (charge émotionnelle adaptative)
                VStack(spacing: 0) {
                    ForEach(emotionAxisValues.reversed(), id: \.self) { val in
                        Text("\(Int(val))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.orange.opacity(0.85))
                            .frame(width: 30)
                        if val != emotionAxisValues.first {
                            Spacer()
                        }
                    }
                }
                .frame(height: 212)  // Hauteur de la zone de tracé effective
                .padding(.bottom, 48)  // Aligner avec l'axe X
            }
        }
    }
    
    @AxisContentBuilder
    private func xAxisMarks(points: [DashboardBarPoint]) -> some AxisContent {
        switch range {
        case .daily, .week, .twoWeeks:
            AxisMarks(values: .stride(by: .day, count: max(1, xStride))) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: shortRangeFormat)
                    }
                }
                .foregroundStyle(Color.white.opacity(0.45))
                .font(.caption2)
                .offset(y: 6)
            }
        case .month, .threeMonths:
            let anchors = axisAnchors(for: points)
            AxisMarks(values: axisValues(for: points)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(labelForMonthRange(date: date, anchors: anchors))
                    }
                }
                .foregroundStyle(Color.white.opacity(0.5))
                .font(.caption2)
                .offset(y: 6)
            }
        case .sixMonths, .year, .all:
            AxisMarks(values: axisValues(for: points)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(labelForLongRange(date: date))
                    }
                }
                .foregroundStyle(Color.white.opacity(0.45))
                .font(.caption2)
                .offset(y: 6)
            }
        }
    }
    
    // MARK: - Helpers (identiques)
    private var calendar: Calendar { Calendar.current }
    
    private var shortRangeFormat: Date.FormatStyle {
        switch range {
        case .daily: return .dateTime.hour().minute()
        case .week, .twoWeeks: return .dateTime.weekday(.abbreviated)
        default: return .dateTime.day().month(.abbreviated)
        }
    }
    
    private func axisAnchors(for points: [DashboardBarPoint]) -> (start: Date, mid: Date, end: Date)? {
        guard let start = points.first?.date, let end = points.last?.date else { return nil }
        let mid = points[points.count / 2].date
        return (start, mid, end)
    }
    
    private func axisValues(for points: [DashboardBarPoint]) -> [Date] {
        guard let start = points.first?.date, let end = points.last?.date else { return [] }
        switch range {
        case .month, .threeMonths:
            let mid = points[points.count / 2].date
            return [start, mid, end]
        case .sixMonths, .year, .all:
            var values: [Date] = [start]
            let strideMonths = max(1, xStride)
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start ?? start
            var current = monthStart
            while let next = calendar.date(byAdding: .month, value: strideMonths, to: current), next < end {
                if next > start { values.append(next) }
                current = next
            }
            if let last = values.last, !calendar.isDate(end, inSameDayAs: last) {
                values.append(end)
            }
            return values
        default:
            return []
        }
    }
    
    private func labelForMonthRange(date: Date, anchors: (start: Date, mid: Date, end: Date)?) -> String {
        guard let anchors else { return date.formatted(.dateTime.day().month(.abbreviated)) }
        if calendar.isDate(date, inSameDayAs: anchors.start) { return "Début" }
        if calendar.isDate(date, inSameDayAs: anchors.mid) { return "Milieu" }
        if calendar.isDate(date, inSameDayAs: anchors.end) { return "Fin" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
    
    private func labelForLongRange(date: Date) -> String {
        guard let start = bars.first?.date, let end = bars.last?.date else {
            return date.formatted(.dateTime.month(.abbreviated))
        }
        if calendar.isDate(date, inSameDayAs: start) { return "Début" }
        if calendar.isDate(date, inSameDayAs: end) { return "Fin" }
        switch range {
        case .all: return date.formatted(.dateTime.month(.abbreviated).year())
        default: return date.formatted(.dateTime.month(.abbreviated))
        }
    }
    
    // Normalise la charge émotionnelle (0-100) sur l'échelle P&L adaptative
    private func normalizeEmotionToPnL(_ emotionValue: Double) -> Double {
        let minPnL = adaptiveYDomain.lowerBound
        let maxPnL = adaptiveYDomain.upperBound
        let pnlRange = maxPnL - minPnL
        
        // Normaliser par rapport au max émotionnel réel
        let normalizedEmotion = emotionValue / maxEmotion
        
        // Convertir vers l'échelle P&L
        return minPnL + normalizedEmotion * pnlRange
    }
    
    // Domaine Y adaptatif avec marge de 20%
    private var adaptiveYDomain: ClosedRange<Double> {
        let minBar = bars.map(\.value).min() ?? 0
        let maxBar = bars.map(\.value).max() ?? 0
        
        // Calculer la marge (20% du range)
        let range = max(abs(maxBar - minBar), 100)  // Minimum 100 pour éviter les axes trop petits
        let margin = range * 0.2
        
        let lower = min(minBar - margin, -margin)
        let upper = max(maxBar + margin, margin)
        
        return lower...upper
    }
    
    // Max de la charge émotionnelle (arrondi au multiple de 25 supérieur)
    private var maxEmotion: Double {
        let maxValue = emoPoints.map(\.value).max() ?? 0
        
        // Arrondir au multiple de 25 supérieur
        if maxValue <= 25 { return 25 }
        if maxValue <= 50 { return 50 }
        if maxValue <= 75 { return 75 }
        return 100
    }
    
    // Valeurs de l'axe émotionnel adaptatif
    private var emotionAxisValues: [Double] {
        let max = maxEmotion
        let step = max / 4.0  // 5 graduations
        return stride(from: 0, through: max, by: step).map { $0 }
    }
    
    // Stride adaptatif - calcul intelligent pour 4-6 ticks optimaux (identique à PnlChartView)
    private var strideValue: Double {
        let range = adaptiveYDomain.upperBound - adaptiveYDomain.lowerBound
        guard range > 0 else { return 1000 }
        
        // Objectif : 4-6 ticks sur l'axe Y
        let targetTicks = 5.0
        let rawStride = range / targetTicks
        
        // Arrondir à une valeur "ronde" selon l'ordre de grandeur
        let magnitude = pow(10.0, floor(log10(rawStride)))
        let normalized = rawStride / magnitude
        
        // Arrondir à 1, 2, 5, 10 (valeurs "rondes")
        let rounded: Double
        if normalized <= 1.5 {
            rounded = 1.0
        } else if normalized <= 3.0 {
            rounded = 2.0
        } else if normalized <= 7.0 {
            rounded = 5.0
        } else {
            rounded = 10.0
        }
        
        return rounded * magnitude
    }
    
    // Valeurs d'axe Y calculées intelligemment (évite les doublons)
    private var yAxisValues: [Double] {
        let stride = strideValue
        let lower = adaptiveYDomain.lowerBound
        let upper = adaptiveYDomain.upperBound
        
        // Arrondir le min vers le bas au stride le plus proche
        let minRounded = floor(lower / stride) * stride
        // Arrondir le max vers le haut au stride le plus proche
        let maxRounded = ceil(upper / stride) * stride
        
        var values: [Double] = []
        var current = minRounded
        
        while current <= maxRounded {
            // Vérifier que la valeur est dans le domaine
            if current >= lower - stride * 0.1 && current <= upper + stride * 0.1 {
                values.append(current)
            }
            current += stride
        }
        
        return values
    }
    
    // Formatage P&L amélioré (évite les doublons)
    private func formatPnL(_ value: Double) -> String {
        let absValue = abs(value)
        
        // Format adaptatif selon la valeur
        if absValue >= 1_000_000 {
            // Millions : "1.5M"
            return String(format: "%.1fM", value / 1_000_000)
        } else if absValue >= 100_000 {
            // Centaines de milliers : "150k" (pas de décimale pour éviter doublons)
            return String(format: "%.0fk", value / 1000)
        } else if absValue >= 10_000 {
            // Dizaines de milliers : "15k" ou "15.5k" selon le stride
            // Si le stride est grand (ex: 10k), pas de décimale
            if strideValue >= 10_000 {
                return String(format: "%.0fk", value / 1000)
            } else {
                return String(format: "%.1fk", value / 1000)
            }
        } else if absValue >= 1_000 {
            // Milliers : "1.5k"
            return String(format: "%.1fk", value / 1000)
        } else {
            // Unités : "500"
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - 🧩 Composants d'aide

private struct LegendItem: View {
    let color: Color
    let label: String
    let style: LegendStyle
    
    enum LegendStyle {
        case solid, area
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if style == .solid {
                Rectangle()
                    .fill(color)
                    .frame(width: 14, height: 2)
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.6), color.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 14, height: 8)
            }
            
            Text(label)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
