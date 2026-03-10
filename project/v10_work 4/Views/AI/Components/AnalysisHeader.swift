//
//  AnalysisHeader.swift
//  Journal de trading 2025
//
//  Header compact pour l'écran Analyse IA

import SwiftUI

struct AnalysisHeader: View {
    let symbol: String
    let score: Int // 0-10 (converti depuis EdgeScore/100)
    let bullProbability: Double // 0-1
    let lastUpdate: Date?
    let onScoreTap: () -> Void
    let onProbabilityTap: (() -> Void)?
    
    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }
    
    private var timeAgo: String {
        guard let lastUpdate = lastUpdate else { return "" }
        return relativeFormatter.localizedString(for: lastUpdate, relativeTo: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: Title + Update time
            VStack(alignment: .leading, spacing: 4) {
                Text("Analyse IA")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.primary)
                
                if !timeAgo.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("Mis à jour \(timeAgo)")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Spacer(minLength: 8)
            
            // Right: Score Radial + Probability
            HStack(spacing: 16) {
                // Score Radial
                ScoreRadial(
                    score: score,
                    size: 72,
                    lineWidth: 6,
                    showLabel: false,
                    onTap: onScoreTap
                )
                
                // Probability
                probabilityIndicator
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#933CFF").opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var probabilityIndicator: some View {
        let bullPercent = Int(bullProbability * 100)
        let bearPercent = 100 - bullPercent
        
        Button(action: {
            HapticFeedback.selection()
            onProbabilityTap?()
        }) {
            VStack(spacing: 6) {
                // Bull probability
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("\(bullPercent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                // Separator
                Rectangle()
                    .fill(AppColors.border.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: 40)
                
                // Bear probability
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("\(bearPercent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.background.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Probability Detail Sheet

struct ProbabilityDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let bullProbability: Double
    let bearProbability: Double
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Visual representation
                VStack(spacing: 16) {
                    // Bull bar
                    probabilityBar(
                        label: "Scénario Haussier",
                        probability: bullProbability,
                        color: .green,
                        icon: "arrow.up.right"
                    )
                    
                    // Bear bar
                    probabilityBar(
                        label: "Scénario Baissier",
                        probability: bearProbability,
                        color: .red,
                        icon: "arrow.down.right"
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardBackground)
                )
                
                // Explanation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.cyan)
                        Text("Comment est calculée la probabilité ?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    Text("La probabilité est calculée en analysant plusieurs facteurs techniques et contextuels : indicateurs MTF (RSI, VMC), biais de tendance, momentum, et confluence multi-timeframes.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cyan.opacity(0.08))
                )
                
                Spacer()
            }
            .padding()
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Probabilités")
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
    
    private func probabilityBar(label: String, probability: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(Int(probability * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .frame(height: 12)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * probability, height: 12)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AnalysisHeader(
            symbol: "BTCUSDT",
            score: 7,
            bullProbability: 0.65,
            lastUpdate: Date().addingTimeInterval(-300),
            onScoreTap: {
                print("Score tapped")
            },
            onProbabilityTap: {
                print("Probability tapped")
            }
        )
        
        AnalysisHeader(
            symbol: "ETHUSDT",
            score: 4,
            bullProbability: 0.42,
            lastUpdate: Date().addingTimeInterval(-3600),
            onScoreTap: {},
            onProbabilityTap: nil
        )
        
        Spacer()
    }
    .padding()
    .background(AppColors.background)
}
