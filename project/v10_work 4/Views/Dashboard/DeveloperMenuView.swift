import Foundation
import SwiftUI
import Combine

// MARK: - Developer Menu View
struct DeveloperMenuView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var isGenerating = false
    @State private var generationProgress: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Trades actuels")
                        Spacer()
                        Text("\(appState.trades.count)")
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Systèmes")
                        Spacer()
                        Text("\(appState.systems.count)")
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Exchanges")
                        Spacer()
                        Text("\(appState.exchanges.count)")
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                    }
                } header: {
                    Text("Statistiques")
                }
                
                Section {
                    Button(action: {
                        appState.generateTestSystems()
                        HapticFeedback.success()
                    }) {
                        Label("Générer des Systèmes de Test", systemImage: "chart.bar.doc.horizontal")
                    }
                    
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text(generationProgress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Configuration")
                }
                
                Section {
                    Button(action: {
                        HapticFeedback.selection()
                        appState.loadTestData()
                        dismiss()
                    }) {
                        Label("Générer 150 Trades de Test", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: {
                        HapticFeedback.selection()
                        isGenerating = true
                        generationProgress = "Génération de 1 000 trades..."
                        Task {
                            await appState.generateMassiveTestDataAsync(count: 1000)
                            await MainActor.run {
                                isGenerating = false
                                dismiss()
                            }
                        }
                    }) {
                        Label("Générer 1 000 Trades", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: {
                        HapticFeedback.selection()
                        isGenerating = true
                        generationProgress = "Génération de 5 000 trades..."
                        Task {
                            await appState.generateMassiveTestDataAsync(count: 5000)
                            await MainActor.run {
                                isGenerating = false
                                dismiss()
                            }
                        }
                    }) {
                        Label("Générer 5 000 Trades", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: {
                        HapticFeedback.selection()
                        isGenerating = true
                        generationProgress = "Génération de 10 000 trades..."
                        Task {
                            await appState.generateMassiveTestDataAsync(count: 10000)
                            await MainActor.run {
                                isGenerating = false
                                dismiss()
                            }
                        }
                    }) {
                        Label("Générer 10 000 Trades", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: {
                        HapticFeedback.selection()
                        isGenerating = true
                        generationProgress = "Génération de données émotionnelles..."
                        Task {
                            await appState.generateTestMoodData(count: 200)
                            await MainActor.run {
                                isGenerating = false
                                dismiss()
                            }
                        }
                    }) {
                        Label("Générer 200 Entrées Émotionnelles (1/jour)", systemImage: "heart.text.square.fill")
                    }
                    
                    Button(action: {
                        HapticFeedback.selection()
                        isGenerating = true
                        generationProgress = "Génération d'émotions intenses..."
                        Task {
                            await appState.generateTestMoodData(count: 120, highPressureBias: 0.85)
                            await MainActor.run {
                                isGenerating = false
                                dismiss()
                            }
                        }
                    }) {
                        Label("Générer émotions intenses (danger)", systemImage: "exclamationmark.triangle.fill")
                    }
                } header: {
                    Text("Génération de Données")
                } footer: {
                    Text("Génère des trades aléatoires sur les 12 derniers mois pour remplir l'application avec des données de démonstration.")
                }
                
                Section {
                    Button(action: {
                        HapticFeedback.warning()
                        appState.clearAllTrades()
                        dismiss()
                    }) {
                        Label("Effacer Tous les Trades", systemImage: "trash")
                            .foregroundColor(AppColors.error)
                    }
                    
                    Button(action: {
                        HapticFeedback.error()
                        appState.clearAllData()
                        dismiss()
                    }) {
                        Label("Reset Complet (Toutes les Données)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.error)
                    }
                } header: {
                    Text("Réinitialisation")
                } footer: {
                    Text("⚠️ Attention: Ces actions sont irréversibles. Toutes les données seront supprimées.")
                }
                
                Section {
                    Button(action: {
                        appState.reassignTradesToSystems()
                        HapticFeedback.success()
                        dismiss()
                    }) {
                        Label("Réassigner les Trades aux Systèmes", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button(action: {
                        print("🔍 DEBUG SYSTÈMES:")
                        print("🔍   - Nombre de systèmes: \(appState.systems.count)")
                        print("🔍   - Nombre de trades: \(appState.trades.count)")
                        
                        for system in appState.systems {
                            let systemTrades = appState.trades.filter { $0.systemId == system.id }
                            print("🔍   - Système '\(system.name)': \(systemTrades.count) trades")
                            
                            let longTrades = systemTrades.filter { $0.type == .long }
                            let shortTrades = systemTrades.filter { $0.type == .short }
                            print("🔍     LONG: \(longTrades.count), SHORT: \(shortTrades.count)")
                        }
                        HapticFeedback.selection()
                        dismiss()
                    }) {
                        Label("Debug Systèmes", systemImage: "ladybug")
                    }
                } header: {
                    Text("Outils")
                }
                
                Section {
                    Button(action: {
                        Task {
                            for api in appState.apiManager.connectedAPIs {
                                let result = try? await appState.apiManager.testAPI(api)
                                print("\(api.name): \(result ?? false)")
                            }
                            HapticFeedback.selection()
                        }
                    }) {
                        Label("Tester APIs connectées", systemImage: "network")
                    }
                    
                    ForEach(appState.apiManager.connectedAPIs) { api in
                        HStack {
                            Text(api.name)
                            Spacer()
                            if api.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.success)
                            }
                        }
                    }
                } header: {
                    Text("API Testing")
                }
            }
            .navigationTitle("Menu Développeur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Metric Card Component
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    var size: Size = .normal
    
    enum Size {
        case normal, small
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(size == .normal ? .system(size: 24, weight: .bold) : .system(size: 18, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .foregroundColor(AppColors.textPrimary)
        .cornerRadius(12)
    }
}

// MARK: - Open Trade Summary Row

struct OpenTradeSummaryRow: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Symbole et type
            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                Text(trade.symbol)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                HStack(spacing: AppSpacing.xs) {
                    Text(trade.type.rawValue)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(trade.type == .long ? AppColors.success : AppColors.error)
                    
                    if let qty = trade.quantity {
                        Text("• \(String(format: "%.2f", qty))")
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            // Prix actuel et P&L
            VStack(alignment: .trailing, spacing: AppSpacing.xxxs) {
                if let current = trade.currentPrice {
                    Text(formatPrice(current))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                if let unrealizedPnL = trade.unrealizedPnL {
                    Text(formatCurrency(unrealizedPnL))
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(unrealizedPnL >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(AppColors.background)
        )
    }
    
    private func formatPrice(_ price: Double) -> String {
        String(format: "%.2f", price)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Professional Metric Card
struct ProfessionalMetricCard: View {
    let value: String
    let title: String
    let subtitle: String
    let color: Color
    let icon: String

    // Formater intelligemment les grands montants
    private var displayValue: String {
        // Si valeur monétaire avec beaucoup de chiffres → abréger
        if value.hasPrefix("$") || value.hasPrefix("-$") {
            let prefix = value.hasPrefix("-") ? "-$" : "$"
            let digits = value.replacingOccurrences(of: "$", with: "")
                              .replacingOccurrences(of: "-", with: "")
                              .replacingOccurrences(of: ",", with: "")
            if let d = Double(digits) {
                if d >= 1_000_000 { return prefix + String(format: "%.2fM", d / 1_000_000) }
                if d >= 10_000    { return prefix + String(format: "%.0fK", d / 1_000) }
            }
        }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Icône + badge couleur
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            // Valeur principale — adaptative
            Text(displayValue)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: false)

            // Titre
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)

            // Sous-titre
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(color.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 90)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.18), color.opacity(0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 1))
        )
        .shadow(color: color.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Performance Card
struct PerformanceCard: View {
    let title: String
    let winRate: Double
    let trades: Int
    let pnl: Double
    let color: Color
    let language: Localizable.Language

    private var isLong: Bool { color == AppColors.success }

    // Formatage PnL abrégé
    private var pnlFormatted: String {
        let abs = Swift.abs(pnl)
        let sign = pnl < 0 ? "-" : "+"
        if abs >= 1_000_000 { return sign + String(format: "$%.2fM", abs / 1_000_000) }
        if abs >= 10_000    { return sign + String(format: "$%.1fK", abs / 1_000) }
        return String(format: "%@$%.0f", sign, abs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: isLong ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)

            // Ligne de séparation colorée
            Rectangle()
                .fill(color.opacity(0.25))
                .frame(height: 1)
                .padding(.bottom, 10)

            // ── Win Rate (grande valeur) ─────────────────
            HStack(alignment: .bottom) {
                Text(String(format: "%.1f%%", winRate))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Localizable.text("winRate", language: language))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(trades) trades")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .padding(.bottom, 8)

            // ── P&L abrégé ──────────────────────────────
            HStack(alignment: .center, spacing: 6) {
                Text("P&L")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppColors.textSecondary.opacity(0.1)))

                Spacer()

                Text(pnlFormatted)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(pnl >= 0 ? AppColors.success : AppColors.error)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}


// MARK: - Systems View

