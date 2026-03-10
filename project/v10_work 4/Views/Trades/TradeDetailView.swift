//
//  TradeDetailView.swift
//  Journal de trading 2025
//
//  Vue détaillée enrichie d'un trade avec métriques avancées et graphiques

import SwiftUI
import Charts

struct TradeDetailView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let trade: Trade
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    var system: TradingSystem? {
        appState.systems.first { $0.id == trade.systemId }
    }
    
    var exchange: Exchange? {
        appState.exchanges.first { $0.id == trade.exchangeId }
    }
    
    var pnl: Double {
        trade.flashPnLNet ?? 0
    }
    
    var isProfit: Bool {
        pnl >= 0
    }
    
    var roi: Double? {
        guard let entry = trade.entryPrice, let exit = trade.exitPrice else { return nil }
        return ((exit - entry) / entry) * 100
    }
    
    var riskReward: Double? {
        guard let entry = trade.entryPrice, let exit = trade.exitPrice else { return nil }
        let priceChange = abs(exit - entry)
        // Approximation simple du R:R
        return priceChange / entry
    }
    
    var holdingTime: TimeInterval? {
        // Si on avait une date de sortie, on pourrait calculer
        // Pour l'instant, on utilise la date du trade
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header avec symbole et P&L
                    headerSection
                    
                    // Métriques principales
                    mainMetricsSection
                    
                    // Détails du trade
                    tradeDetailsSection
                    
                    // Métriques avancées
                    advancedMetricsSection
                    
                    // Graphique de prix (si disponible)
                    if let entry = trade.entryPrice, let exit = trade.exitPrice {
                        priceChartSection(entry: entry, exit: exit)
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle(t("tradeDetail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingEditSheet = true
                        }) {
                            Label("Modifier", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Supprimer", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditTradeView(trade: trade)
                    .environmentObject(appState)
            }
            .alert("Supprimer le trade", isPresented: $showingDeleteConfirmation) {
                Button("Annuler", role: .cancel) { }
                Button("Supprimer", role: .destructive) {
                    deleteTrade()
                }
            } message: {
                Text(t("delete"))
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Symbole
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(trade.symbol)
                        .font(AppTypography.displaySmall)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack(spacing: AppSpacing.sm) {
                        // Type badge
                        TypeBadge(type: trade.type)
                        
                        // Système
                        if let system = system {
                            SystemBadge(system: system)
                        }
                    }
                }
                
                Spacer()
                
                // P&L en grand
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: isProfit ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.title2)
                        Text(String(format: "$%.2f", pnl))
                            .font(AppTypography.displayMedium)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(isProfit ? AppColors.success : AppColors.error)
                    
                    if let roi = roi {
                        Text(String(format: "%.2f%%", roi))
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    isProfit ? AppColors.success.opacity(0.3) : AppColors.error.opacity(0.3),
                                    AppColors.primary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
    }
    
    // MARK: - Main Metrics Section
    private var mainMetricsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: AppSpacing.md) {
            TradeDetailMetricCard(
                title: "P&L Net",
                value: String(format: "$%.2f", pnl),
                icon: "dollarsign.circle.fill",
                color: isProfit ? AppColors.success : AppColors.error
            )
            
            if let roi = roi {
                TradeDetailMetricCard(
                    title: "ROI",
                    value: String(format: "%.2f%%", roi),
                    icon: "percent",
                    color: roi >= 0 ? AppColors.success : AppColors.error
                )
            }
            
            if let entry = trade.entryPrice {
                TradeDetailMetricCard(
                    title: "Prix d'entrée",
                    value: String(format: "$%.2f", entry),
                    icon: "arrow.down.circle.fill",
                    color: AppColors.primary
                )
            }
            
            if let exit = trade.exitPrice {
                TradeDetailMetricCard(
                    title: "Prix de sortie",
                    value: String(format: "$%.2f", exit),
                    icon: "arrow.up.circle.fill",
                    color: AppColors.primary
                )
            }
        }
    }
    
    // MARK: - Trade Details Section
    private var tradeDetailsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("ai"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                DetailRow(label: "Date", value: formatDate(trade.date))
                
                if let quantity = trade.quantity {
                    DetailRow(label: "Quantité", value: String(format: "%.4f", quantity))
                }
                
                if trade.leverage > 1 {
                    DetailRow(label: "Effet de levier", value: String(format: "%.1fx", trade.leverage))
                }
                
                if let exchange = exchange {
                    DetailRow(label: "Exchange", value: exchange.name)
                }
                
                DetailRow(label: "Rôle", value: trade.orderRole == .maker ? "Maker" : "Taker")
                DetailRow(label: "Session", value: trade.session.displayName)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Advanced Metrics Section
    private var advancedMetricsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("mtriquesAvances"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                if let riskReward = riskReward {
                    DetailRow(
                        label: "Risk:Reward",
                        value: String(format: "1:%.2f", riskReward)
                    )
                }
                
                if let entry = trade.entryPrice, let exit = trade.exitPrice {
                    let priceChange = exit - entry
                    DetailRow(
                        label: "Variation de prix",
                        value: String(format: "$%.2f (%.2f%%)", priceChange, (priceChange / entry) * 100)
                    )
                }
                
                if let exchange = exchange {
                    let feeRate = trade.orderRole == .maker ? exchange.makerFeeRate : exchange.takerFeeRate
                    if let entry = trade.entryPrice, let quantity = trade.quantity {
                        let notional = entry * quantity * trade.leverage
                        let fees = notional * feeRate
                        DetailRow(
                            label: "Frais estimés",
                            value: String(format: "$%.2f (%.3f%%)", fees, feeRate * 100)
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Price Chart Section
    private func priceChartSection(entry: Double, exit: Double) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("price"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            // Graphique simple montrant entry → exit
            HStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("entry"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "$%.2f", entry))
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.primary)
                }
                
                // Ligne avec flèche
                GeometryReader { geometry in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                    }
                    .stroke(
                        trade.type == .long ? AppColors.success : AppColors.error,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .overlay(
                        Image(systemName: trade.type == .long ? "arrow.right" : "arrow.left")
                            .font(.caption)
                            .foregroundColor(trade.type == .long ? AppColors.success : AppColors.error)
                            .offset(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    )
                }
                .frame(height: 30)
                
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    Text(t("exit"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "$%.2f", exit))
                        .font(AppTypography.titleMedium)
                        .foregroundColor(isProfit ? AppColors.success : AppColors.error)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: AppSpacing.md) {
            Button(action: {
                duplicateTrade()
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text(t("dupliquerLeTrade"))
                }
                .font(AppTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.primary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.primary, lineWidth: 1.5)
                        )
                )
            }
            
            Button(action: {
                shareTrade()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(t("partager"))
                }
                .font(AppTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
    
    private func deleteTrade() {
        appState.deleteTrade(trade)
        HapticFeedback.success()
        dismiss()
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
    
    private func shareTrade() {
        // TODO: Implémenter le partage
        HapticFeedback.light()
    }
}

// MARK: - Supporting Views
struct TypeBadge: View {
    let type: TradeType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type == .long ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.caption)
            Text(type.rawValue.uppercased())
                .font(AppTypography.captionSmall)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(type == .long ? AppColors.success : AppColors.error)
        )
    }
}

struct SystemBadge: View {
    let system: TradingSystem
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: system.color))
                .frame(width: 8, height: 8)
            Text(system.name)
                .font(AppTypography.captionSmall)
                .fontWeight(.medium)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AppColors.cardBackground)
                .overlay(
                    Capsule()
                        .stroke(AppColors.border, lineWidth: 1)
                )
        )
    }
}

struct TradeDetailMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Text(value)
                .font(AppTypography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
        )
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

extension Session {
    var displayName: String {
        switch self {
        case .us: return "US"
        case .asia: return "Asia"
        case .europe: return "Europe"
        }
    }
}

#Preview {
    TradeDetailView(trade: Trade(
        date: Date(),
        symbol: "BTCUSDT",
        type: .long,
        entryPrice: 50000,
        exitPrice: 51000,
        quantity: 0.1,
        leverage: 1.0,
        exchangeId: UUID(),
        orderRole: .taker,
        systemId: UUID(),
        session: .us,
        flashPnLNet: 100
    ))
    .environmentObject(AppState())
}
