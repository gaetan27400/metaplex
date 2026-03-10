//
//  AdvancedTradeFiltersView.swift
//  Journal de trading 2025
//
//  Vue de filtres avancés avec multi-sélection et sauvegarde

import SwiftUI

struct AdvancedTradeFiltersView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @Environment(\.dismiss) private var dismiss
    @Binding var filters: TradeFilters
    let systems: [TradingSystem]
    let exchanges: [Exchange]
    
    @State private var tempFilters: TradeFilters
    @State private var filterName = ""
    @State private var showingSaveFilter = false
    
    init(filters: Binding<TradeFilters>, systems: [TradingSystem], exchanges: [Exchange]) {
        self._filters = filters
        self.systems = systems
        self.exchanges = exchanges
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Période
                Section("Période") {
                    DatePicker("Début", selection: Binding(
                        get: { tempFilters.startDate ?? Date().addingTimeInterval(-30 * 24 * 60 * 60) },
                        set: { tempFilters.startDate = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("Fin", selection: Binding(
                        get: { tempFilters.endDate ?? Date() },
                        set: { tempFilters.endDate = $0 }
                    ), displayedComponents: .date)
                    
                    Button("Réinitialiser") {
                        tempFilters.startDate = nil
                        tempFilters.endDate = nil
                    }
                    .foregroundColor(AppColors.primary)
                }
                
                // Symboles
                Section("Symboles") {
                    TextField("Rechercher un symbole...", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    
                    // Liste des symboles uniques (serait chargée depuis les trades)
                    // Pour l'instant, placeholder
                    Text(t("slectionMultipleDeSymboles"))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Type
                Section("Type de Trade") {
                    Toggle("Long", isOn: Binding(
                        get: { tempFilters.includeLong },
                        set: { tempFilters.includeLong = $0 }
                    ))
                    
                    Toggle("Short", isOn: Binding(
                        get: { tempFilters.includeShort },
                        set: { tempFilters.includeShort = $0 }
                    ))
                }
                
                // Systèmes
                Section("Systèmes de Trading") {
                    ForEach(systems) { system in
                        Toggle(system.name, isOn: Binding(
                            get: { tempFilters.selectedSystems.contains(system.id) },
                            set: { isOn in
                                if isOn {
                                    tempFilters.selectedSystems.insert(system.id)
                                } else {
                                    tempFilters.selectedSystems.remove(system.id)
                                }
                            }
                        ))
                    }
                }
                
                // Exchanges
                Section("Exchanges") {
                    ForEach(exchanges) { exchange in
                        Toggle(exchange.name, isOn: Binding(
                            get: { tempFilters.selectedExchanges.contains(exchange.id) },
                            set: { isOn in
                                if isOn {
                                    tempFilters.selectedExchanges.insert(exchange.id)
                                } else {
                                    tempFilters.selectedExchanges.remove(exchange.id)
                                }
                            }
                        ))
                    }
                }
                
                // P&L Range
                Section("P&L Net") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Min: $\(String(format: "%.2f", tempFilters.minPnL))")
                            Spacer()
                            Text("Max: $\(String(format: "%.2f", tempFilters.maxPnL))")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        
                        HStack {
                            Slider(value: $tempFilters.minPnL, in: -10000...10000, step: 100)
                            Slider(value: $tempFilters.maxPnL, in: -10000...10000, step: 100)
                        }
                    }
                }
                
                // Résultat
                Section("Résultat") {
                    Toggle("Gains uniquement", isOn: Binding(
                        get: { tempFilters.showOnlyWins },
                        set: { tempFilters.showOnlyWins = $0 }
                    ))
                    
                    Toggle("Pertes uniquement", isOn: Binding(
                        get: { tempFilters.showOnlyLosses },
                        set: { tempFilters.showOnlyLosses = $0 }
                    ))
                    
                    Toggle("Break-even uniquement", isOn: Binding(
                        get: { tempFilters.showOnlyBreakEven },
                        set: { tempFilters.showOnlyBreakEven = $0 }
                    ))
                }
            }
            .navigationTitle(t("advancedFilters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("add")) {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sauvegarder les filtres") {
                            showingSaveFilter = true
                        }
                        
                        Button("Réinitialiser") {
                            resetFilters()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSaveFilter) {
                SaveFilterView(filterName: $filterName) {
                    // TODO: Sauvegarder le filtre
                    showingSaveFilter = false
                }
            }
        }
    }
    
    private func applyFilters() {
        filters = tempFilters
        dismiss()
    }
    
    private func resetFilters() {
        tempFilters = TradeFilters()
    }
}

// MARK: - Trade Filters Model
struct TradeFilters: Codable {
    var startDate: Date?
    var endDate: Date?
    var selectedSymbols: Set<String> = []
    var includeLong: Bool = true
    var includeShort: Bool = true
    var selectedSystems: Set<UUID> = []
    var selectedExchanges: Set<UUID> = []
    var minPnL: Double = -10000
    var maxPnL: Double = 10000
    var showOnlyWins: Bool = false
    var showOnlyLosses: Bool = false
    var showOnlyBreakEven: Bool = false
    
    func apply(to trades: [Trade]) -> [Trade] {
        var filtered = trades
        
        // Date range
        if let startDate = startDate {
            filtered = filtered.filter { $0.date >= startDate }
        }
        if let endDate = endDate {
            filtered = filtered.filter { $0.date <= endDate }
        }
        
        // Symbols
        if !selectedSymbols.isEmpty {
            filtered = filtered.filter { selectedSymbols.contains($0.symbol) }
        }
        
        // Type
        if !includeLong {
            filtered = filtered.filter { $0.type != .long }
        }
        if !includeShort {
            filtered = filtered.filter { $0.type != .short }
        }
        
        // Systems
        if !selectedSystems.isEmpty {
            filtered = filtered.filter { selectedSystems.contains($0.systemId) }
        }
        
        // Exchanges
        if !selectedExchanges.isEmpty {
            filtered = filtered.filter { selectedExchanges.contains($0.exchangeId) }
        }
        
        // P&L Range - utiliser pnl qui gère les trades ouverts et fermés
        filtered = filtered.filter { trade in
            let pnl = trade.pnl // Utilise pnl qui gère unrealizedPnL pour les trades ouverts
            return pnl >= minPnL && pnl <= maxPnL
        }
        
        // Result - utiliser pnl qui gère les trades ouverts et fermés
        if showOnlyWins {
            filtered = filtered.filter { $0.pnl > 0 }
        }
        if showOnlyLosses {
            filtered = filtered.filter { $0.pnl < 0 }
        }
        if showOnlyBreakEven {
            filtered = filtered.filter { $0.pnl == 0 }
        }
        
        return filtered
    }
    
    var isEmpty: Bool {
        startDate == nil &&
        endDate == nil &&
        selectedSymbols.isEmpty &&
        includeLong && includeShort &&
        selectedSystems.isEmpty &&
        selectedExchanges.isEmpty &&
        minPnL == -10000 &&
        maxPnL == 10000 &&
        !showOnlyWins &&
        !showOnlyLosses &&
        !showOnlyBreakEven
    }
}

// MARK: - Save Filter View
struct SaveFilterView: View {
    @Binding var filterName: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Nom du filtre") {
                    TextField("Ex: Gains cette semaine", text: $filterName)
                }
            }
            .navigationTitle(t("saveFilter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        onSave()
                        dismiss()
                    }
                    .disabled(filterName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AdvancedTradeFiltersView(
        filters: .constant(TradeFilters()),
        systems: [],
        exchanges: []
    )
}
