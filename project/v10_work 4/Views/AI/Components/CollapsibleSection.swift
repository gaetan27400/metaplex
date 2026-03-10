//
//  CollapsibleSection.swift
//  Journal de trading 2025
//
//  Section collapsible avec preview et contenu complet

import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    let preview: String
    let content: Content
    
    @State private var isExpanded: Bool = false
    
    init(
        title: String,
        icon: String,
        accentColor: Color,
        preview: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.preview = preview
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Always visible
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
                HapticFeedback.selection()
            }) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                        .frame(width: 28)
                    
                    // Title
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Preview - Visible when collapsed
            if !isExpanded && !preview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(4)
                        .lineLimit(3)
                    
                    Text("Tap pour voir plus →")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(accentColor.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.05))
                )
                .padding(.top, 8)
            }
            
            // Content - Visible when expanded
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.05))
                )
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        CollapsibleSection(
            title: "Analyse Technique",
            icon: "chart.xyaxis.line",
            accentColor: .cyan,
            preview: "Support majeur à 66500 • Résistance clé à 68200 • RSI neutre sur H4"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                technicalRow(label: "Support 1", value: "66,500", color: .green)
                technicalRow(label: "Support 2", value: "65,800", color: .green)
                technicalRow(label: "Résistance 1", value: "68,200", color: .red)
                technicalRow(label: "Résistance 2", value: "69,000", color: .red)
                
                Divider()
                    .background(Color.cyan.opacity(0.3))
                
                Text("Tendance actuelle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Le prix évolue dans un range entre 66500 et 68200. Une cassure de l'une de ces bornes déterminera la direction.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }
        }
        
        CollapsibleSection(
            title: "Informations Importantes",
            icon: "exclamationmark.triangle.fill",
            accentColor: .orange,
            preview: "Annonce FOMC dans 2h • Volume élevé détecté • Volatilité en hausse"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(
                    icon: "calendar",
                    color: .orange,
                    title: "Annonce FOMC",
                    description: "Dans 2 heures - Impact attendu : Élevé"
                )
                
                infoRow(
                    icon: "chart.bar.fill",
                    color: .blue,
                    title: "Volume inhabituel",
                    description: "Volume 1.8x supérieur à la moyenne 24h"
                )
                
                infoRow(
                    icon: "waveform.path.ecg",
                    color: .red,
                    title: "Volatilité élevée",
                    description: "ATR en hausse de 35% sur les 4 dernières heures"
                )
            }
        }
        
        Spacer()
    }
    .padding()
    .background(AppColors.background)
}

// MARK: - Preview Helpers

private func technicalRow(label: String, value: String, color: Color) -> some View {
    HStack {
        Text(label)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
        Spacer()
        Text(value)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(color)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
        RoundedRectangle(cornerRadius: 8)
            .fill(AppColors.background.opacity(0.5))
    )
}

private func infoRow(icon: String, color: Color, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(color)
            .frame(width: 24)
        
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
        }
    }
    .padding(12)
    .background(
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.08))
    )
}
