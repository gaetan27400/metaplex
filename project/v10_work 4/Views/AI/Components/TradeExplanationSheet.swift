//
//  TradeExplanationSheet.swift
//  Journal de trading 2025
//
//  Modal d'explication d'un scénario de trade

import SwiftUI

struct TradeExplanationSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared
    let type: TradeScenarioCard.ScenarioType
    let explanation: ScenarioExplanation
    
    private var noDataLabel: String {
        Localizable.text("dataUnavailable", language: languageManager.currentLanguage)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title with icon
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.system(size: 32))
                            .foregroundColor(type.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pourquoi ce scénario ?")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(type.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(type.color)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Raisons
                    if !explanation.reasons.isEmpty {
                        sectionCard(
                            title: "Raisons du scénario",
                            icon: "checkmark.circle.fill",
                            color: .blue,
                            items: explanation.reasons
                        )
                    }
                    
                    // Conditions de validation
                    if !explanation.validationConditions.isEmpty {
                        sectionCard(
                            title: "Conditions de validation",
                            icon: "flag.checkered",
                            color: .green,
                            items: explanation.validationConditions
                        )
                    }
                    
                    // Invalidation
                    if !explanation.invalidation.isEmpty {
                        sectionCard(
                            title: "Invalidation",
                            icon: "xmark.octagon.fill",
                            color: .red,
                            items: explanation.invalidation
                        )
                    }
                    
                    // Risques
                    if !explanation.risks.isEmpty {
                        sectionCard(
                            title: "Risques à surveiller",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            items: explanation.risks
                        )
                    }
                }
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Explication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    // MARK: - Section Card
    
    private func sectionCard(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if item != "Donnée non disponible" {
                        bulletPoint(text: item, color: color)
                    } else {
                        Text(noDataLabel)
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.08))
        )
    }
    
    private func bulletPoint(text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .offset(y: 6)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Scenario Explanation Model

struct ScenarioExplanation {
    let reasons: [String]
    let validationConditions: [String]
    let invalidation: [String]
    let risks: [String]
    
    static let mockBull = ScenarioExplanation(
        reasons: [
            "RSI multi-timeframes en zone neutre à légèrement survendu, suggérant un potentiel de rebond",
            "VMC montre une divergence haussière sur le H4 avec diminution de la pression vendeuse",
            "Volume d'achat en augmentation sur les dernières sessions"
        ],
        validationConditions: [
            "Cassure confirmée au-dessus de 67200 avec volume supérieur à la moyenne",
            "Clôture H1 au-dessus de la résistance avec retest réussi"
        ],
        invalidation: [
            "Rejet violent sous 66800 avec augmentation du volume vendeur"
        ],
        risks: [
            "Volatilité élevée pouvant provoquer des stop loss prématurés",
            "Contexte macro incertain avec annonce économique imminente"
        ]
    )
    
    static let mockBear = ScenarioExplanation(
        reasons: [
            "RSI en zone de surachat sur plusieurs timeframes",
            "Formation d'une divergence baissière sur le H4 (prix monte, momentum descend)",
            "Rejet visible à la résistance majeure 67500"
        ],
        validationConditions: [
            "Cassure confirmée sous 66950 avec volume vendeur fort",
            "Échec de retest de la zone 67000 comme support"
        ],
        invalidation: [
            "Reprise haussière au-dessus de 67450 avec clôture H1 confirmée"
        ],
        risks: [
            "Squeeze possible si les acheteurs défendent la zone 67000",
            "News imprévue pouvant inverser la tendance rapidement"
        ]
    )
    
    static var empty: ScenarioExplanation {
        let noData = Localizable.text("dataUnavailable", language: LanguageManager.shared.currentLanguage)
        return ScenarioExplanation(
            reasons: [noData],
            validationConditions: [noData],
            invalidation: [noData],
            risks: [noData]
        )
    }
}

// MARK: - Preview

#Preview {
    TradeExplanationSheet(
        type: .bull,
        explanation: .mockBull
    )
}
