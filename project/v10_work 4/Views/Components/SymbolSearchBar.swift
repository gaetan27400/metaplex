//
//  SymbolSearchBar.swift
//  Journal de trading 2025
//
//  Barre de recherche d'actifs unifiée
//

import SwiftUI

struct SymbolSearchBar: View {
    @Binding var selectedSymbol: MarketSymbol
    @State private var searchText = ""
    @State private var searchResults: [MarketSymbol] = []
    @State private var searchStatus: SearchStatus = .idle
    @State private var showResults = false
    @State private var searchTask: Task<Void, Never>?
    @State private var recentSymbols: [MarketSymbol] = []
    
    /// Clé UserDefaults pour persister l'historique
    private static let recentKey = "recentSearchedSymbols"
    private static let maxRecent = 6
    
    enum SearchStatus: Equatable {
        case idle, searching, found, notFound, error(String)
        static func == (lhs: SearchStatus, rhs: SearchStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.searching, .searching), (.found, .found), (.notFound, .notFound): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: selectedSymbol.instrumentType.marketIcon)
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                TextField("Rechercher un actif...", text: $searchText)
                    .font(AppTypography.bodySmall)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, newValue in
                        performSearch(query: newValue)
                    }
                    .onTapGesture { showResults = true }
                
                statusIndicator
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        searchStatus = .idle
                        showResults = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(showResults ? Color.orange.opacity(0.5) : AppColors.border.opacity(0.3), lineWidth: 1)
            )
            
            // Recherches récentes (visibles quand pas de recherche active)
            if searchText.isEmpty && !recentSymbols.isEmpty {
                recentSearchesView
            }
            
            // Selected symbol info
            HStack(spacing: AppSpacing.xs) {
                Text(selectedSymbol.displayName)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text("•").foregroundColor(AppColors.textTertiary)
                Text(selectedSymbol.exchange ?? "")
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                if !TwelveDataService.shared.hasAPIKey {
                    Text("Crypto uniquement")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                }
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.top, 4)
            
            // Results
            if showResults && !searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults) { symbol in
                            Button(action: {
                                selectSymbol(symbol)
                            }) {
                                symbolRow(symbol)
                            }
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 250)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                .padding(.top, 4)
            }
            
            if case .error(let msg) = searchStatus {
                Text(msg)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
        .onAppear { loadRecentSymbols() }
    }
    
    // MARK: - Recherches récentes
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
                Text("Récents")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                if recentSymbols.count > 1 {
                    Button(action: clearRecentSymbols) {
                        Text("Effacer")
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.top, 6)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(recentSymbols) { symbol in
                        Button(action: {
                            selectSymbol(symbol)
                            HapticFeedback.selection()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: symbol.instrumentType.marketIcon)
                                    .font(.system(size: 9))
                                    .foregroundColor(typeColor(symbol.instrumentType))
                                Text(symbol.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(symbol.id == selectedSymbol.id ? .orange : AppColors.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                symbol.id == selectedSymbol.id
                                    ? Color.orange.opacity(0.12)
                                    : AppColors.cardBackground
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    symbol.id == selectedSymbol.id
                                        ? Color.orange.opacity(0.4)
                                        : AppColors.border.opacity(0.2),
                                    lineWidth: 1
                                )
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xs)
            }
        }
    }
    
    // MARK: - Symbol Selection
    
    private func selectSymbol(_ symbol: MarketSymbol) {
        selectedSymbol = symbol
        searchText = ""
        searchResults = []
        showResults = false
        searchStatus = .idle
        addToRecent(symbol)
    }
    
    // MARK: - Recent Symbols Persistence
    
    private func addToRecent(_ symbol: MarketSymbol) {
        var recent = recentSymbols
        recent.removeAll { $0.symbol == symbol.symbol }
        recent.insert(symbol, at: 0)
        if recent.count > Self.maxRecent {
            recent = Array(recent.prefix(Self.maxRecent))
        }
        recentSymbols = recent
        saveRecentSymbols()
    }
    
    private func loadRecentSymbols() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentKey),
              let decoded = try? JSONDecoder().decode([RecentSymbolEntry].self, from: data) else {
            return
        }
        recentSymbols = decoded.map { $0.toMarketSymbol() }
    }
    
    private func saveRecentSymbols() {
        let entries = recentSymbols.map { RecentSymbolEntry(from: $0) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.recentKey)
        }
    }
    
    private func clearRecentSymbols() {
        recentSymbols = []
        UserDefaults.standard.removeObject(forKey: Self.recentKey)
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        Group {
            switch searchStatus {
            case .idle:
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            case .searching:
                ProgressView().scaleEffect(0.7)
            case .found:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            case .notFound:
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            }
        }
        .font(.system(size: 14))
    }
    
    // MARK: - Symbol Row
    
    private func symbolRow(_ symbol: MarketSymbol) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: symbol.instrumentType.marketIcon)
                .font(.system(size: 14))
                .foregroundColor(symbol == selectedSymbol ? .orange : AppColors.textSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.symbol)
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text(symbol.displayName)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(symbol.instrumentType.marketDisplayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(typeColor(symbol.instrumentType)))
                if let exchange = symbol.exchange {
                    Text(exchange)
                        .font(.system(size: 8))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(symbol == selectedSymbol ? Color.orange.opacity(0.08) : Color.clear)
    }
    
    private func typeColor(_ type: InstrumentType) -> Color {
        switch type {
        case .crypto: return .orange
        case .stocks: return .blue
        case .forex: return .green
        case .futures: return .brown
        case .options: return .purple
        }
    }
    
    // MARK: - Search
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            searchResults = []
            searchStatus = .idle
            showResults = false
            return
        }
        
        searchStatus = .searching
        showResults = true
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // debounce
            guard !Task.isCancelled else { return }
            
            var results: [MarketSymbol] = []
            
            // Always search Binance crypto (no key needed)
            do {
                let cryptoResults = try await TwelveDataService.shared.searchBinanceCrypto(query: query)
                results.append(contentsOf: cryptoResults)
            } catch {
                Logger.default.error("Binance search error: \(error.localizedDescription)")
            }
            
            // Search TwelveData if key available
            if TwelveDataService.shared.hasAPIKey {
                do {
                    let tdResults = try await TwelveDataService.shared.searchSymbols(query: query)
                    let existingSymbols = Set(results.map { $0.symbol })
                    let filtered = tdResults.filter { !existingSymbols.contains($0.symbol) }
                    results.append(contentsOf: filtered)
                } catch {
                    if results.isEmpty {
                        await MainActor.run {
                            searchStatus = .error("TwelveData: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                searchResults = results
                searchStatus = results.isEmpty ? .notFound : .found
            }
        }
    }
}

// MARK: - Persistence Model

/// Struct légère Codable pour sauvegarder les symboles récents dans UserDefaults.
/// MarketSymbol n'est pas Codable → on utilise cette struct intermédiaire.
private struct RecentSymbolEntry: Codable {
    let symbol: String
    let displayName: String
    let exchange: String?
    let instrumentType: String // rawValue de InstrumentType
    let currency: String?
    
    init(from ms: MarketSymbol) {
        self.symbol = ms.symbol
        self.displayName = ms.displayName
        self.exchange = ms.exchange
        self.instrumentType = ms.instrumentType.rawValue
        self.currency = ms.currency
    }
    
    func toMarketSymbol() -> MarketSymbol {
        MarketSymbol(
            symbol: symbol,
            displayName: displayName,
            exchange: exchange,
            instrumentType: InstrumentType(rawValue: instrumentType) ?? .crypto,
            currency: currency
        )
    }
}
