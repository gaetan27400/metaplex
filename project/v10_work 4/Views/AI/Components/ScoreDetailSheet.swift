//
//  ScoreDetailSheet.swift
//  Journal de trading 2025
//
//  Modal détaillée du score avec sous-scores

import SwiftUI

struct ScoreDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let advice: TradingAdviceSummary
    let instrumentType: InstrumentType
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header avec score principal
                    scoreHeader
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Sous-scores
                    subscoresSection
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Explication du score
                    explanationSection
                }
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Détails du score")
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
    
    // MARK: - Score Header
    
    private var scoreHeader: some View {
        VStack(spacing: 16) {
            ScoreRadial(
                score: advice.edgeScore / 10, // Convertir de 0-100 à 0-10
                size: 96,
                lineWidth: 8,
                showLabel: true
            )
            
            Text(advice.status.label)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: advice.status.color))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(hex: advice.status.color).opacity(0.15))
                )
            
            Text(statusDescription(for: advice.status))
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: advice.status.color).opacity(0.08))
        )
    }
    
    // MARK: - Subscores Section
    
    private var subscoresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cyan)
                Text("Composantes du score")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(spacing: 10) {
                subscoreRow(
                    label: "Discipline",
                    score: Double(advice.edgeScore) * 0.3 / 10, // Approximation
                    icon: "checkmark.shield.fill",
                    color: .green
                )
                
                subscoreRow(
                    label: "Momentum",
                    score: Double(advice.edgeScore) * 0.25 / 10,
                    icon: "arrow.up.right.circle.fill",
                    color: .blue
                )
                
                subscoreRow(
                    label: "Volume",
                    score: Double(advice.edgeScore) * 0.20 / 10,
                    icon: "chart.bar.xaxis",
                    color: .purple
                )
                
                subscoreRow(
                    label: "Sentiment",
                    score: Double(advice.edgeScore) * 0.15 / 10,
                    icon: "brain.head.profile",
                    color: .orange
                )
                
                subscoreRow(
                    label: "Structure",
                    score: Double(advice.edgeScore) * 0.10 / 10,
                    icon: "building.columns.fill",
                    color: .cyan
                )
                
                // Fondamentaux uniquement pour actions
                if instrumentType == .stocks {
                    subscoreRow(
                        label: "Fondamentaux",
                        score: nil, // Donnée non disponible pour MVP
                        icon: "doc.text.fill",
                        color: .yellow
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
        )
    }
    
    private func subscoreRow(label: String, score: Double?, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            // Label
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            // Score ou N/A
            if let score = score {
                HStack(spacing: 8) {
                    // Mini bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.opacity(0.15))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color)
                                .frame(width: geo.size.width * score, height: 6)
                        }
                    }
                    .frame(width: 60, height: 6)
                    
                    // Value
                    Text(String(format: "%.1f", score * 10))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .frame(width: 35, alignment: .trailing)
                }
            } else {
                Text("N/A")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.background.opacity(0.5))
        )
    }
    
    // MARK: - Explanation Section
    
    @State private var showFullExplanation = false
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Explication du score")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(shortExplanation)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            if !showFullExplanation && !longExplanation.isEmpty {
                Button(action: {
                    withAnimation {
                        showFullExplanation = true
                    }
                }) {
                    HStack {
                        Text("Voir plus")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppColors.primary)
                }
                .padding(.top, 4)
            }
            
            if showFullExplanation {
                Text(longExplanation)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                    .padding(.top, 8)
                
                Button(action: {
                    withAnimation {
                        showFullExplanation = false
                    }
                }) {
                    HStack {
                        Text("Voir moins")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppColors.primary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.08))
        )
    }
    
    private var shortExplanation: String {
        switch advice.status {
        case .optimal:
            return "Ton Edge Score est optimal ! Toutes les conditions sont réunies pour trader avec confiance. Discipline élevée, charge émotionnelle faible, et contexte technique favorable."
        case .neutral:
            return "Ton Edge Score est neutre. Les conditions sont acceptables mais pas idéales. Sois sélectif et trade uniquement tes meilleurs setups."
        case .avoid:
            return "Ton Edge Score est faible. Les conditions actuelles ne sont pas favorables au trading. Une pause ou une extrême prudence est recommandée."
        }
    }
    
    private var longExplanation: String {
        // Génération d'une explication plus détaillée basée sur les facteurs
        var parts: [String] = []
        
        if !advice.positiveFactors.isEmpty {
            parts.append("Points forts : \(advice.positiveFactors.prefix(2).joined(separator: ", ")).")
        }
        
        if !advice.negativeFactors.isEmpty {
            parts.append("Points de vigilance : \(advice.negativeFactors.prefix(2).joined(separator: ", ")).")
        }
        
        parts.append("Action recommandée : \(advice.primaryAction)")
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Helpers
    
    private func statusDescription(for status: AdviceStatus) -> String {
        switch status {
        case .optimal:
            return "Conditions idéales pour trader"
        case .neutral:
            return "Conditions acceptables, sois sélectif"
        case .avoid:
            return "Conditions défavorables, pause recommandée"
        }
    }
}

// MARK: - Preview

#Preview {
    ScoreDetailSheet(
        advice: TradingAdviceSummary(
            edgeScore: 75,
            status: .optimal,
            primaryAction: "Trade tes meilleurs setups avec confiance",
            optimalWindow: "14h-18h",
            focus: "Cassures de résistances majeures",
            positiveFactors: ["Discipline élevée (85%)", "Série de 3 gains consécutifs", "Volume fort"],
            negativeFactors: ["Volatilité élevée"],
            streakAnalysis: nil
        ),
        instrumentType: .crypto
    )
}
