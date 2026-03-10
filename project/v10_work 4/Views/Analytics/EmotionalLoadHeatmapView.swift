import SwiftUI

/// Heatmap dédiée : **Charge émotionnelle** (0–100).
/// - Source unique : `appState.emotionalLoadByDay` (déjà calculée + cachée).
/// - P&L n'intervient pas ici : c'est une lecture de "pression" (pas de jugement).
struct EmotionalLoadHeatmapView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Periods (local scope to avoid module-level name collisions)
    enum HeatmapPeriod: CaseIterable, Identifiable {
        case week
        case month
        case threeMonths
        case sixMonths
        case year
        
        var id: Self { self }
        
        var displayName: String {
            switch self {
            case .week: return "7j"
            case .month: return "1M"
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .year: return "1A"
            }
        }
        
        /// Nombre de semaines affichées.
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
    
    @State private var selectedPeriod: HeatmapPeriod = .month
    @State private var didAppear: Bool = false
    
    // ✅ Pré-calcul / cache pour éviter toute latence au tap
    @State private var cachedGrid: [[Cell]] = []
    @State private var cachedDayDetails: [Date: DayDetails] = [:] // startOfDay -> details
    @State private var isComputing: Bool = false
    
    // Selection / interactions
    @State private var selectedCell: Cell? = nil
    @State private var showingDayDetails: Bool = false
    @State private var previewBanner: PreviewBanner? = nil
    
    private let daysOfWeek = ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "fr_FR")
        cal.firstWeekday = 1 // Sunday
        return cal
    }
    
    private var rowsCount: Int { selectedPeriod.weeksCount }
    
    private var cellHeight: CGFloat {
        switch selectedPeriod {
        case .week, .month: return 60
        case .threeMonths: return 44
        case .sixMonths, .year: return 34
        }
    }
    
    private struct Cell: Identifiable, Equatable {
        let id = UUID()
        let date: Date // startOfDay
        let weekIndex: Int
        let dayIndex: Int
        let load: Double // 0..100
        
        var isEmpty: Bool { load <= 0.0 }
    }
    
    struct DayDetails: Equatable {
        let date: Date
        let load: Double // 0..100
        let pressureLabel: String
        let topEmotions: [EmotionalState]
        let exposureLabel: String?
        let controlLabel: String?
        let planLabel: String?
        let triggerLabels: [String]
    }
    
    private struct PreviewBanner: Equatable {
        let date: Date
        let load: Double
        let label: String
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    heatmapGrid
                    legend
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("emotionalLoad"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("close")) { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                if let previewBanner {
                    previewBannerView(previewBanner)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $showingDayDetails) {
                if let selected = selectedCell {
                    EmotionalLoadDayDetailsSheet(details: cachedDayDetails[selected.date] ?? fallbackDetails(for: selected))
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
            .task {
                didAppear = true
                await rebuildCaches()
            }
            .onChange(of: selectedPeriod) { _, _ in
                Task { await rebuildCaches() }
            }
            .onReceive(appState.$emotionalLoadByDay) { _ in
                Task { await rebuildCaches() }
            }
            .onReceive(appState.$moodEntries) { _ in
                Task { await rebuildCaches() }
            }
            .onReceive(appState.$trades) { _ in
                Task { await rebuildCaches() }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("pressionmotionnelle0100"))
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(t("trades"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if isComputing {
                    ProgressView().scaleEffect(0.9)
                }
            }
            
            Picker("Période", selection: $selectedPeriod) {
                ForEach(HeatmapPeriod.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 12, weight: .semibold))
                    Text(t("touchezUneCase"))
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
        }
    }
    
    private var heatmapGrid: some View {
        let grid = cachedGrid.isEmpty ? buildGrid() : cachedGrid
        
        return VStack(spacing: 12) {
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
            
            ForEach(0..<max(1, rowsCount), id: \.self) { weekIndex in
                HStack(spacing: 8) {
                    // Label de ligne discret (on évite le bruit en année)
                    Text(rowsCount > 13 ? (weekIndex % 4 == 0 ? "S\(weekIndex + 1)" : "") : "S\(weekIndex + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let cell = grid[safe: weekIndex]?[safe: dayIndex] ?? placeholderCell(weekIndex: weekIndex, dayIndex: dayIndex)
                        EmotionalLoadCellView(
                            load: cell.load,
                            isSelected: selectedCell?.date == cell.date
                        ) {
                            HapticFeedback.selection()
                            selectedCell = cell
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingDayDetails = true
                            }
                        } onLongPressPreview: {
                            HapticFeedback.light()
                            showPreview(for: cell)
                        }
                        .frame(height: cellHeight)
                        .environment(\.sizeCategory, .medium)
                    }
                }
            }
        }
        .padding()
        .background(Color.surface2)
        .cornerRadius(16)
    }
    
    private var legend: some View {
        HStack(spacing: 10) {
            legendPill(title: "Faible", color: color(for: 10), load: 10)
            legendPill(title: "Modérée", color: color(for: 35), load: 35)
            legendPill(title: "Élevée", color: color(for: 62), load: 62)
            legendPill(title: "Critique", color: color(for: 88), load: 88)
        }
        .font(.caption2)
        .foregroundColor(AppColors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func legendPill(title: String, color: Color, load: Double) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(opacity(for: load)))
                .frame(width: 14, height: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            Text(title)
                .lineLimit(1)
        }
    }
    
    // MARK: - Cache rebuild (no work in body)
    @MainActor
    private func rebuildCaches() async {
        isComputing = true
        defer { isComputing = false }
        
        // micro-yield pour laisser l'interaction respirer
        try? await Task.sleep(nanoseconds: 30_000_000)
        
        let grid = buildGrid()
        cachedGrid = grid
        
        cachedDayDetails = buildDayDetails(for: grid.flatMap { $0 })
    }
    
    private func buildGrid() -> [[Cell]] {
        guard let refWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return Array(repeating: Array(repeating: placeholderCell(weekIndex: 0, dayIndex: 0), count: 7), count: max(1, rowsCount))
        }
        
        var out: [[Cell]] = Array(repeating: [], count: max(1, rowsCount))
        for w in 0..<max(1, rowsCount) {
            var row: [Cell] = []
            row.reserveCapacity(7)
            for d in 0..<7 {
                let weekOffset = w - (rowsCount - 1)
                let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: refWeekStart) ?? refWeekStart
                let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: d, to: weekStart) ?? weekStart)
                let load = appState.emotionalLoadByDay[day] ?? 0
                row.append(Cell(date: day, weekIndex: w, dayIndex: d, load: load))
            }
            out[w] = row
        }
        return out
    }
    
    private func buildDayDetails(for cells: [Cell]) -> [Date: DayDetails] {
        // On ne calcule que sur les dates visibles (période) -> stable et instant.
        let visibleDays = Set(cells.map(\.date))
        
        // Pre-index trades by id (exposition via leverage)
        let tradesById = Dictionary(uniqueKeysWithValues: appState.trades.map { ($0.id, $0) })
        
        // Group moods by day
        let moodsByDay = Dictionary(grouping: appState.moodEntries) { calendar.startOfDay(for: $0.timestamp) }
        
        var out: [Date: DayDetails] = [:]
        out.reserveCapacity(visibleDays.count)
        
        for day in visibleDays {
            let load = appState.emotionalLoadByDay[day] ?? 0
            let moods = moodsByDay[day] ?? []
            
            // Dominant emotions (prefer afterTrade)
            let after = moods.filter { $0.context == .afterTrade }
            let source = after.isEmpty ? moods : after
            let emotionCounts = Dictionary(grouping: source, by: { $0.emotionalState }).mapValues { $0.count }
            let topEmotions = emotionCounts
                .sorted(by: { $0.value > $1.value })
                .prefix(2)
                .map(\.key)
            
            // Amplifiers (proxies, non-judgment)
            // Exposure (from linked trades leverage)
            let linkedTrades: [Trade] = source.compactMap { $0.tradeId }.compactMap { tradesById[$0] }
            let maxLev = linkedTrades.map(\.leverage).max() ?? 1.0
            let exposureLabel: String? = maxLev >= 8 ? "Exposition élevée (lev \(Int(maxLev))x)"
                : maxLev >= 3 ? "Exposition modérée (lev \(Int(maxLev))x)"
                : nil
            
            // Control (lower control -> more pressure)
            let controls = source.compactMap(\.controlLevel)
            let avgControl = controls.isEmpty ? nil : Double(controls.reduce(0, +)) / Double(controls.count)
            let controlLabel: String? = {
                guard let avgControl else { return nil }
                if avgControl < 4 { return "Contrôle bas (≈\(Int(avgControl))/10)" }
                if avgControl < 7 { return "Contrôle modéré (≈\(Int(avgControl))/10)" }
                return nil
            }()
            
            // Plan / prep proxy: look for beforeTrade checklist for same tradeIds
            let beforeTradeByTradeId: [UUID: MoodEntry] = Dictionary(
                moods
                    .filter { $0.context == .beforeTrade && $0.tradeId != nil }
                    .compactMap { m in
                        guard let id = m.tradeId else { return nil }
                        return (id, m)
                    },
                uniquingKeysWith: { first, _ in first }
            )

            var missingChecklistCount = 0
            for t in linkedTrades {
                if let m = beforeTradeByTradeId[t.id], let checklist = m.checklistBeforeTrade {
                    let flags: [Bool] = [checklist.planClear, checklist.stopDefined, checklist.riskAccepted, checklist.noRevenge, checklist.noUrgency]
                    missingChecklistCount += flags.filter { !$0 }.count
                }
            }
            let planLabel: String? = missingChecklistCount >= 3 ? "Prépa incomplète (checklist)"
                : missingChecklistCount > 0 ? "Prépa partielle (checklist)"
                : nil
            
            // Triggers
            let triggers = source.compactMap(\.trigger).map(\.chipLabel)
            let topTriggers = Array(Dictionary(grouping: triggers, by: { $0 })
                .mapValues { $0.count }
                .sorted(by: { $0.value > $1.value })
                .prefix(2)
                .map(\.key))
            
            out[day] = DayDetails(
                date: day,
                load: load,
                pressureLabel: pressureLabel(for: load),
                topEmotions: topEmotions,
                exposureLabel: exposureLabel,
                controlLabel: controlLabel,
                planLabel: planLabel,
                triggerLabels: topTriggers
            )
        }
        
        return out
    }
    
    private func fallbackDetails(for cell: Cell) -> DayDetails {
        DayDetails(
            date: cell.date,
            load: cell.load,
            pressureLabel: pressureLabel(for: cell.load),
            topEmotions: [],
            exposureLabel: nil,
            controlLabel: nil,
            planLabel: nil,
            triggerLabels: []
        )
    }
    
    private func placeholderCell(weekIndex: Int, dayIndex: Int) -> Cell {
        Cell(date: calendar.startOfDay(for: Date()), weekIndex: weekIndex, dayIndex: dayIndex, load: 0)
    }
    
    // MARK: - Long press preview (no navigation)
    private func showPreview(for cell: Cell) {
        guard cell.load > 0 else { return }
        let banner = PreviewBanner(date: cell.date, load: cell.load, label: pressureLabel(for: cell.load))
        withAnimation(.easeInOut(duration: 0.15)) { previewBanner = banner }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) { previewBanner = nil }
            }
        }
    }
    
    private func previewBannerView(_ banner: PreviewBanner) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color(for: banner.load).opacity(opacity(for: banner.load)))
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    banner.date.formatted(
                        date: Date.FormatStyle.DateStyle.abbreviated,
                        time: Date.FormatStyle.TimeStyle.omitted
                    )
                )
                    .font(AppTypography.captionSmall.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                Text("Charge: \(Int(round(banner.load * 100)))% – \(banner.label)")
                    .font(AppTypography.captionMedium.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.border.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, AppSpacing.lg)
    }
    
    // MARK: - Color mapping (non-moralisant)
    private func color(for load: Double) -> Color {
        switch load {
        case ..<20: return Color(hex: "#2DD4BF") // teal/soft stability
        case ..<50: return Color(hex: "#A3E635") // green-yellow soft
        case ..<75: return Color(hex: "#FB923C") // orange
        default: return Color(hex: "#F87171") // soft red
        }
    }
    
    private func opacity(for load: Double) -> Double {
        let t = max(0.0, min(1.0, load / 100.0))
        // évite les contrastes brutaux
        return 0.10 + 0.75 * pow(t, 0.85)
    }
    
    private func pressureLabel(for load: Double) -> String {
        switch load {
        case ..<20: return "pression faible"
        case ..<50: return "pression modérée"
        case ..<75: return "pression élevée"
        default: return "pression critique"
        }
    }
}

// MARK: - Cell View (instant)
private struct EmotionalLoadCellView: View {
    let load: Double
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPressPreview: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button { onTap() } label: {
            ZStack(alignment: .topTrailing) {
                if load > 0, (isSelected || isPressed) {
                    Text("\(Int(round(load)))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .padding(6)
                        .transition(.opacity)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? AppColors.primary.opacity(0.9) : Color.white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: Color.black.opacity(isSelected || isPressed ? 0.22 : 0.10), radius: isSelected || isPressed ? 10 : 6, x: 0, y: 6)
            )
            .scaleEffect((isSelected || isPressed) ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.14), value: isSelected || isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 24, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.12)) { isPressed = pressing }
            if pressing { onLongPressPreview() }
        }, perform: {})
    }
    
    private var fillColor: Color {
        guard load > 0 else { return AppColors.border.opacity(0.18) }
        let color = colorFor(load)
        return color.opacity(opacityFor(load))
    }
    
    private func colorFor(_ load: Double) -> Color {
        switch load {
        case ..<20: return Color(hex: "#2DD4BF")
        case ..<50: return Color(hex: "#A3E635")
        case ..<75: return Color(hex: "#FB923C")
        default: return Color(hex: "#F87171")
        }
    }
    
    private func opacityFor(_ load: Double) -> Double {
        let t = max(0.0, min(1.0, load / 100.0))
        return 0.10 + 0.75 * pow(t, 0.85)
    }
}

// MARK: - Day Details Sheet (compact "cause → effet")
private struct EmotionalLoadDayDetailsSheet: View {
    let details: EmotionalLoadHeatmapView.DayDetails
    @Environment(\.dismiss) private var dismiss
    
    private var tint: Color {
        switch details.load {
        case ..<20: return Color(hex: "#2DD4BF")
        case ..<50: return Color(hex: "#A3E635")
        case ..<75: return Color(hex: "#FB923C")
        default: return Color(hex: "#F87171")
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("ai"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                            Text(
                                details.date.formatted(
                                    date: Date.FormatStyle.DateStyle.complete,
                                    time: Date.FormatStyle.TimeStyle.omitted
                                )
                            )
                                .font(.title3.weight(.bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    // Score principal
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("chargemotionnelle"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                            Text(t("ai"))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(tint)
                                .monospacedDigit()
                        }
                        Spacer()
                        Text(details.pressureLabel)
                            .font(AppTypography.captionMedium.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(tint.opacity(0.28))
                            )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(tint.opacity(0.22), lineWidth: 1)
                            )
                    )
                    
                    // Décomposition (compacte)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("dcomposition"))
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        if !details.topEmotions.isEmpty {
                            row(title: "Émotions dominantes", value: details.topEmotions.map(\.displayName).joined(separator: " • "), icon: "heart.fill")
                        } else {
                            row(title: "Émotions dominantes", value: "—", icon: "heart")
                        }
                        
                        let factors = [details.exposureLabel, details.controlLabel, details.planLabel].compactMap { $0 }
                        row(title: "Facteurs", value: factors.isEmpty ? "—" : factors.joined(separator: " • "), icon: "sparkline")
                        
                        if !details.triggerLabels.isEmpty {
                            row(title: "Déclencheurs", value: details.triggerLabels.joined(separator: " • "), icon: "bolt.fill")
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppColors.border.opacity(0.14), lineWidth: 1)
                            )
                    )
                    
                    Text(t("trades"))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func row(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint.opacity(0.9))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.captionSmall.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                Text(value)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

// MARK: - Safe indexing
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}


