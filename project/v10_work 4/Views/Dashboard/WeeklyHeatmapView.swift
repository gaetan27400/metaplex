import Foundation
import SwiftUI
import Combine

// MARK: - Heatmap Period (P&L)
enum HeatmapPeriod: CaseIterable {
    case week
    case month
    case threeMonths
    case sixMonths
    case year
    
    var displayName: String {
        switch self {
        case .week: return "Semaine"
        case .month: return "Mois"
        case .threeMonths: return "3 mois"
        case .sixMonths: return "6 mois"
        case .year: return "Année"
        }
    }
    
    /// Nb de semaines affichées (dernière ligne = semaine courante).
    var weeksCount: Int {
        switch self {
        case .week: return 1
        case .month: return 5
        case .threeMonths: return 13
        case .sixMonths: return 26
        case .year: return 52
        }
    }
}


// MARK: - Challenge Banner Item
struct ChallengeBannerItem: View {
    let title: String
    let progress: Double
    let reward: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                
                ProgressView(value: progress)
                    .tint(color)
                    .scaleEffect(y: 0.8)
            }
            
            Spacer()
            
            Text(reward)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.2))
                .cornerRadius(6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.18))
        .cornerRadius(12)
    }
}

// MARK: - Weekly Heatmap View
struct WeeklyHeatmapView: View {
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    @Environment(\.dismiss) var dismiss
    
    private let daysOfWeek = ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]

    @State private var selectedCell: WeeklyHeatmapSelection?
    @State private var showingCellDetails = false
    @State private var didAppear: Bool = false
    @State private var selectedPeriod: HeatmapPeriod = .month
    
    // ✅ Cache: évite tout recalcul lourd dans le body (latence au tap)
    @State private var cachedGrid: [[WeeklyHeatmapCellModel]] = []
    @State private var cachedBestWorst: (best: (w: Int, d: Int, v: Double)?, worst: (w: Int, d: Int, v: Double)?) = (best: nil, worst: nil)
    @State private var isGridComputing: Bool = false

    /// On force un calendrier "Dim → Sam" (Sunday-first) pour matcher la grille affichée.
    private var heatmapCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        cal.firstWeekday = 1 // Sunday
        return cal
    }
    
    private func dateForCell(weekIndex: Int, dayIndex: Int) -> Date? {
        let cal = heatmapCalendar
        let now = Date()
        guard let refWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return nil }
        // weekIndex: 0..N-1 (dernier = semaine courante)
        let weekOffset = weekIndex - (gridRowCount - 1) // 0 => current week
        guard let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: refWeekStart) else { return nil }
        guard let day = cal.date(byAdding: .day, value: dayIndex, to: weekStart) else { return nil }
        return cal.startOfDay(for: day)
    }

    private var gridRowCount: Int { selectedPeriod.weeksCount }
    
    private var cellHeight: CGFloat {
        switch selectedPeriod {
        case .week, .month: return 60
        case .threeMonths: return 44
        case .sixMonths, .year: return 34
        }
    }
    
    private var isCompactCells: Bool { cellHeight <= 44 }
    
    private func emptyGrid(rows: Int) -> [[WeeklyHeatmapCellModel]] {
        Array(repeating: Array(repeating: .empty, count: 7), count: max(1, rows))
    }
    
    private func computeGrid() -> (grid: [[WeeklyHeatmapCellModel]], bestWorst: (best: (w: Int, d: Int, v: Double)?, worst: (w: Int, d: Int, v: Double)?)) {
        let cal = heatmapCalendar
        let now = Date()
        guard let refWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            return (grid: emptyGrid(rows: gridRowCount), bestWorst: (best: nil, worst: nil))
        }
        
        // Init Nx7 (N semaines incluant la semaine courante)
        var grid = emptyGrid(rows: gridRowCount)
        
        // Index trades into cells (last N weeks including current)
        for trade in appState.trades {
            guard let pnl = appState.netPnL(for: trade) else { continue }
            let day = cal.startOfDay(for: trade.date)
            guard let tradeWeekStart = cal.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
            
            let weekDelta = cal.dateComponents([.weekOfYear], from: tradeWeekStart, to: refWeekStart).weekOfYear ?? 0
            let weekIndex = (gridRowCount - 1) - weekDelta // last row = current week
            guard weekIndex >= 0 && weekIndex < gridRowCount else { continue }

            let weekday = cal.component(.weekday, from: day) - 1 // 0..6 (Sun..Sat)
            guard weekday >= 0 && weekday < 7 else { continue }

            grid[weekIndex][weekday].append(trade: trade, pnl: pnl)
        }

        // Dynamic scaling for colors (par période)
        var maxAbs: Double = 0
        for w in 0..<gridRowCount {
            for d in 0..<7 {
                if let v = grid[w][d].pnlSum {
                    maxAbs = max(maxAbs, abs(v))
                }
            }
        }
        let scale = max(1.0, maxAbs) // avoid /0
        for w in 0..<gridRowCount {
            for d in 0..<7 {
                grid[w][d].colorScaleMaxAbs = scale
            }
        }

        // Best / worst (sur la période)
        var best: (w: Int, d: Int, v: Double)? = nil
        var worst: (w: Int, d: Int, v: Double)? = nil
        for w in 0..<gridRowCount {
            for d in 0..<7 {
                guard let v = grid[w][d].pnlSum else { continue }
                if best == nil || v > (best?.v ?? 0) { best = (w: w, d: d, v: v) }
                if worst == nil || v < (worst?.v ?? 0) { worst = (w: w, d: d, v: v) }
            }
        }
        
        return (grid: grid, bestWorst: (best: best, worst: worst))
    }
    
    @MainActor
    private func rebuildGridIfNeeded() async {
        // ✅ recalcul en amont, jamais au moment du tap
        isGridComputing = true
        defer { isGridComputing = false }
        
        // Laisser le feedback UI respirer (évite micro-freeze si on arrive sur l’écran)
        try? await Task.sleep(nanoseconds: 40_000_000) // 40ms
        
        let computed = computeGrid()
        cachedGrid = computed.grid
        cachedBestWorst = computed.bestWorst
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Heatmap P&L par Semaine")
                        .font(.title2.bold())
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                    
                    VStack(spacing: 12) {
                        // Période (sans changer les calculs, uniquement la fenêtre affichée)
                        HStack {
                            Picker("Période", selection: $selectedPeriod) {
                                ForEach(HeatmapPeriod.allCases, id: \.self) { period in
                                    Text(period.displayName).tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            if isGridComputing {
                                ProgressView()
                                    .scaleEffect(0.75)
                                    .tint(AppColors.textSecondary)
                            }
                        }
                        
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.tap")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(language == .french ? "Touchez une case" : "Tap a day")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundColor(AppColors.textSecondary.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.22))
                                    .overlay(
                                        Capsule()
                                            .stroke(AppColors.border.opacity(0.16), lineWidth: 1)
                                    )
                            )
                            .opacity(didAppear ? 1 : 0)
                            .animation(.easeInOut(duration: 0.25), value: didAppear)
                            
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Text("")
                                .frame(width: 40)
                            
                            ForEach(daysOfWeek, id: \.self) { day in
                                Text(day)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        ForEach(0..<gridRowCount, id: \.self) { weekIndex in
                            HStack(spacing: 8) {
                                Text("S\(weekIndex + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .frame(width: 40)
                                
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    let safeGrid = cachedGrid.isEmpty ? emptyGrid(rows: gridRowCount) : cachedGrid
                                    let cell = safeGrid[weekIndex][dayIndex]
                                    let cellDate = dateForCell(weekIndex: weekIndex, dayIndex: dayIndex)
                                    let emotionLoad = cellDate.flatMap { appState.emotionalLoadByDay[$0] } // 0..100
                                    HeatmapCell(
                                        value: cell.pnlSum,
                                        tradeCount: cell.tradeCount,
                                        scaleMaxAbs: cell.colorScaleMaxAbs,
                                        isBest: cachedBestWorst.best?.w == weekIndex && cachedBestWorst.best?.d == dayIndex,
                                        isWorst: cachedBestWorst.worst?.w == weekIndex && cachedBestWorst.worst?.d == dayIndex,
                                        isCurrentWeek: weekIndex == (gridRowCount - 1),
                                        emotionLoad: emotionLoad,
                                        isSelected: selectedCell?.weekIndex == weekIndex && selectedCell?.dayIndex == dayIndex
                                    ) {
                                        HapticFeedback.selection()
                                        selectedCell = WeeklyHeatmapSelection(
                                            weekIndex: weekIndex,
                                            dayIndex: dayIndex,
                                            dayLabel: daysOfWeek[dayIndex],
                                            pnl: cell.pnlSum,
                                            trades: cell.trades,
                                            colorScaleMaxAbs: cell.colorScaleMaxAbs,
                                            emotionLoad: emotionLoad
                                        )
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                        showingCellDetails = true
                                    }
                                    }
                                    .frame(height: cellHeight)
                                    .environment(\.sizeCategory, .medium) // évite que les très petits cells explosent en Dynamic Type
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.surface2)
                    .cornerRadius(16)
                    
                    HStack(spacing: 20) {
                        HeatmapLegendItem(color: .red, label: "Pertes")
                        HeatmapLegendItem(color: .gray, label: "Neutre")
                        HeatmapLegendItem(color: .green, label: "Gains")
                    }
                    .font(.caption)
                }
                .padding()
            }
            .navigationTitle("Heatmap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCellDetails) {
                if let selection = selectedCell {
                    WeeklyHeatmapCellDetailsSheet(selection: selection, language: language)
                        .environmentObject(appState)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .onAppear { didAppear = true }
            .task { await rebuildGridIfNeeded() }
            .onChange(of: selectedPeriod) { _, _ in
                Task { await rebuildGridIfNeeded() }
            }
            .onReceive(appState.$trades) { _ in
                Task { await rebuildGridIfNeeded() }
            }
        }
    }
}

// MARK: - Heatmap Cell
struct HeatmapCell: View {
    let value: Double?
    let tradeCount: Int
    let scaleMaxAbs: Double
    let isBest: Bool
    let isWorst: Bool
    let isCurrentWeek: Bool
    let emotionLoad: Double? // 0..100
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed: Bool = false
    
    private var intensity: Double {
        guard let v = value else { return 0 }
        let t = min(1.0, abs(v) / max(1.0, scaleMaxAbs))
        // courbe d’intensité un peu non linéaire pour rendre les petites variations lisibles
        return pow(t, 0.65)
    }
    
    private var backgroundColor: Color {
        guard let v = value else { return AppColors.border.opacity(0.18) }
        if v == 0 { return AppColors.border.opacity(0.30) }
        let base = v > 0 ? AppColors.success : AppColors.error
        return base.opacity(0.18 + 0.70 * intensity)
    }
    
    private var emotionTint: Color? {
        guard let v = emotionLoad else { return nil }
        // Bleu/vert doux -> orange -> rouge (pression croissante)
        switch v {
        case ..<25: return Color(hex: "#2DD4BF") // teal
        case ..<55: return Color(hex: "#60A5FA") // soft blue
        case ..<75: return Color(hex: "#FB923C") // orange
        default: return Color(hex: "#F87171") // soft red
        }
    }
    
    private var emotionIntensity: Double {
        guard let v = emotionLoad else { return 0 }
        let t = max(0.0, min(1.0, v / 100.0))
        return pow(t, 0.75)
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    if let value = value {
                        Text(String(format: "%.0f", value))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .monospacedDigit()
                    } else {
                        Text("-")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    if tradeCount > 0, (isSelected || isPressed) {
                        Text("\(tradeCount)t")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.18)))
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                }
                
                if isBest || isWorst {
                    Image(systemName: isBest ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.92))
                        .padding(6)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isSelected ? AppColors.primary.opacity(0.9)
                                : isCurrentWeek ? Color.white.opacity(0.14)
                                : Color.white.opacity(0.10),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .overlay(
                        // ✅ Couche émotionnelle: halo/contour (contextuel) sans écraser le P&L
                        Group {
                            if let tint = emotionTint, emotionIntensity > 0 {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(tint.opacity(0.18 + 0.55 * emotionIntensity), lineWidth: 2)
                                    .shadow(color: tint.opacity(0.12 + 0.25 * emotionIntensity), radius: 10, x: 0, y: 6)
                            }
                        }
                    )
                    .shadow(color: Color.black.opacity(isSelected || isPressed ? 0.25 : 0.12), radius: isSelected || isPressed ? 10 : 6, x: 0, y: 6)
            )
            .scaleEffect((isSelected || isPressed) ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.14), value: isSelected || isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.15, maximumDistance: 24, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.12)) {
                isPressed = pressing
            }
            if pressing { HapticFeedback.selection() }
        }, perform: {
            onTap()
        })
    }
}

// MARK: - Heatmap Legend Item
struct HeatmapLegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 20, height: 20)
            Text(label)
        }
    }
}

// MARK: - Weekly Heatmap Models + Details
private struct WeeklyHeatmapCellModel {
    var trades: [Trade] = []
    var pnlSum: Double? = nil
    var tradeCount: Int { trades.count }
    var colorScaleMaxAbs: Double = 1.0

    static let empty = WeeklyHeatmapCellModel()

    mutating func append(trade: Trade, pnl: Double) {
        trades.append(trade)
        pnlSum = (pnlSum ?? 0) + pnl
    }
}

private struct WeeklyHeatmapSelection: Identifiable {
    let id = UUID()
    let weekIndex: Int
    let dayIndex: Int
    let dayLabel: String
    let pnl: Double?
    let trades: [Trade]
    let colorScaleMaxAbs: Double
    let emotionLoad: Double?
}

private struct WeeklyHeatmapCellDetailsSheet: View {
    @EnvironmentObject var appState: AppState
    let selection: WeeklyHeatmapSelection
    let language: Localizable.Language
    @Environment(\.dismiss) private var dismiss

    private var pnlValue: Double { selection.pnl ?? 0 }
    private var pnlColor: Color { pnlValue >= 0 ? AppColors.success : AppColors.error }

    @State private var didAppear: Bool = false
    @State private var computedTradesWithPnL: [(trade: Trade, pnl: Double)] = []
    @State private var isComputingDetails: Bool = false
    
    private var originIntensity: Double {
        let t = min(1.0, abs(pnlValue) / max(1.0, selection.colorScaleMaxAbs))
        return pow(t, 0.65)
    }
    
    private var originColor: Color {
        if pnlValue == 0 { return AppColors.border.opacity(0.30) }
        let base = pnlValue >= 0 ? AppColors.success : AppColors.error
        return base.opacity(0.18 + 0.70 * originIntensity)
    }
    
    private var emotionLoadValue: Double { selection.emotionLoad ?? 0 }
    private var emotionLoadTint: Color {
        switch emotionLoadValue {
        case ..<25: return Color(hex: "#2DD4BF")
        case ..<55: return Color(hex: "#60A5FA")
        case ..<75: return Color(hex: "#FB923C")
        default: return Color(hex: "#F87171")
        }
    }

    private var tradesWithPnL: [(trade: Trade, pnl: Double)] { computedTradesWithPnL }

    private var winRate: Double {
        guard !tradesWithPnL.isEmpty else { return 0 }
        let wins = tradesWithPnL.filter { $0.pnl > 0 }.count
        return Double(wins) / Double(tradesWithPnL.count) * 100.0
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f
    }()

    private func formatCurrency(_ v: Double) -> String {
        Self.currencyFormatter.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language == .french ? "Détails du jour" : "Day details")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(selection.dayLabel) • S\(selection.weekIndex + 1)")
                                .font(.title3.weight(.bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Big P&L
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language == .french ? "P&L Total" : "Total P&L")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                        Text(formatCurrency(pnlValue))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(pnlColor)
                            .monospacedDigit()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(pnlColor.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .overlay(alignment: .topTrailing) {
                        // Rappel visuel de la case d’origine
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(originColor)
                            .frame(width: 34, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .padding(10)
                            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
                    }

                    // Quick stats
                    HStack(spacing: 12) {
                        statPill(title: language == .french ? "Trades" : "Trades", value: "\(selection.trades.count)", color: AppColors.primary)
                        statPill(title: language == .french ? "Win rate" : "Win rate", value: tradesWithPnL.isEmpty ? "—" : "\(Int(winRate))%", color: pnlColor)
                        let avg = tradesWithPnL.isEmpty ? 0 : (tradesWithPnL.map { $0.pnl }.reduce(0, +) / Double(tradesWithPnL.count))
                        statPill(title: language == .french ? "Moy." : "Avg", value: tradesWithPnL.isEmpty ? "—" : formatCurrency(avg), color: AppColors.textSecondary)
                    }
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 6)
                    .animation(.easeInOut(duration: 0.25), value: didAppear)
                    
                    // Charge émotionnelle (contextuelle, sans jugement)
                    if selection.emotionLoad != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(emotionLoadTint.opacity(0.9))
                            Text(language == .french ? "Charge émotionnelle" : "Emotional load")
                                .font(AppTypography.captionMedium.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text("\(Int(round(emotionLoadValue)))/100")
                                .font(AppTypography.captionMedium.weight(.bold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(emotionLoadTint.opacity(0.28), lineWidth: 1)
                                )
                        )
                    }

                    // Cause → effet (ultra court)
                    if !tradesWithPnL.isEmpty {
                        let dominantSymbol = Dictionary(grouping: tradesWithPnL, by: { $0.trade.symbol })
                            .max(by: { $0.value.count < $1.value.count })?.key
                        let longCount = tradesWithPnL.filter { $0.trade.type == .long }.count
                        let shortCount = tradesWithPnL.filter { $0.trade.type == .short }.count
                        HStack(spacing: 8) {
                            Image(systemName: "sparkline")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(pnlColor.opacity(0.9))
                            Text(
                                [
                                    "\(tradesWithPnL.count) trades",
                                    dominantSymbol.map { "\($0) dominant" },
                                    "\(longCount)L / \(shortCount)S"
                                ]
                                .compactMap { $0 }
                                .joined(separator: " • ")
                            )
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppColors.border.opacity(0.14), lineWidth: 1)
                                )
                        )
                    }

                    Divider().opacity(0.25)

                    Text(language == .french ? "Trades du jour" : "Trades of the day")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if isComputingDetails {
                        HStack(spacing: 10) {
                            ProgressView().scaleEffect(0.9)
                            Text(language == .french ? "Chargement…" : "Loading…")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    } else if tradesWithPnL.isEmpty {
                        Text(language == .french ? "Aucun trade ce jour." : "No trades on this day.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(tradesWithPnL.prefix(12), id: \.trade.id) { item in
                                HeatmapTradeRow(trade: item.trade, pnl: item.pnl)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationBarHidden(true)
            .onAppear { didAppear = true }
            .task {
                guard computedTradesWithPnL.isEmpty else { return }
                isComputingDetails = true
                defer { isComputingDetails = false }
                
                // ✅ async: la sheet apparaît immédiatement, le détail se calcule ensuite
                let computed = selection.trades.compactMap { t -> (Trade, Double)? in
                    guard let pnl = appState.netPnL(for: t) else { return nil }
                    return (t, pnl)
                }
                .sorted { $0.1 > $1.1 }
                
                computedTradesWithPnL = computed.map { (trade: $0.0, pnl: $0.1) }
            }
        }
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

private struct HeatmapTradeRow: View {
    let trade: Trade
    let pnl: Double

    private var pnlColor: Color { pnl >= 0 ? AppColors.success : AppColors.error }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f
    }()

    private func formatCurrency(_ v: Double) -> String {
        Self.currencyFormatter.string(from: NSNumber(value: v)) ?? String(format: "$%.2f", v)
    }

    var body: some View {
        Button {
            // feedback d’interaction (navigation gérée plus haut dans l’app si besoin)
            HapticFeedback.selection()
        } label: {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.symbol)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(trade.type == .long ? "LONG" : "SHORT")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(trade.type == .long ? AppColors.success : AppColors.error)
            }
            Spacer()
            Text(formatCurrency(pnl))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(pnlColor)
                .monospacedDigit()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        }
        .buttonStyle(.plain)
    }
}

