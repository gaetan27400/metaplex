//
//  SystemsView.swift
//  Journal de trading 2025
//

import SwiftUI
import Charts
import Darwin

struct SystemsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @ObservedObject private var appState = AppState.shared
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "fr"
    @State private var showingAddSystem = false
    @State private var searchText: String = ""
    @State private var displayMode: SystemDisplayMode = .spider
    @State private var sort: SystemSort = .mostTraded
    @State private var filter: SystemFilter = .all
    @State private var highlightedSystemId: UUID? = nil
    @State private var spiderScope: SpiderScope = .all
    
    var body: some View {
        NavigationStack {
            mainContent
                .background(Color.black)
                .navigationBarHidden(true)
                .sheet(isPresented: $showingAddSystem) {
                    addSystemSheet
                }
        }
        .navigationViewStyle(.stack)
    }
    
    private var mainContent: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    performanceHeader
                    searchBar
                    controlsRow
                    systemsContent
                }
                // ✅ permet de scroller le dernier bloc (ex: détails du système) AU-DESSUS de la bottom bar
                .padding(.bottom, 24)
            }
    }
    
    private var addSystemSheet: some View {
        AddSystemView(language: languageBinding)
    }
    
    private var languageBinding: Binding<Localizable.Language> {
        Binding(
                    get: {
                        let lang = Localizable.Language(rawValue: selectedLanguage)
                        return lang ?? Localizable.Language.allCases.first!
                    },
                    set: { selectedLanguage = $0.rawValue }
        )
    }
    
    // MARK: - Derived
    private var language: Localizable.Language {
        Localizable.Language(rawValue: selectedLanguage) ?? .french
    }

    private var systemsWithMetrics: [SystemMetrics] {
        // Dédupliquer les systèmes par id pour éviter les doublons (notamment sur iPad)
        var seen = Set<UUID>()
        let uniqueSystems = appState.systems.filter { seen.insert($0.id).inserted }
        let metrics = uniqueSystems.map { system in
            let trades = appState.trades.filter { $0.systemId == system.id }
            return SystemMetrics(system: system, trades: trades, appState: appState)
        }

        let searched = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? metrics
        : metrics.filter { $0.system.name.localizedCaseInsensitiveContains(searchText) }

        let filtered: [SystemMetrics]
        switch filter {
        case .all:
            filtered = searched
        case .withTrades:
            filtered = searched.filter { $0.totalTrades > 0 }
        case .withoutTrades:
            filtered = searched.filter { $0.totalTrades == 0 }
        }

        switch sort {
        case .mostTraded:
            return filtered.sorted { $0.totalTrades > $1.totalTrades }
        case .bestWinRate:
            return filtered.sorted { $0.overallWinRate > $1.overallWinRate }
        case .worstWinRate:
            return filtered.sorted { $0.overallWinRate < $1.overallWinRate }
        case .name:
            return filtered.sorted { $0.system.name.localizedCaseInsensitiveCompare($1.system.name) == .orderedAscending }
        }
    }

    private var spiderSystems: [SystemMetrics] {
        // ⚠️ Radar: on peut limiter pour la lisibilité tout en gardant Grid/List pour le détail.
        let sorted = systemsWithMetrics.sorted { $0.totalTrades > $1.totalTrades }
        switch spiderScope {
        case .all:
            return sorted
        case .top10:
            return Array(sorted.prefix(10))
        case .top15:
            return Array(sorted.prefix(15))
        }
    }
    
    // MARK: - Performance Header
    private var performanceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(language == .french ? "Performance par Système" : "Performance by System")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
                // Add System button (aligné avec le titre)
                Button(action: {
                    HapticFeedback.light()
                    showingAddSystem = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(14)
                        .background(
                            Circle()
                                .fill(AppColors.cardBackground.opacity(0.85))
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.primary.opacity(0.25), lineWidth: 1.5)
                                )
                        )
                        .shadow(color: AppColors.primary.opacity(0.25), radius: 10, x: 0, y: 6)
                }
            }

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Circle().fill(AppColors.success).frame(width: 8, height: 8)
                    Text(t("long")).font(.caption.weight(.semibold)).foregroundColor(AppColors.textSecondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(AppColors.error).frame(width: 8, height: 8)
                    Text(t("short")).font(.caption.weight(.semibold)).foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
            }

    // MARK: - Search
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
            TextField(language == .french ? "Rechercher un système..." : "Search a system...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GlassCard(cornerRadius: 18, strokeOpacity: 0.10))
        .padding(.horizontal)
    }

    // MARK: - Controls
    @State private var showingFiltersSheet = false
    
    private var controlsRow: some View {
        HStack(spacing: 12) {
            // Bouton Filtres qui ouvre le bottom sheet
                    Button {
                        HapticFeedback.selection()
                showingFiltersSheet = true
                    } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                    Text(language == .french ? "Filtres" : "Filters")
                        .font(.system(size: 14, weight: .semibold))
                    // Badge si filtres actifs (hors défaut)
                    if filter != .all || sort != .mostTraded {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(AppColors.cardBackground.opacity(0.65))
                        .overlay(
                            Capsule()
                                .stroke(AppColors.border.opacity(0.3), lineWidth: 1.2)
                        )
                )
            }
            
            Spacer()
            
            // Mode d'affichage (toujours visible car principal)
            Menu {
                ForEach(SystemDisplayMode.allCases, id: \.self) { mode in
                    Button {
                        HapticFeedback.selection()
                        displayMode = mode
                    } label: {
                        Label(mode.title(language: language), systemImage: mode.icon)
                    }
                }
            } label: {
                FilterPill(icon: displayMode.icon, title: displayMode.shortTitle(language: language), tint: AppColors.primary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .sheet(isPresented: $showingFiltersSheet) {
            FiltersBottomSheet(
                sort: $sort,
                filter: $filter,
                language: language
            )
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var systemsContent: some View {
        switch displayMode {
        case .grid:
            gridContent
        case .list:
            listContent
        case .spider:
            spiderContent
        case .heatmap:
            heatmapContent
        }
    }
    
    private var gridContent: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(systemsWithMetrics) { metrics in
                    SystemPerformanceCard(metrics: metrics, isHighlighted: metrics.id == highlightedSystemId)
                        .onTapGesture {
                        handleSystemTap(metrics.id)
                        }
                }
            }
            
            // Détail du système sélectionné
            if let selected = systemsWithMetrics.first(where: { $0.id == highlightedSystemId }) {
                SpiderSelectedDetailsCard(metrics: selected, language: language)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal)
    }

    private var listContent: some View {
        VStack(spacing: 10) {
            LazyVStack(spacing: 10) {
                ForEach(systemsWithMetrics) { metrics in
                    SystemPerformanceRow(metrics: metrics, isHighlighted: metrics.id == highlightedSystemId)
                        .onTapGesture {
                        handleSystemTap(metrics.id)
                        }
                }
            }
            
            // Détail du système sélectionné
            if let selected = systemsWithMetrics.first(where: { $0.id == highlightedSystemId }) {
                SpiderSelectedDetailsCard(metrics: selected, language: language)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal)
    }

    private var spiderContent: some View {
        VStack(alignment: .leading, spacing: 12) {
        HStack {
            Spacer()
                // Cacher le segmented control si moins de 10 systèmes
                if systemsWithMetrics.count >= 10 {
                    Picker("", selection: $spiderScope) {
                        ForEach(SpiderScope.allCases, id: \.self) { scope in
                            Text(scope.title(language: language)).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                }
                SystemsSpiderChartView(
                    systems: spiderSystems,
                    highlightedSystemId: $highlightedSystemId,
                    language: language
                )
                if spiderSystems.count > 18 {
                    Text(language == .french ? "Astuce : utilisez Grille/Liste pour le détail." : "Tip: use Grid/List for details.")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                // ✅ plus d'espace pour que la carte de détails puisse scroller au-dessus de la bottom bar
                Color.clear.frame(height: 140)
            }
            .padding(.horizontal)
    }

    private var heatmapContent: some View {
            SystemsHeatmapPlaceholderView(systems: systemsWithMetrics, language: language)
                    .padding(.horizontal)
            }
    
    private func handleSystemTap(_ systemId: UUID) {
        HapticFeedback.selection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            highlightedSystemId = (highlightedSystemId == systemId) ? nil : systemId
            }
        }
    }
    
// MARK: - Display Modes / Sorting
enum SystemDisplayMode: CaseIterable {
    case grid, list, spider, heatmap

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        // `chart.radar` n'est pas dispo partout -> icône sûre
        case .spider: return "hexagon"
        case .heatmap: return "flame"
        }
    }

    func title(language: Localizable.Language) -> String {
        switch (self, language) {
        case (.grid, .french): return "Grille"
        case (.grid, _): return "Grid"
        case (.list, .french): return "Liste"
        case (.list, _): return "List"
        case (.spider, .french): return "Araignée"
        case (.spider, _): return "Spider"
        case (.heatmap, .french): return "Heatmap"
        case (.heatmap, _): return "Heatmap"
        }
    }

    func shortTitle(language: Localizable.Language) -> String {
        // Ici on colle à la maquette (libellés courts)
        title(language: language)
    }
}

enum SystemSort: CaseIterable {
    case mostTraded, bestWinRate, worstWinRate, name

    func title(language: Localizable.Language) -> String {
        switch (self, language) {
        case (.mostTraded, .french): return "Plus tradés"
        case (.mostTraded, _): return "Most traded"
        case (.bestWinRate, .french): return "Meilleur winrate"
        case (.bestWinRate, _): return "Best win rate"
        case (.worstWinRate, .french): return "Pire winrate"
        case (.worstWinRate, _): return "Worst win rate"
        case (.name, .french): return "Nom"
        case (.name, _): return "Name"
        }
    }
}

enum SystemFilter: CaseIterable {
    case all, withTrades, withoutTrades

    func title(language: Localizable.Language) -> String {
        switch (self, language) {
        case (.all, .french): return "Tous"
        case (.all, _): return "All"
        case (.withTrades, .french): return "Avec trades"
        case (.withTrades, _): return "With trades"
        case (.withoutTrades, .french): return "Sans trades"
        case (.withoutTrades, _): return "No trades"
        }
    }
}

enum SpiderScope: CaseIterable {
    case all, top10, top15

    func title(language: Localizable.Language) -> String {
        switch (self, language) {
        case (.all, .french): return "Tous"
        case (.all, _): return "All"
        case (.top10, .french): return "Top 10"
        case (.top10, _): return "Top 10"
        case (.top15, .french): return "Top 15"
        case (.top15, _): return "Top 15"
        }
    }
}

// MARK: - Metrics
struct SystemMetrics: Identifiable {
    let id: UUID
    let system: TradingSystem
    let totalTrades: Int
    let longTrades: Int
    let shortTrades: Int
    let longWinRate: Double // 0..100
    let shortWinRate: Double // 0..100
    let overallWinRate: Double // 0..100
    let netPnL: Double

    init(system: TradingSystem, trades: [Trade], appState: AppState) {
        self.id = system.id
        self.system = system
        self.totalTrades = trades.count
        let longs = trades.filter { $0.type == .long }
        let shorts = trades.filter { $0.type == .short }
        self.longTrades = longs.count
        self.shortTrades = shorts.count

        func winRate(for trades: [Trade]) -> Double {
            guard !trades.isEmpty else { return 0 }
            let wins = trades.filter { (appState.netPnL(for: $0) ?? 0) > 0 }.count
            return Double(wins) / Double(trades.count) * 100.0
        }

        self.longWinRate = winRate(for: longs)
        self.shortWinRate = winRate(for: shorts)
        self.overallWinRate = winRate(for: trades)
        self.netPnL = trades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
    }
}

// MARK: - Cards
private struct SystemPerformanceCard: View {
    let metrics: SystemMetrics
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: metrics.system.color))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

                Text(metrics.system.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                Text("\(Int(metrics.overallWinRate))% WR")
                        .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }

            // L row
            SystemBarRow(label: "L", color: AppColors.success, value: metrics.longWinRate, rightText: "\(metrics.longTrades)")

            // S row
            SystemBarRow(label: "S", color: AppColors.error, value: metrics.shortWinRate, rightText: "\(metrics.shortTrades)")

            HStack {
                Text(t("trades"))
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                // (le % est dans le badge du header)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHighlighted ? AppColors.primary.opacity(0.65) : Color.white.opacity(0.08), lineWidth: isHighlighted ? 2 : 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

private struct SystemPerformanceRow: View {
    let metrics: SystemMetrics
    let isHighlighted: Bool

    @ObservedObject private var appState = AppState.shared
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "fr"
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSystem = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var language: Localizable.Language {
        Localizable.Language(rawValue: selectedLanguage) ?? .french
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: metrics.system.color))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

                    Text(metrics.system.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }
                SystemBarRow(label: "L", color: AppColors.success, value: metrics.longWinRate, rightText: "\(metrics.longTrades)")
                SystemBarRow(label: "S", color: AppColors.error, value: metrics.shortWinRate, rightText: "\(metrics.shortTrades)")
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(Int(metrics.overallWinRate))% WR")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                Text(t("trades"))
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)

                Menu {
                    Button(action: {
                        HapticFeedback.selection()
                        showingEditSystem = true
                    }) {
                        Label(language == .french ? "Modifier" : "Edit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive, action: {
                        HapticFeedback.medium()
                        showingDeleteConfirmation = true
                    }) {
                        Label(language == .french ? "Supprimer" : "Delete", systemImage: "trash")
                    }
                    .disabled(isDeleting)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHighlighted ? AppColors.primary.opacity(0.65) : Color.white.opacity(0.08), lineWidth: isHighlighted ? 2 : 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                HapticFeedback.medium()
                showingDeleteConfirmation = true
            } label: {
                Label(language == .french ? "Supprimer" : "Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            language == .french ? "Supprimer \(metrics.system.name) ?" : "Delete \(metrics.system.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(language == .french ? "Supprimer" : "Delete", role: .destructive) {
                Task { await deleteSystem() }
            }
            Button(language == .french ? "Annuler" : "Cancel", role: .cancel) {}
        } message: {
            Text(language == .french
                 ? "Cette action est irréversible. Les trades associés seront réassignés."
                 : "This action cannot be undone. Associated trades will be reassigned.")
        }
        .alert(language == .french ? "Erreur" : "Error",
               isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            if let error = deleteError { Text(error) }
        }
        .sheet(isPresented: $showingEditSystem) {
            EditSystemView(
                system: metrics.system,
                language: Binding(
                    get: { Localizable.Language(rawValue: selectedLanguage) ?? .french },
                    set: { selectedLanguage = $0.rawValue }
                )
            )
            .environmentObject(appState)
        }
    }

    @MainActor
    private func deleteSystem() async {
        isDeleting = true
        deleteError = nil
        do {
            try await appState.deleteSystem(metrics.system)
            HapticFeedback.success()
        } catch let error as AppState.SystemDeletionError {
            deleteError = error.localizedDescription
            HapticFeedback.error()
        } catch {
            deleteError = language == .french
                ? "Erreur lors de la suppression : \(error.localizedDescription)"
                : "Deletion error: \(error.localizedDescription)"
            HapticFeedback.error()
        }
        isDeleting = false
    }
}

private struct SystemBarRow: View {
    let label: String
    let color: Color
    let value: Double // 0..100
    let rightText: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
                .frame(width: 10, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(height: 8)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, value / 100))), height: 8)
                }
            }
            .frame(height: 8)

            Text(rightText)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

    // MARK: - Heatmap (Matrix Implementation)
private struct SystemsHeatmapPlaceholderView: View {
    let systems: [SystemMetrics]
    let language: Localizable.Language
        
        @State private var selectedViewMode: ViewMode = .matrix
        @State private var selectedMetric: HeatmapMetric = .winRate
        @State private var sortBy: SortOption = .name
        
        enum ViewMode: String, CaseIterable {
            case matrix = "Matrix"
            case single = "Single"
            
            var frenchLabel: String {
                switch self {
                case .matrix: return "Matrice"
                case .single: return "Simple"
                }
            }
        }
        
        enum SortOption: String, CaseIterable {
            case name = "Name"
            case winRate = "Win Rate"
            case pnl = "P&L"
            case trades = "Trades"
            
            var frenchLabel: String {
                switch self {
                case .name: return "Nom"
                case .winRate: return "Taux de réussite"
                case .pnl: return "P&L"
                case .trades: return "Trades"
                }
            }
        }
        
        enum HeatmapMetric: String, CaseIterable {
            case winRate = "Win Rate"
            case longWinRate = "Long WR"
            case shortWinRate = "Short WR"
            case netPnL = "P&L"
            case totalTrades = "Trades"
            
            var frenchLabel: String {
                switch self {
                case .winRate: return "Taux de réussite"
                case .longWinRate: return "WR Long"
                case .shortWinRate: return "WR Short"
                case .netPnL: return "P&L"
                case .totalTrades: return "Trades"
                }
            }
            
            var icon: String {
                switch self {
                case .winRate: return "target"
                case .longWinRate: return "arrow.up.circle"
                case .shortWinRate: return "arrow.down.circle"
                case .netPnL: return "dollarsign.circle"
                case .totalTrades: return "number.circle"
                }
            }
            
            func value(for metrics: SystemMetrics) -> Double {
                switch self {
                case .winRate: return metrics.overallWinRate
                case .longWinRate: return metrics.longWinRate
                case .shortWinRate: return metrics.shortWinRate
                case .netPnL: return metrics.netPnL
                case .totalTrades: return Double(metrics.totalTrades)
                }
            }
            
            func maxValue(for systems: [SystemMetrics]) -> Double {
                let values = systems.map { value(for: $0) }
                return values.max() ?? 100
            }
            
            func minValue(for systems: [SystemMetrics]) -> Double {
                let values = systems.map { value(for: $0) }
                return values.min() ?? 0
            }
            
            func colorScheme() -> (low: Color, high: Color) {
                switch self {
                case .winRate, .longWinRate, .shortWinRate:
                    return (AppColors.error.opacity(0.3), AppColors.success.opacity(0.8))
                case .netPnL:
                    return (AppColors.error.opacity(0.4), AppColors.success.opacity(0.7))
                case .totalTrades:
                    return (AppColors.primary.opacity(0.2), AppColors.primary.opacity(0.8))
                }
            }
        }
        
        private var sortedSystems: [SystemMetrics] {
            let sorted = systems.sorted { s1, s2 in
                switch sortBy {
                case .name:
                    return s1.system.name < s2.system.name
                case .winRate:
                    return s1.overallWinRate > s2.overallWinRate
                case .pnl:
                    return s1.netPnL > s2.netPnL
                case .trades:
                    return s1.totalTrades > s2.totalTrades
                }
            }
            return sorted
        }

    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header avec contrôles
                VStack(spacing: 12) {
                    HStack {
                        Text(language == .french ? "Heatmap Comparaison" : "Comparison Heatmap")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        
                        // Mode de vue
                        Menu {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Button {
                                    HapticFeedback.selection()
                                    selectedViewMode = mode
                                } label: {
                                    HStack {
                                        Text(language == .french ? mode.frenchLabel : mode.rawValue)
                                        if selectedViewMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: selectedViewMode == .matrix ? "square.grid.3x3" : "square")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(AppColors.cardBackground.opacity(0.65))
                                )
                        }
                    }
                    
                    // Contrôles de tri et métrique (uniquement en mode single)
                    if selectedViewMode == .single {
                        HStack(spacing: 10) {
                            Menu {
                                ForEach(HeatmapMetric.allCases, id: \.self) { metric in
                                    Button {
                                        HapticFeedback.selection()
                                        selectedMetric = metric
                                    } label: {
                                        HStack {
                                            Image(systemName: metric.icon)
                                            Text(language == .french ? metric.frenchLabel : metric.rawValue)
                                            if selectedMetric == metric {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: selectedMetric.icon)
                                    Text(language == .french ? selectedMetric.frenchLabel : selectedMetric.rawValue)
                        .font(.caption.weight(.semibold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AppColors.cardBackground.opacity(0.65))
                                        .overlay(
                                            Capsule()
                                                .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            
                            Spacer()
                            
                            // Tri
                            Menu {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button {
                                        HapticFeedback.selection()
                                        sortBy = option
                                    } label: {
                                        HStack {
                                            Text(language == .french ? option.frenchLabel : option.rawValue)
                                            if sortBy == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text(language == .french ? sortBy.frenchLabel : sortBy.rawValue)
                                        .font(.caption.weight(.semibold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AppColors.cardBackground.opacity(0.65))
                                        .overlay(
                                            Capsule()
                                                .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
                
                if systems.isEmpty {
                    Text(language == .french ? "Aucun système avec des trades" : "No systems with trades")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    if selectedViewMode == .matrix {
                        matrixView
                    } else {
                        singleMetricView
                    }
                }
            }
        }
        
        // MARK: - Matrix View (Toutes les métriques en une fois)
        private var matrixView: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // En-tête avec noms des métriques
                    HStack(spacing: 0) {
                        // Colonne système (fixe)
                        Text(language == .french ? "Système" : "System")
                            .font(.caption.weight(.bold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 100, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.3))
                        
                        // Colonnes métriques
                        ForEach(HeatmapMetric.allCases, id: \.self) { metric in
                            VStack(spacing: 4) {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 12))
                                Text(language == .french ? metric.frenchLabel : metric.rawValue)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 80, height: 50)
                            .background(Color.black.opacity(0.2))
                        }
                    }
                    
                    // Lignes de données
                    ForEach(sortedSystems) { system in
                        HStack(spacing: 0) {
                            // Nom du système
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: system.system.color))
                                    .frame(width: 8, height: 8)
                                Text(system.system.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundColor(.white)
                            .frame(width: 100, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.15))
                            
                            // Cellules de métriques
                            ForEach(HeatmapMetric.allCases, id: \.self) { metric in
                                let minVal = metric.minValue(for: sortedSystems)
                                let maxVal = metric.maxValue(for: sortedSystems)
                                SystemsHeatmapCell(
                                    system: system,
                                    metric: metric,
                                    minValue: minVal,
                                    maxValue: maxVal,
                                    language: language
                                )
                                .frame(width: 80, height: 50)
                            }
                        }
                    }
                }
            }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.vertical, 8)
        }
        
        // MARK: - Single Metric View
        private var singleMetricView: some View {
            VStack(spacing: 12) {
                let maxVal = selectedMetric.maxValue(for: systems)
                let minVal = selectedMetric.minValue(for: systems)
                let range = max(maxVal - minVal, 1)
                let colors = selectedMetric.colorScheme()
                
                ForEach(sortedSystems) { m in
                    let value = selectedMetric.value(for: m)
                    let normalized = (value - minVal) / range
                    let intensity = max(0.2, min(1.0, normalized))
                    
                    HStack(spacing: 12) {
                        // Indicateur couleur système
                        Circle()
                            .fill(Color(hex: m.system.color))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        
                        // Nom du système
                        Text(m.system.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Valeur
                        Text(formatValue(value, metric: selectedMetric))
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .frame(width: 70, alignment: .trailing)
                        
                        // Barre de progression visuelle
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                    .cornerRadius(3)
                                
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [colors.low, colors.high],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(intensity), height: 6)
                                    .cornerRadius(3)
                            }
                        }
                        .frame(height: 6)
                        .frame(width: 100)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colors.high.opacity(intensity * 0.15),
                                        colors.low.opacity(intensity * 0.05)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                
                // Légende
                HStack {
                    Text(language == .french ? "Min" : "Min")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [colors.low, colors.high],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)
                        .cornerRadius(4)
                    Spacer()
                    Text(language == .french ? "Max" : "Max")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.top, 8)
            }
        }
        
        private func formatValue(_ value: Double, metric: HeatmapMetric) -> String {
            switch metric {
            case .winRate, .longWinRate, .shortWinRate:
                return "\(Int(value))%"
            case .netPnL:
                if abs(value) >= 1000 {
                    return String(format: "%.1fk", value / 1000)
                } else {
                    return String(format: "%.0f", value)
                }
            case .totalTrades:
                return "\(Int(value))"
            }
        }
    }
    
    // MARK: - Systems Heatmap Cell Component
    private struct SystemsHeatmapCell: View {
        let system: SystemMetrics
        let metric: SystemsHeatmapPlaceholderView.HeatmapMetric
        let minValue: Double
        let maxValue: Double
        let language: Localizable.Language
        
        private var value: Double {
            metric.value(for: system)
        }
        
        private var normalizedIntensity: CGFloat {
            let range = max(maxValue - minValue, 1)
            let normalized = (value - minValue) / range
            return CGFloat(max(0.2, min(1.0, normalized)))
        }
        
        private var colors: (low: Color, high: Color) {
            metric.colorScheme()
        }
        
        var body: some View {
            VStack(spacing: 4) {
                Text(formatValue(value))
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                
                // Indicateur visuel
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                colors.low.opacity(0.3),
                                colors.high.opacity(normalizedIntensity)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                    .cornerRadius(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        colors.high.opacity(normalizedIntensity * 0.2),
                        colors.low.opacity(normalizedIntensity * 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        
        private func formatValue(_ value: Double) -> String {
            switch metric {
            case .winRate, .longWinRate, .shortWinRate:
                return "\(Int(value))%"
            case .netPnL:
                if abs(value) >= 1000 {
                    return String(format: "%.1fk", value / 1000)
                } else {
                    return String(format: "%.0f", value)
                }
            case .totalTrades:
                return "\(Int(value))"
            }
    }
}

// MARK: - Modern UI helpers
private struct GlassCard: View {
    let cornerRadius: CGFloat
    let strokeOpacity: Double

    init(cornerRadius: CGFloat = 16, strokeOpacity: Double = 0.12) {
        self.cornerRadius = cornerRadius
        self.strokeOpacity = strokeOpacity
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.cardBackground.opacity(0.75))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

private struct FilterPill: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppColors.cardBackground.opacity(0.65))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.35), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Spider / Radar chart (interactive)
private struct SystemsSpiderChartView: View {
    let systems: [SystemMetrics]
    @Binding var highlightedSystemId: UUID?
    let language: Localizable.Language

    @State private var tooltip: SpiderTooltip? = nil

    struct SpiderTooltip: Identifiable {
        let id = UUID()
        let systemName: String
        let longWinRate: Double
        let shortWinRate: Double
        let longTrades: Int
        let shortTrades: Int
        let overallTrades: Int
        let anchor: CGPoint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
            HStack {
                    Text(language == .french ? "Graphique Araignée" : "Spider Chart")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                    if highlightedSystemId != nil || tooltip != nil {
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                highlightedSystemId = nil
                                tooltip = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 6)
                    }
                    Text(language == .french ? "\(systems.count) systèmes" : "\(systems.count) systems")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            SystemsWrapLegend(
                systems: systems,
                highlightedSystemId: $highlightedSystemId,
                tooltip: $tooltip
            )

            SpiderChartCanvas(
                systems: systems,
                highlightedSystemId: $highlightedSystemId,
                tooltip: $tooltip,
                language: language
            )
            .frame(height: 260)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            if let details = selectedMetrics {
                SpiderSelectedDetailsCard(metrics: details, language: language)
                    // un peu d'air pour éviter toute proximité avec la bottom bar
                    .padding(.bottom, 12)
            }
        }
    }

    private var selectedMetrics: SystemMetrics? {
        guard let id = highlightedSystemId else { return nil }
        return systems.first(where: { $0.id == id })
    }
}

struct SpiderSelectedDetailsCard: View {
    let metrics: SystemMetrics
    let language: Localizable.Language

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: metrics.system.color))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                Text(metrics.system.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .layoutPriority(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(language == .french ? "\(metrics.totalTrades) trades" : "\(metrics.totalTrades) trades")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Text(formatPnL(metrics.netPnL))
                        .font(.caption2.weight(.bold))
                        .foregroundColor(metrics.netPnL >= 0 ? AppColors.success : AppColors.error)
                }
            }

            HStack(spacing: 12) {
                detailPill(
                    title: "LONG",
                    value: "\(Int(metrics.longWinRate))%",
                    subtitle: "\(metrics.longTrades)",
                    color: AppColors.success
                )
                detailPill(
                    title: "SHORT",
                    value: "\(Int(metrics.shortWinRate))%",
                    subtitle: "\(metrics.shortTrades)",
                    color: AppColors.error
                )
                detailPill(
                    title: language == .french ? "GLOBAL" : "OVERALL",
                    value: "\(Int(metrics.overallWinRate))%",
                    subtitle: "\(metrics.totalTrades)",
                    color: AppColors.primary
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)
    }

    private static let pnlFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private func formatPnL(_ value: Double) -> String {
        let s = Self.pnlFormatter.string(from: NSNumber(value: abs(value))) ?? "0"
        return (value >= 0 ? "+" : "-") + s
    }

    @ViewBuilder
    private func detailPill(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppColors.textSecondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct SystemsWrapLegend: View {
    let systems: [SystemMetrics]
    @Binding var highlightedSystemId: UUID?
    @Binding var tooltip: SystemsSpiderChartView.SpiderTooltip?
        
        // Helper pour extraire les initiales (même logique que dans SpiderChartCanvas)
        private func systemInitials(_ name: String) -> String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "?" }
            if trimmed.count <= 3 {
                return trimmed.uppercased()
            }
            let words = trimmed.components(separatedBy: .whitespaces)
            if words.count > 1 {
                return words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
            } else {
                return String(trimmed.prefix(2)).uppercased()
            }
        }

    private let columns: [GridItem] = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(0..<systems.count, id: \.self) { i in
                let m = systems[i]
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    highlightedSystemId = (highlightedSystemId == m.id) ? nil : m.id
                    // Le tooltip dépend d'un anchor GeometryReader -> on le laisse au chart (tap sur points / numéros)
                        tooltip = nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        // Initiales au lieu du numéro (cohérent avec le radar)
                        let initials = systemInitials(m.system.name)
                        Text(initials)
                            .font(.caption2.weight(.bold))
                            .foregroundColor((highlightedSystemId == m.id) ? .black : .white)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill((highlightedSystemId == m.id) ? AppColors.primary : Color(hex: m.system.color).opacity(0.8))
                                    .overlay(
                                        Circle()
                                            .stroke((highlightedSystemId == m.id) ? AppColors.primary.opacity(0.9) : Color.white.opacity(0.15), lineWidth: (highlightedSystemId == m.id) ? 2 : 1)
                                    )
                            )

                        Circle()
                            .fill(Color(hex: m.system.color))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

                        Text(m.system.name)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                            .layoutPriority(1)

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(m.overallWinRate))% WR")
                            .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("\(m.totalTrades) \(Localizable.text("trades", language: LanguageManager.shared.currentLanguage))")
                                .font(.caption2.weight(.medium))
                            .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.cardBackground.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke((highlightedSystemId == m.id) ? AppColors.primary.opacity(0.7) : Color.white.opacity(0.08), lineWidth: (highlightedSystemId == m.id) ? 2 : 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SpiderChartCanvas: View {
    let systems: [SystemMetrics]
    @Binding var highlightedSystemId: UUID?
    @Binding var tooltip: SystemsSpiderChartView.SpiderTooltip?
    let language: Localizable.Language
    
    // Empêche le "tap canvas" de venir écraser un tap explicite sur un numéro/point
    @State private var ignoreCanvasTapUntil: CFAbsoluteTime = 0
        @State private var animationTrigger: Bool = false
        
        // Struct pour regrouper la géométrie du radar
        private struct RadarGeometry {
            let center: CGPoint
            let radius: CGFloat
            let angles: [Double]
            let size: CGSize
        }

    var body: some View {
        GeometryReader { geo in
                let geometry = makeGeometry(size: geo.size)
                
                ZStack {
                    gridLayer(geometry: geometry)
                    polygonLayer(geometry: geometry)
                    markerLayer(geometry: geometry)
                    labelLayer(geometry: geometry)
                    tooltipLayer(geometry: geometry)
                }
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    guard CFAbsoluteTimeGetCurrent() >= ignoreCanvasTapUntil else { return }
                    selectByAxis(location: location, geometry: geometry)
                }
                .onAppear {
                    withAnimation {
                        animationTrigger = true
                    }
                }
                .onChange(of: systems.count) { _, _ in
                    animationTrigger = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animationTrigger = true
                        }
                    }
                }
            }
        }
        
        // MARK: - Geometry Helper
        private func makeGeometry(size: CGSize) -> RadarGeometry {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.44
            let count = max(systems.count, 3)
            let angles = makeAngles(count: count)
            return RadarGeometry(center: center, radius: radius, angles: angles, size: size)
        }
        
        // MARK: - Layers
        @ViewBuilder
        private func gridLayer(geometry: RadarGeometry) -> some View {
            SpiderGrid(center: geometry.center, radius: geometry.radius, sides: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 1.2)
            
            if let selectedIndex = selectedAxisIndex() {
                let a = geometry.angles[selectedIndex]
                    Path { p in
                    p.move(to: geometry.center)
                    p.addLine(to: point(center: geometry.center, radius: geometry.radius * 1.06, angle: a))
                    }
                    .stroke(AppColors.primary.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
                }
        
        @ViewBuilder
        private func polygonLayer(geometry: RadarGeometry) -> some View {
            let longValues = systems.map { $0.longWinRate }
            let shortValues = systems.map { $0.shortWinRate }

                SpiderFilledPolygon(
                    values: longValues,
                center: geometry.center,
                radius: geometry.radius,
                angles: geometry.angles,
                fill: LinearGradient(
                    colors: [
                        AppColors.success.opacity(0.35),
                        AppColors.success.opacity(0.15),
                        AppColors.success.opacity(0.0)
                    ],
                    startPoint: .center,
                    endPoint: .topLeading
                ),
                    stroke: AppColors.success.opacity(0.9)
                )
            .scaleEffect(animationTrigger ? 1.0 : 0.8)
            .opacity(animationTrigger ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animationTrigger)

                SpiderFilledPolygon(
                    values: shortValues,
                center: geometry.center,
                radius: geometry.radius,
                angles: geometry.angles,
                fill: LinearGradient(
                    colors: [
                        AppColors.error.opacity(0.30),
                        AppColors.error.opacity(0.12),
                        AppColors.error.opacity(0.0)
                    ],
                    startPoint: .center,
                    endPoint: .topLeading
                ),
                    stroke: AppColors.error.opacity(0.9)
                )
            .scaleEffect(animationTrigger ? 1.0 : 0.8)
            .opacity(animationTrigger ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animationTrigger)
        }

        @ViewBuilder
        private func markerLayer(geometry: RadarGeometry) -> some View {
            ForEach(Array<Int>(0..<systems.count), id: \.self) { i in
                    let m = systems[i]
                let longPoint = point(center: geometry.center, radius: geometry.radius * CGFloat(m.longWinRate / 100.0), angle: geometry.angles[i])
                let shortPoint = point(center: geometry.center, radius: geometry.radius * CGFloat(m.shortWinRate / 100.0), angle: geometry.angles[i])
                    let isDimmed = (highlightedSystemId != nil && highlightedSystemId != m.id)

                Group {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)
                        .position(longPoint)
                        .opacity(isDimmed ? 0.25 : 1)
                        .contentShape(Rectangle().inset(by: -14))
                        .onTapGesture { selectFromMarker(m, anchor: longPoint) }

                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 8, height: 8)
                        .position(shortPoint)
                        .opacity(isDimmed ? 0.25 : 1)
                        .contentShape(Rectangle().inset(by: -14))
                        .onTapGesture { selectFromMarker(m, anchor: shortPoint) }
                }
            }
                }

        @ViewBuilder
        private func labelLayer(geometry: RadarGeometry) -> some View {
                if systems.count <= 18 {
                ForEach(Array<Int>(0..<systems.count), id: \.self) { i in
                    SpiderLabelBadge(
                        metrics: systems[i],
                        index: i,
                        geometry: geometry,
                        highlightedSystemId: $highlightedSystemId,
                        tooltip: $tooltip,
                        onSelect: { selectFromMarker($0, anchor: $1) },
                        point: { point(center: $0, radius: $1, angle: $2) },
                        systemInitials: { systemInitials($0) }
                    )
                }
            }
        }
        
        // MARK: - Label Badge Component
        private struct SpiderLabelBadge: View {
            let metrics: SystemMetrics
            let index: Int
            let geometry: RadarGeometry
            @Binding var highlightedSystemId: UUID?
            @Binding var tooltip: SystemsSpiderChartView.SpiderTooltip?
            let onSelect: (SystemMetrics, CGPoint) -> Void
            let point: (CGPoint, CGFloat, Double) -> CGPoint
            let systemInitials: (String) -> String
            
            private var labelPoint: CGPoint {
                point(geometry.center, geometry.radius * 1.10, geometry.angles[index])
            }
            
            private var isSelected: Bool {
                highlightedSystemId == metrics.id
            }
            
            private var initials: String {
                systemInitials(metrics.system.name)
            }
            
            var body: some View {
                Text(initials)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(isSelected ? .black : .white)
                    .frame(width: 28, height: 28)
                            .background(
                                Circle()
                            .fill(isSelected ? AppColors.primary : Color(hex: metrics.system.color).opacity(0.8))
                                    .overlay(
                                        Circle()
                                    .stroke(isSelected ? AppColors.primary.opacity(0.9) : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                                    )
                            )
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                    .shadow(color: isSelected ? AppColors.primary.opacity(0.4) : Color(hex: metrics.system.color).opacity(0.3), radius: isSelected ? 10 : 6, x: 0, y: 4)
                            .position(labelPoint)
                    .onTapGesture {
                        onSelect(metrics, labelPoint)
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        HapticFeedback.medium()
                        let anchor = point(geometry.center, geometry.radius * 0.8, geometry.angles[index])
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            tooltip = SystemsSpiderChartView.SpiderTooltip(
                                systemName: metrics.system.name,
                                longWinRate: metrics.longWinRate,
                                shortWinRate: metrics.shortWinRate,
                                longTrades: metrics.longTrades,
                                shortTrades: metrics.shortTrades,
                                overallTrades: metrics.totalTrades,
                                anchor: anchor
                            )
                        }
                    }
            }
        }
        
        @ViewBuilder
        private func tooltipLayer(geometry: RadarGeometry) -> some View {
                if let tooltip {
                    SpiderTooltipView(tooltip: tooltip)
                    .position(adjustedTooltipPosition(tooltip.anchor, in: geometry.size))
                        .transition(.opacity.combined(with: .scale))
                        .allowsHitTesting(false)
        }
    }

    // ✅ Helper hors ViewBuilder (évite "Closure containing control flow statement" dans GeometryReader)
    private func makeAngles(count: Int) -> [Double] {
        let safe = max(count, 3)
        var angles: [Double] = []
        angles.reserveCapacity(safe)
        for idx in 0..<safe {
            angles.append((Double(idx) / Double(safe)) * (2.0 * Double.pi) - Double.pi / 2.0)
        }
        return angles
    }

    private func shortLabel(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 10 { return trimmed }
        return String(trimmed.prefix(10)) + "…"
    }
        
        // Extraire les initiales d'un nom de système (ex: "Swing Trading" -> "ST", "VMC" -> "VM")
        private func systemInitials(_ name: String) -> String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "?" }
            
            // Si le nom est court (≤3 caractères), l'utiliser tel quel
            if trimmed.count <= 3 {
                return trimmed.uppercased()
            }
            
            // Sinon, prendre les premières lettres de chaque mot
            let words = trimmed.components(separatedBy: .whitespaces)
            if words.count > 1 {
                // Plusieurs mots : prendre la première lettre de chaque
                return words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
            } else {
                // Un seul mot : prendre les 2-3 premières lettres
                return String(trimmed.prefix(2)).uppercased()
            }
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(Darwin.cos(angle)) * radius,
            y: center.y + CGFloat(Darwin.sin(angle)) * radius
        )
    }

    private func select(_ metrics: SystemMetrics, anchor: CGPoint) {
        HapticFeedback.selection()
        highlightedSystemId = metrics.id
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            tooltip = SystemsSpiderChartView.SpiderTooltip(
                systemName: metrics.system.name,
                longWinRate: metrics.longWinRate,
                shortWinRate: metrics.shortWinRate,
                longTrades: metrics.longTrades,
                shortTrades: metrics.shortTrades,
                overallTrades: metrics.totalTrades,
                anchor: anchor
            )
        }
    }
    
    private func selectFromMarker(_ metrics: SystemMetrics, anchor: CGPoint) {
        // évite que le SpatialTapGesture du canvas déclenche une sélection différente juste après
        ignoreCanvasTapUntil = CFAbsoluteTimeGetCurrent() + 0.25
        select(metrics, anchor: anchor)
    }

    private func selectedAxisIndex() -> Int? {
        guard let id = highlightedSystemId else { return nil }
        return systems.firstIndex(where: { $0.id == id })
    }

    // ✅ Interaction directe: tap sur le graphique -> choisit l'axe (système) le plus proche
        private func selectByAxis(location: CGPoint, geometry: RadarGeometry) {
        guard !systems.isEmpty else { return }

            let dx = Double(location.x - geometry.center.x)
            let dy = Double(location.y - geometry.center.y)

        // angle en repère écran (y vers le bas) -> atan2(dy, dx)
        let a = atan2(dy, dx)

        var bestIndex = 0
        var bestDelta = Double.greatestFiniteMagnitude

        for i in 0..<systems.count {
                let ai = geometry.angles[i]
            // diff d'angle "wrap"
            let raw = abs(ai - a)
            let delta = min(raw, 2.0 * Double.pi - raw)
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = i
            }
        }

        let m = systems[bestIndex]
        // anchor sur l'axe, dans le canvas (évite les overlays hors zone)
            let anchor = point(center: geometry.center, radius: geometry.radius * 1.02, angle: geometry.angles[bestIndex])
        select(m, anchor: anchor)
    }

    private func adjustedTooltipPosition(_ anchor: CGPoint, in size: CGSize) -> CGPoint {
            // Taille approximative de la tooltip (largeur ~160, hauteur ~120)
            let tooltipWidth: CGFloat = 160
            let tooltipHeight: CGFloat = 120
            let margin: CGFloat = 16
            
        var x = anchor.x
            var y = anchor.y - tooltipHeight / 2 - 20
            
            // Ajuster horizontalement pour éviter les bords
            if x < tooltipWidth / 2 + margin {
                x = tooltipWidth / 2 + margin
            } else if x > size.width - tooltipWidth / 2 - margin {
                x = size.width - tooltipWidth / 2 - margin
            }
            
            // Ajuster verticalement pour éviter les bords
            if y < tooltipHeight / 2 + margin {
                y = tooltipHeight / 2 + margin
            } else if y > size.height - tooltipHeight / 2 - margin {
                y = size.height - tooltipHeight / 2 - margin
            }
            
        return CGPoint(x: x, y: y)
    }
}

private struct SpiderFilledPolygon: View {
    let values: [Double]
    let center: CGPoint
    let radius: CGFloat
    let angles: [Double]
        let fill: AnyShapeStyle
    let stroke: Color
        
        init(values: [Double], center: CGPoint, radius: CGFloat, angles: [Double], fill: Color, stroke: Color) {
            self.values = values
            self.center = center
            self.radius = radius
            self.angles = angles
            self.fill = AnyShapeStyle(fill)
            self.stroke = stroke
        }
        
        init(values: [Double], center: CGPoint, radius: CGFloat, angles: [Double], fill: LinearGradient, stroke: Color) {
            self.values = values
            self.center = center
            self.radius = radius
            self.angles = angles
            self.fill = AnyShapeStyle(fill)
            self.stroke = stroke
        }

    var body: some View {
        SpiderPolygon(values: values, center: center, radius: radius, angles: angles)
            .fill(fill)
            .overlay(
                SpiderPolygon(values: values, center: center, radius: radius, angles: angles)
                        .stroke(stroke, lineWidth: 2.5)
            )
    }
}

private struct SpiderGrid: Shape {
    let center: CGPoint
    let radius: CGFloat
    let sides: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let rings = 4
        let safeSides = max(sides, 3)
        var angles: [Double] = []
        angles.reserveCapacity(safeSides)
        for i in 0..<safeSides {
            let a = (Double(i) / Double(safeSides)) * (2.0 * Double.pi) - Double.pi / 2.0
            angles.append(a)
        }

        func ringPath(ringRadius: CGFloat) -> Path {
            var rp = Path()
            guard safeSides > 2 else { return rp }
            let first = CGPoint(
                x: center.x + CGFloat(Darwin.cos(angles[0])) * ringRadius,
                y: center.y + CGFloat(Darwin.sin(angles[0])) * ringRadius
            )
            rp.move(to: first)
            for i in 1..<safeSides {
                let pt = CGPoint(
                    x: center.x + CGFloat(Darwin.cos(angles[i])) * ringRadius,
                    y: center.y + CGFloat(Darwin.sin(angles[i])) * ringRadius
                )
                rp.addLine(to: pt)
            }
            rp.closeSubpath()
            return rp
        }

        for r in 1...rings {
            let rr = radius * CGFloat(r) / CGFloat(rings)
            p.addPath(ringPath(ringRadius: rr))
        }

        return p
    }
}

private struct SpiderPolygon: Shape {
    let values: [Double]   // 0..100
    let center: CGPoint
    let radius: CGFloat
    let angles: [Double]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard !values.isEmpty else { return p }
        let count = min(values.count, angles.count)
        guard count > 2 else { return p }

        func pt(i: Int) -> CGPoint {
            let v = max(0, min(100, values[i])) / 100.0
            return CGPoint(
                x: center.x + CGFloat(Darwin.cos(angles[i])) * radius * CGFloat(v),
                y: center.y + CGFloat(Darwin.sin(angles[i])) * radius * CGFloat(v)
            )
        }

        p.move(to: pt(i: 0))
        for i in 1..<count { p.addLine(to: pt(i: i)) }
        p.closeSubpath()
        return p
    }
}

private struct SpiderTooltipView: View {
    let tooltip: SystemsSpiderChartView.SpiderTooltip

    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
            Text(tooltip.systemName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                        Circle().fill(AppColors.success).frame(width: 8, height: 8)
                        Text(t("long"))
                            .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(Int(tooltip.longWinRate))%")
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(.white)
                            Text(t("trades"))
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    
                HStack(spacing: 6) {
                        Circle().fill(AppColors.error).frame(width: 8, height: 8)
                        Text(t("short"))
                            .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(Int(tooltip.shortWinRate))%")
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(.white)
                            Text(t("trades"))
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                HStack {
                    Text(t("total"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
            Text(t("trades"))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
        }
        .padding(10)
            .frame(maxWidth: 150)
        .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.92))
                .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                )
        )
            .shadow(color: Color.black.opacity(0.6), radius: 16, x: 0, y: 8)
    }
}
struct SystemsRadarChartView: View {
    @ObservedObject private var appState = AppState.shared
    
    var chartData: [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        
        print("🔍 SystemsRadarChartView - Systems count: \(appState.systems.count)")
        print("🔍 SystemsRadarChartView - Trades count: \(appState.trades.count)")
        
        for system in appState.systems {
            let systemTrades = appState.trades.filter { $0.systemId == system.id }
            print("🔍 System '\(system.name)' (ID: \(system.id)) - Trades: \(systemTrades.count)")
            
            // LONG trades
            let longTrades = systemTrades.filter { $0.type == .long }
            let longWinRate = calculateWinRate(for: longTrades)
            print("🔍   LONG trades: \(longTrades.count), Win rate: \(longWinRate)")
            data.append(ChartDataPoint(
                system: system.name,
                type: "LONG",
                value: longWinRate,
                color: .green,
                tradesCount: longTrades.count
            ))
            
            // SHORT trades
            let shortTrades = systemTrades.filter { $0.type == .short }
            let shortWinRate = calculateWinRate(for: shortTrades)
            print("🔍   SHORT trades: \(shortTrades.count), Win rate: \(shortWinRate)")
            data.append(ChartDataPoint(
                system: system.name,
                type: "SHORT",
                value: shortWinRate,
                color: .red,
                tradesCount: shortTrades.count
            ))
        }
        
        print("🔍 ChartData count: \(data.count)")
        for item in data {
            print("🔍   - \(item.system) \(item.type): \(item.value) (\(item.tradesCount) trades)")
        }
        return data
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(t("system"))
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Légende
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text(t("long"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text(t("short"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            if !chartData.isEmpty {
                Chart(chartData) { data in
                    BarMark(
                        x: .value("Système", data.system),
                        y: .value("Win Rate", data.value)
                    )
                    .foregroundStyle(data.color)
                    .opacity(0.8)
                    .position(by: .value("Type", data.type))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
            }
        }
    }
    
    private func calculateWinRate(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        
        let winningTrades = trades.filter { trade in
            // Si flashPnLNet est disponible, l'utiliser
            if let flashPnL = trade.flashPnLNet {
                return flashPnL > 0
            }
            // Sinon, calculer le P&L à partir des prix
            else if let entry = trade.entryPrice, let exit = trade.exitPrice, let qty = trade.quantity {
                let pnl = (exit - entry) * qty * trade.leverage
                return pnl > 0
            }
            return false
        }
        
        return Double(winningTrades.count) / Double(trades.count) * 100
    }
}

// MARK: - Chart Data Models
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let system: String
    let type: String
    let value: Double
    let color: Color
    let tradesCount: Int
}

struct SystemCardView: View {
    @ObservedObject private var appState = AppState.shared
    let system: TradingSystem
    let trades: [Trade]
    
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "fr"
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSystem = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    var longStats: SystemStats {
        let longTrades = trades.filter { $0.type == .long }
        let totalPnL = longTrades.reduce(0) { $0 + ($1.flashPnLNet ?? 0) }
        let winRate = calculateWinRate(for: longTrades)
        return SystemStats(totalPnL: totalPnL, winRate: winRate, tradeCount: longTrades.count)
    }
    
    var shortStats: SystemStats {
        let shortTrades = trades.filter { $0.type == .short }
        let totalPnL = shortTrades.reduce(0) { $0 + ($1.flashPnLNet ?? 0) }
        let winRate = calculateWinRate(for: shortTrades)
        return SystemStats(totalPnL: totalPnL, winRate: winRate, tradeCount: shortTrades.count)
    }
    
    var hasTrades: Bool {
        !trades.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // System color indicator
                Circle()
                    .fill(Color(hex: system.color))
                    .frame(width: 12, height: 12)
                
                Text(system.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .layoutPriority(1)
                
                Spacer()
                
                // Menu d'actions
                Menu {
                    Button(action: {
                        HapticFeedback.selection()
                        showingEditSystem = true
                    }) {
                        Label("Modifier", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        HapticFeedback.medium()
                        showingDeleteConfirmation = true
                    }) {
                        Label("Supprimer", systemImage: "trash")
                    }
                    .disabled(isDeleting)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(8)
                }
            }
            
            // LONG Performance
            if longStats.tradeCount > 0 {
                HStack {
                    Text(t("long"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .frame(width: 50, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    HStack(spacing: 16) {
                        StatItem(title: "Win Rate", value: String(format: "%.1f%%", longStats.winRate), color: longStats.winRate >= 50 ? AppColors.success : AppColors.error)
                        StatItem(title: "Trades", value: "\(longStats.tradeCount)", color: AppColors.textPrimary)
                        StatItem(title: "P&L", value: String(format: "$%.0f", longStats.totalPnL), color: longStats.totalPnL >= 0 ? AppColors.success : AppColors.error)
                    }
                }
            }
            
            // SHORT Performance
            if shortStats.tradeCount > 0 {
                HStack {
                    Text(t("short"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(width: 50, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    HStack(spacing: 16) {
                        StatItem(title: "Win Rate", value: String(format: "%.1f%%", shortStats.winRate), color: shortStats.winRate >= 50 ? AppColors.success : AppColors.error)
                        StatItem(title: "Trades", value: "\(shortStats.tradeCount)", color: AppColors.textPrimary)
                        StatItem(title: "P&L", value: String(format: "$%.0f", shortStats.totalPnL), color: shortStats.totalPnL >= 0 ? AppColors.success : AppColors.error)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                HapticFeedback.medium()
                showingDeleteConfirmation = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            .disabled(isDeleting)
        }
        .confirmationDialog(
            "Supprimer le système",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                Task {
                    await deleteSystem()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            if hasTrades {
                Text("Ce système est utilisé par \(trades.count) trade\(trades.count > 1 ? "s" : ""). Les trades seront réassignés à un autre système. Cette action est irréversible.")
            } else {
                Text(t("delete"))
            }
        }
        .alert("Erreur", isPresented: .constant(deleteError != nil)) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .sheet(isPresented: $showingEditSystem) {
            EditSystemView(
                system: system,
                language: Binding(
                    get: {
                        let lang = Localizable.Language(rawValue: selectedLanguage)
                        return lang ?? Localizable.Language.allCases.first!
                    },
                    set: { selectedLanguage = $0.rawValue }
                )
            )
            .environmentObject(appState)
        }
    }
    
    @MainActor
    private func deleteSystem() async {
        isDeleting = true
        deleteError = nil
        
        do {
            try await appState.deleteSystem(system)
            HapticFeedback.success()
        } catch let error as AppState.SystemDeletionError {
            deleteError = error.localizedDescription
            HapticFeedback.error()
        } catch {
            deleteError = "Une erreur est survenue lors de la suppression : \(error.localizedDescription)"
            HapticFeedback.error()
        }
        
        isDeleting = false
    }
    
    private func calculateWinRate(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        
        let winningTrades = trades.filter { trade in
            // Si flashPnLNet est disponible, l'utiliser
            if let flashPnL = trade.flashPnLNet {
                return flashPnL > 0
            }
            // Sinon, calculer le P&L à partir des prix
            else if let entry = trade.entryPrice, let exit = trade.exitPrice, let qty = trade.quantity {
                let pnl = (exit - entry) * qty * trade.leverage
                return pnl > 0
            }
            return false
        }
        
        return Double(winningTrades.count) / Double(trades.count) * 100
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Data Models

struct SystemStats {
    let totalPnL: Double
    let winRate: Double
    let tradeCount: Int
}
    
    // MARK: - Filters Bottom Sheet
    private struct FiltersBottomSheet: View {
        @Binding var sort: SystemSort
        @Binding var filter: SystemFilter
        let language: Localizable.Language
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 24) {
                    // Section Tri
                    VStack(alignment: .leading, spacing: 12) {
                        Text(language == .french ? "Trier par" : "Sort by")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        ForEach(SystemSort.allCases, id: \.self) { s in
                            Button {
                                HapticFeedback.selection()
                                sort = s
                            } label: {
                                HStack {
                                    Text(s.title(language: language))
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if sort == s {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(sort == s ? AppColors.primary.opacity(0.15) : AppColors.cardBackground.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(sort == s ? AppColors.primary.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Section Filtre
                    VStack(alignment: .leading, spacing: 12) {
                        Text(language == .french ? "Filtrer" : "Filter")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        
                        ForEach(SystemFilter.allCases, id: \.self) { f in
                            Button {
                                HapticFeedback.selection()
                                filter = f
                            } label: {
                                HStack {
                                    Text(f.title(language: language))
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if filter == f {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(filter == f ? AppColors.primary.opacity(0.15) : AppColors.cardBackground.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(filter == f ? AppColors.primary.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppColors.background.ignoresSafeArea())
                .navigationTitle(language == .french ? "Filtres" : "Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(language == .french ? "Terminé" : "Done") {
                            HapticFeedback.selection()
                            dismiss()
                        }
                        .foregroundColor(AppColors.primary)
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }


#Preview {
    SystemsView()
        .environmentObject(AppState())
}
