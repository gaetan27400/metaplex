//
//  TradesView.swift
//  Journal de trading 2025
//

import SwiftUI

struct TradesView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @State private var selectedTab: TradeTab = .trades
    @State private var searchText = ""
    @State private var selectedSystem: UUID? = nil
    @State private var toast: ToastData?
    @State private var filters = TradeFilters()
    @State private var showingAdvancedFilters = false

    // ✅ Pré-trade (au début de l'onglet Trades)
    @State private var preTradeChecklist: MiniPreTradeChecklist = .empty
    private let emotionsCoach: EmotionsCoachProviding = LocalEmotionsCoachMock()
    
    var filteredTrades: [Trade] {
        var trades = appState.trades
        
        print("🔍 [TradesView.filteredTrades] Début - appState.trades.count: \(trades.count)")
        
        // Filter by search text
        if !searchText.isEmpty {
            let beforeCount = trades.count
            trades = trades.filter { trade in
                trade.symbol.localizedCaseInsensitiveContains(searchText)
            }
            print("🔍 [TradesView.filteredTrades] Après recherche '\(searchText)': \(beforeCount) → \(trades.count)")
        }
        
        // Filter by system (legacy, pour compatibilité)
        if let systemId = selectedSystem {
            let beforeCount = trades.count
            trades = trades.filter { $0.systemId == systemId }
            print("🔍 [TradesView.filteredTrades] Après filtre système: \(beforeCount) → \(trades.count)")
        }
        
        // Apply advanced filters
        let beforeCount = trades.count
        trades = filters.apply(to: trades)
        if beforeCount != trades.count {
            print("🔍 [TradesView.filteredTrades] Après filtres avancés: \(beforeCount) → \(trades.count)")
        }
        
        // Trier par date (les plus récents en premier)
        // Les trades ouverts sont inclus dans la liste
        let sorted = trades.sorted { $0.date > $1.date }
        print("🔍 [TradesView.filteredTrades] Résultat final: \(sorted.count) trades")
        return sorted
    }
    
    var hasActiveFilters: Bool {
        selectedSystem != nil || !filters.isEmpty
    }
    
    var activeFiltersCount: Int {
        var count = 0
        if selectedSystem != nil { count += 1 }
        if filters.startDate != nil || filters.endDate != nil { count += 1 }
        if !filters.selectedSymbols.isEmpty { count += 1 }
        if !filters.selectedSystems.isEmpty { count += 1 }
        if !filters.selectedExchanges.isEmpty { count += 1 }
        if filters.showOnlyWins || filters.showOnlyLosses || filters.showOnlyBreakEven { count += 1 }
        return count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(t("trades"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Improved Tabs with animated underline
                improvedTabs
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                
                // Active filter badge
                if hasActiveFilters {
                    activeFilterBadge
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                // Content
                if selectedTab == .trades {
                    VStack(spacing: 12) {
                        PreTradeCard(
                            lastMood: appState.moodEntries.last,
                            checklist: $preTradeChecklist,
                            coach: emotionsCoach
                        )
                        .padding(.horizontal)

                        TradesListView(
                            trades: filteredTrades,
                            searchText: $searchText,
                            selectedSystem: $selectedSystem,
                            filters: $filters,
                            showingAdvancedFilters: $showingAdvancedFilters,
                            systems: appState.systems,
                            exchanges: appState.exchanges
                        )
                    }
                } else if selectedTab == .exchanges {
                    ExchangesView()
                } else {
                    EmotionalJournalView()
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .toast($toast)
            .onAppear {
                print("🔍 [TradesView] onAppear - Nombre de trades: \(appState.trades.count)")
                print("🔍 [TradesView] AppState instance: \(appState === AppState.shared ? "shared ✅" : "DIFFÉRENTE ❌")")
                print("🔍 [TradesView] filteredTrades.count: \(filteredTrades.count)")
                print("🔍 [TradesView] searchText: '\(searchText)'")
                print("🔍 [TradesView] selectedSystem: \(selectedSystem?.uuidString ?? "nil")")
                print("🔍 [TradesView] filters.isEmpty: \(filters.isEmpty)")
                
                // Si filteredTrades est vide mais appState.trades ne l'est pas, réinitialiser les filtres
                if filteredTrades.isEmpty && !appState.trades.isEmpty {
                    print("⚠️ [TradesView] filteredTrades est vide alors que appState.trades contient \(appState.trades.count) trades")
                    print("⚠️ [TradesView] Réinitialisation des filtres...")
                    searchText = ""
                    selectedSystem = nil
                    filters = TradeFilters()
                    print("✅ [TradesView] Filtres réinitialisés, filteredTrades.count devrait être: \(appState.trades.count)")
                }
                
            }
            .onAppear {
                // suggestion initiale basée sur la dernière entrée émotionnelle si dispo
                if let last = appState.moodEntries.last {
                    if let suggested = emotionsCoach.suggestedMiniChecklist(
                        emotionalState: last.emotionalState,
                        intensity: last.intensity,
                        context: .beforeTrade,
                        trigger: last.trigger
                    ) {
                        preTradeChecklist = suggested
                    }
                }
            }
            .onChange(of: appState.trades.count) { oldCount, newCount in
                print("🔍 [TradesView] onChange - appState.trades.count: \(oldCount) → \(newCount)")
                print("🔍 [TradesView] filteredTrades.count: \(filteredTrades.count)")
            }
        }
    }
    
    // MARK: - Improved Tabs
    private var improvedTabs: some View {
        HStack(spacing: 0) {
            ForEach(TradeTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? .white : .gray)
                        
                        // Animated underline
                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Active Filter Badge
    private var activeFilterBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.caption)
                .foregroundColor(.blue)
            
            if activeFiltersCount > 0 {
                Text("\(activeFiltersCount) filtre\(activeFiltersCount > 1 ? "s" : "") actif\(activeFiltersCount > 1 ? "s" : "")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            if let system = appState.systems.first(where: { $0.id == selectedSystem }) {
                Text(t("name"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    selectedSystem = nil
                    filters = TradeFilters()
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.15))
        )
    }
}

// MARK: - Pré-trade card (compact)
private struct PreTradeCard: View {
    let lastMood: MoodEntry?
    @Binding var checklist: MiniPreTradeChecklist
    let coach: EmotionsCoachProviding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("prtrade"))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Suggérer") {
                    HapticFeedback.selection()
                    let emotion = lastMood?.emotionalState ?? .calm
                    let intensity = lastMood?.intensity ?? 5
                    if let suggested = coach.suggestedMiniChecklist(
                        emotionalState: emotion,
                        intensity: intensity,
                        context: .beforeTrade,
                        trigger: lastMood?.trigger
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            checklist = suggested
                        }
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.tradingBlue)
            }

            if let lastMood {
                Text(t("tuesday"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                TradeToggleChip(title: "Plan OK", isOn: $checklist.planOK)
                TradeToggleChip(title: "Taille OK", isOn: $checklist.sizeOK)
                TradeToggleChip(title: "Stop défini", isOn: $checklist.stopDefined)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6).opacity(0.15))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        )
    }
}

private struct TradeToggleChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? .green : .gray)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isOn ? 0.10 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isOn ? Color.green.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TradesListView: View {
    let trades: [Trade]
    @Binding var searchText: String
    @Binding var selectedSystem: UUID?
    @Binding var filters: TradeFilters
    @Binding var showingAdvancedFilters: Bool
    let systems: [TradingSystem]
    let exchanges: [Exchange]
    
    @State private var showFilters = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Improved Search bar
            improvedSearchBar
                .padding(.horizontal)
                .padding(.bottom, 12)
            
            // Filters panel (expandable)
            if showFilters {
                filtersPanel
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Trades list
            if trades.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(trades) { trade in
                            TradeCardView(trade: trade, systems: systems)
                        }
                    }
                    .padding(.horizontal)
                    // `TradingJournalApp` gère désormais l'espace de la bottom bar via `safeAreaInset`.
                    .padding(.bottom, 16)
                }
                .refreshable {
                    await refreshTrades()
                }
            }
        }
    }
    
    // MARK: - Improved Search Bar
    private var improvedSearchBar: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.title3)
            
            // Text field
            TextField("Rechercher un symbole...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
            
            // Clear button
            if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.spring()) {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Filter button with badge
            Button(action: {
                HapticFeedback.light()
                withAnimation(.spring()) {
                    showFilters.toggle()
                }
            }) {
                ZStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    if selectedSystem != nil || !filters.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 8, y: -8)
                    }
                }
            }
            
            // Advanced filters button
            Button(action: {
                HapticFeedback.medium()
                showingAdvancedFilters = true
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(AppColors.primary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
        .sheet(isPresented: $showingAdvancedFilters) {
            AdvancedTradeFiltersView(
                filters: $filters,
                systems: systems,
                exchanges: exchanges
            )
        }
    }
    
    // MARK: - Filters Panel
    private var filtersPanel: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Filtres", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        showFilters = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // System filter with chevron
            VStack(alignment: .leading, spacing: 8) {
                Label("Système de Trading", systemImage: "chart.radar")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Menu {
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedSystem = nil
                        }
                    }) {
                        HStack {
                            Text(t("tous"))
                            if selectedSystem == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    ForEach(systems) { system in
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedSystem = system.id
                            }
                        }) {
                            HStack {
                                Text(system.name)
                                if selectedSystem == system.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let systemId = selectedSystem,
                           let system = systems.first(where: { $0.id == systemId }) {
                            Circle()
                                .fill(Color(hex: system.color))
                                .frame(width: 8, height: 8)
                            Text(system.name)
                                .foregroundColor(.white)
                        } else {
                            Text(t("tous"))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.15))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(t("aucunTradeTrouv"))
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(t("add"))
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Refresh Function
    private func refreshTrades() async {
        isRefreshing = true
        HapticFeedback.medium()
        
        // Simulate network call
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        isRefreshing = false
        HapticFeedback.success()
        
        // Show success toast (would need to pass from parent)
        // This is a placeholder for the toast functionality
    }
}

struct TradeCardView: View {
    let trade: Trade
    let systems: [TradingSystem]
    @EnvironmentObject var appState: AppState
    
    @State private var isDeleted = false
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    
    var system: TradingSystem? {
        systems.first { $0.id == trade.systemId }
    }
    
    var pnl: Double {
        // Utiliser pnl qui gère les trades ouverts et fermés
        trade.pnl
    }
    
    var isProfit: Bool {
        pnl >= 0
    }
    
    var body: some View {
        if isDeleted {
            EmptyView()
        } else {
            makeMainCard()
        }
    }
    
    private func makeMainCard() -> some View {
        cardContent
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                leadingSwipeActions
            }
            .alert("Supprimer le trade", isPresented: $showDeleteConfirmation) {
                Button("Annuler", role: .cancel) { }
                Button("Supprimer", role: .destructive) {
                    deleteTrade()
                }
            } message: {
                Text(t("delete"))
            }
            .sheet(isPresented: $showEditSheet) {
                EditTradeView(trade: trade)
                    .environmentObject(appState)
            }
            .onTapGesture {
                // Navigation vers TradeDetailView
                // TODO: Implémenter la navigation
            }
    }
    
    private var trailingSwipeActions: some View {
        Group {
            // Supprimer
            Button(role: .destructive) {
                HapticFeedback.error()
                showDeleteConfirmation = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            .tint(.red)
            
            // Modifier
            Button {
                HapticFeedback.medium()
                showEditSheet = true
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
    
    private var leadingSwipeActions: some View {
        Group {
            // Dupliquer
            Button {
                HapticFeedback.light()
                duplicateTrade()
            } label: {
                Label("Dupliquer", systemImage: "doc.on.doc")
            }
            .tint(.orange)
            
            // Partager
            Button {
                HapticFeedback.light()
                // TODO: Implementer le partage
            } label: {
                Label("Partager", systemImage: "square.and.arrow.up")
            }
            .tint(.green)
        }
    }
    
    // MARK: - Card Components
    private func makeCardHeader() -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            makeSymbolSection()
            Spacer()
            cardActionsMenu
            makePnlSection()
        }
    }

    private var cardActionsMenu: some View {
        Menu {
            Button {
                HapticFeedback.medium()
                showEditSheet = true
            } label: {
                Label("Modifier", systemImage: "pencil")
            }

            Button {
                HapticFeedback.light()
                duplicateTrade()
            } label: {
                Label("Dupliquer", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                HapticFeedback.error()
                showDeleteConfirmation = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
        }
        .contentShape(Circle())
    }
    
    private func makeSymbolSection() -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.xs) {
                Text(trade.symbol)
                    .font(AppTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            makeTypeBadge()
        }
    }
    
    private func makeTypeBadge() -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: trade.type == .long ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.white)
            Text(trade.type.rawValue.uppercased())
                .font(AppTypography.captionSmall)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxxs)
        .background(
            Capsule()
                .fill(trade.type == .long ? AppColors.success : AppColors.error)
        )
    }
    
    private func makePnlSection() -> some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xxxs) {
            HStack(spacing: AppSpacing.xxxs) {
                Image(systemName: isProfit ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 16))
                Text(String(format: "$%.2f", pnl))
                    .font(AppTypography.titleLarge)
                    .fontWeight(.bold)
            }
            .foregroundColor(isProfit ? AppColors.success : AppColors.error)
            
            Text(String(format: "%.1f%%", abs(pnl) / 100))
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    @ViewBuilder
    private func makeEntryExitSection() -> some View {
        if let entryPrice = trade.entryPrice, let exitPrice = trade.exitPrice {
            HStack(spacing: AppSpacing.md) {
                makeEntryPriceView(price: entryPrice)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.primary)
                makeExitPriceView(price: exitPrice)
                Spacer()
                makeDateView()
            }
        } else {
            makeNoEntryExitRow()
        }
    }
    
    private func makeEntryPriceView(price: Double) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Label("Entry", systemImage: "arrow.down.circle")
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textTertiary)
            Text(String(format: "$%.2f", price))
                .font(AppTypography.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    private func makeExitPriceView(price: Double) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Label("Exit", systemImage: "arrow.up.circle")
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textTertiary)
            Text(String(format: "$%.2f", price))
                .font(AppTypography.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    private func makeDateView() -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
            Text(formatDate(trade.date))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private func makeNoEntryExitRow() -> some View {
        HStack(spacing: AppSpacing.md) {
            if let system = system {
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(Color(hex: system.color))
                        .frame(width: 8, height: 8)
                    Text(system.name)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            makeDateView()
        }
    }
    
    private func makeCardContent() -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            makeCardHeader()
            
            Divider()
                .background(AppColors.border)
                .padding(.vertical, AppSpacing.xs)
            
            makeEntryExitSection()
        }
        .padding(AppSpacing.md)
        .background(makeCardBackground())
        .overlay(makeCardOverlay())
    }
    
    private var cardContent: some View {
        makeCardContent()
    }
    
    private func makeCardBackground() -> some View {
        RoundedRectangle(cornerRadius: AppRadius.large)
            .fill(AppColors.cardBackground)
            .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)
    }
    
    private func makeCardOverlay() -> some View {
        RoundedRectangle(cornerRadius: AppRadius.large)
            .stroke(
                LinearGradient(
                    colors: [
                        AppColors.primary.opacity(0.1),
                        AppColors.accent.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    private func deleteTrade() {
        HapticFeedback.success()
        withAnimation(.spring()) {
            isDeleted = true
        }
        
        // Supprimer le trade de AppState
        Task {
            await MainActor.run {
                appState.deleteTrade(trade)
            }
        }
    }
    
    private func duplicateTrade() {
        let duplicatedTrade = Trade(
            date: Date(),
            symbol: trade.symbol,
            type: trade.type,
            entryPrice: trade.entryPrice,
            exitPrice: trade.exitPrice,
            quantity: trade.quantity,
            leverage: trade.leverage,
            exchangeId: trade.exchangeId,
            orderRole: trade.orderRole,
            systemId: trade.systemId,
            session: trade.session,
            flashPnLNet: trade.flashPnLNet
        )
        appState.addTrade(duplicatedTrade)
        HapticFeedback.success()
    }
}

enum TradeTab: String, CaseIterable {
    case trades = "trades"
    case exchanges = "exchanges"
    case emotionalJournal = "emotionalJournal"
    
    var title: String {
        switch self {
        case .trades: return "Trades"
        case .exchanges: return "Exchanges"
        case .emotionalJournal: return "Émotions"
        }
    }
}

// MARK: - Edit Trade View
struct EditTradeView: View {
    let trade: Trade
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var symbol: String
    @State private var selectedType: TradeType
    @State private var entryPrice: String
    @State private var exitPrice: String
    @State private var quantity: String
    @State private var leverage: Double
    @State private var selectedExchangeId: UUID?
    @State private var selectedOrderRole: OrderRole
    @State private var selectedSystemId: UUID?
    @State private var selectedSession: Session
    @State private var flashPnL: String
    
    init(trade: Trade) {
        self.trade = trade
        _symbol = State(initialValue: trade.symbol)
        _selectedType = State(initialValue: trade.type)
        _entryPrice = State(initialValue: trade.entryPrice.map { String($0) } ?? "")
        _exitPrice = State(initialValue: trade.exitPrice.map { String($0) } ?? "")
        _quantity = State(initialValue: trade.quantity.map { String($0) } ?? "")
        _leverage = State(initialValue: trade.leverage)
        _selectedExchangeId = State(initialValue: trade.exchangeId)
        _selectedOrderRole = State(initialValue: trade.orderRole)
        _selectedSystemId = State(initialValue: trade.systemId)
        _selectedSession = State(initialValue: trade.session)
        _flashPnL = State(initialValue: trade.flashPnLNet.map { String($0) } ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations du Trade") {
                    TextField("Symbole", text: $symbol)
                        .autocapitalization(.allCharacters)
                    
                    Picker("Type", selection: $selectedType) {
                        Text(t("long")).tag(TradeType.long)
                        Text(t("short")).tag(TradeType.short)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Prix") {
                    TextField("Prix d'entrée", text: $entryPrice)
                        .keyboardType(.decimalPad)
                    
                    TextField("Prix de sortie", text: $exitPrice)
                        .keyboardType(.decimalPad)
                }
                
                Section("Quantité et Effet de levier") {
                    TextField("Quantité", text: $quantity)
                        .keyboardType(.decimalPad)
                    
                    VStack(alignment: .leading) {
                        Text("Effet de levier: \(String(format: "%.1f", leverage))x")
                        Slider(value: $leverage, in: 1...100, step: 0.1)
                    }
                }
                
                Section("Exchange et Système") {
                    Picker("Exchange", selection: $selectedExchangeId) {
                        ForEach(appState.exchanges) { exchange in
                            Text(exchange.name).tag(exchange.id as UUID?)
                        }
                    }
                    
                    Picker("Système", selection: $selectedSystemId) {
                        ForEach(appState.systems) { system in
                            Text(system.name).tag(system.id as UUID?)
                        }
                    }
                }
                
                Section("Rôle et Session") {
                    Picker("Rôle", selection: $selectedOrderRole) {
                        Text(t("maker")).tag(OrderRole.maker)
                        Text(t("taker")).tag(OrderRole.taker)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Picker("Session", selection: $selectedSession) {
                        Text(t("bullish")).tag(Session.us)
                        Text(t("ai")).tag(Session.asia)
                        Text(t("europe")).tag(Session.europe)
                    }
                }
                
                Section("P&L Flash") {
                    TextField("P&L Flash", text: $flashPnL)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(t("editTrade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        saveTrade()
                    }
                }
            }
        }
    }
    
    private func saveTrade() {
        guard !symbol.isEmpty,
              let exchangeId = selectedExchangeId,
              let systemId = selectedSystemId else { return }
        
        // Créer une nouvelle instance avec le même ID que l'original
        let updatedTrade = Trade(
            id: trade.id,
            date: trade.date,
            symbol: symbol.uppercased(),
            type: selectedType,
            entryPrice: Double(entryPrice),
            exitPrice: Double(exitPrice),
            quantity: Double(quantity),
            leverage: leverage,
            exchangeId: exchangeId,
            orderRole: selectedOrderRole,
            systemId: systemId,
            session: selectedSession,
            flashPnLNet: Double(flashPnL)
        )
        
        appState.updateTrade(updatedTrade)
        dismiss()
    }
}
