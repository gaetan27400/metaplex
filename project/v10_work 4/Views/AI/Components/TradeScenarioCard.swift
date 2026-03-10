//
//  TradeScenarioCard.swift
//  Journal de trading 2025
//
//  Carte de scénario de trade (Bull/Bear) symétrique

import SwiftUI

struct TradeScenarioCard: View {
    let type: ScenarioType
    let scenario: TradeScenario
    let onInfoTap: () -> Void
    
    enum ScenarioType {
        case bull
        case bear
        
        var title: String {
            let lang = LanguageManager.shared.currentLanguage
            switch self {
            case .bull: return Localizable.text("bullishScenario", language: lang)
            case .bear: return Localizable.text("bearishScenario", language: lang)
            }
        }
        
        var color: Color {
            switch self {
            case .bull: return .green
            case .bear: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .bull: return "arrow.up.right.circle.fill"
            case .bear: return "arrow.down.right.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // HEADER
            header
            
            Divider()
                .background(AppColors.border.opacity(0.2))
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 12) {
                // SUBHEADER - Type d'entrée
                if let entryType = scenario.entryType {
                    subheader(entryType: entryType)
                }
                
                // ENTRY / STOP
                entryStopSection
                
                Divider()
                    .background(AppColors.border.opacity(0.2))
                
                // OBJECTIFS (TP)
                targetsSection
                
                Divider()
                    .background(AppColors.border.opacity(0.2))
                
                // SYNTHÈSE %
                summarySection
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .frame(minHeight: 240) // Hauteur minimale pour homogénéité
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            // Dot + Title
            HStack(spacing: 8) {
                Circle()
                    .fill(type.color)
                    .frame(width: 8, height: 8)
                
                Text(type.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
            
            // Info button
            Button(action: {
                HapticFeedback.selection()
                onInfoTap()
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundColor(type.color.opacity(0.7))
                    .frame(width: 44, height: 44) // Zone tactile min
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Subheader
    
    private func subheader(entryType: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.system(size: 11))
                .foregroundColor(type.color.opacity(0.6))
            
            Text("Type : \(entryType)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(type.color.opacity(0.1))
        )
    }
    
    // MARK: - Entry / Stop Section
    
    private var entryStopSection: some View {
        VStack(spacing: 8) {
            // Entry
            dataRow(
                label: t("entryLabel"),
                value: scenario.entry != nil ? formatPrice(scenario.entry!) : "—",
                color: type.color
            )
            
            // Stop
            dataRow(
                label: t("stopLabel"),
                value: scenario.stop != nil ? formatPrice(scenario.stop!) : "—",
                color: .red
            )
        }
    }
    
    // MARK: - Targets Section
    
    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("objectivesLabel"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                // TP1
                targetRow(
                    label: "TP1",
                    price: scenario.tp1,
                    rr: scenario.tp1RR
                )
                
                // TP2
                targetRow(
                    label: "TP2",
                    price: scenario.tp2,
                    rr: scenario.tp2RR
                )
                
                // TP3
                targetRow(
                    label: "TP3",
                    price: scenario.tp3,
                    rr: scenario.tp3RR
                )
            }
        }
    }
    
    private func targetRow(label: String, price: Double?, rr: String?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 35, alignment: .leading)
            
            if let price = price {
                Text(formatPrice(price))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                if let rr = rr {
                    Text(rr)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(type.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(type.color.opacity(0.15))
                        )
                }
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }
        }
        .frame(height: 24) // Hauteur fixe pour alignement
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 6) {
            // Risk
            if let riskPercent = scenario.riskPercent {
                summaryRow(
                    label: t("riskLabel"),
                    value: String(format: "%.1f%%", riskPercent),
                    color: .red
                )
            } else {
                summaryRow(label: t("riskLabel"), value: "—", color: .gray)
            }
            
            // Potential TP2
            if let potentialTP2 = scenario.potentialTP2Percent {
                summaryRow(
                    label: t("potentialTP2Label"),
                    value: String(format: "+%.1f%%", potentialTP2),
                    color: .green
                )
            } else {
                summaryRow(label: t("potentialTP2Label"), value: "—", color: .gray)
            }
        }
    }
    
    private func summaryRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Data Row (reusable)
    
    private func dataRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Helper
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0f", price)
        } else if price >= 1 {
            return String(format: "%.2f", price)
        } else {
            return String(format: "%.4f", price)
        }
    }
}

// MARK: - Trade Scenario Model

struct TradeScenario {
    let entryType: String? // "Cassure", "Rejet", "Retest", "Pullback"
    let entry: Double?
    let stop: Double?
    let tp1: Double?
    let tp1RR: String? // "RR 1:1"
    let tp2: Double?
    let tp2RR: String? // "RR 2:1"
    let tp3: Double?
    let tp3RR: String? // "RR 3:1"
    let riskPercent: Double? // -2.5
    let potentialTP2Percent: Double? // +5.0
    
    static let mockBull = TradeScenario(
        entryType: "Cassure",
        entry: 67250,
        stop: 66800,
        tp1: 67700,
        tp1RR: "RR 1:1",
        tp2: 68150,
        tp2RR: "RR 2:1",
        tp3: 68600,
        tp3RR: "RR 3:1",
        riskPercent: -0.67,
        potentialTP2Percent: 1.34
    )
    
    static let mockBear = TradeScenario(
        entryType: "Rejet",
        entry: 67000,
        stop: 67450,
        tp1: 66550,
        tp1RR: "RR 1:1",
        tp2: 66100,
        tp2RR: "RR 2:1",
        tp3: nil,
        tp3RR: nil,
        riskPercent: -0.67,
        potentialTP2Percent: 1.34
    )
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        TradeScenarioCard(
            type: .bull,
            scenario: .mockBull,
            onInfoTap: {
                print("Info tapped - Bull")
            }
        )
        
        TradeScenarioCard(
            type: .bear,
            scenario: .mockBear,
            onInfoTap: {
                print("Info tapped - Bear")
            }
        )
    }
    .padding()
    .background(AppColors.background)
}
