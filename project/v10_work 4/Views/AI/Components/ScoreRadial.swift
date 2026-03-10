//
//  ScoreRadial.swift
//  Journal de trading 2025
//
//  Composant de score radial compact avec animation

import SwiftUI

struct ScoreRadial: View {
    let score: Int // 0-10
    let maxScore: Int = 10
    let size: CGFloat
    let lineWidth: CGFloat
    let showLabel: Bool
    let onTap: (() -> Void)?
    
    @State private var animatedProgress: Double = 0
    
    init(
        score: Int,
        size: CGFloat = 84,
        lineWidth: CGFloat = 6,
        showLabel: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.score = min(max(score, 0), 10)
        self.size = size
        self.lineWidth = lineWidth
        self.showLabel = showLabel
        self.onTap = onTap
    }
    
    private var progress: Double {
        Double(score) / Double(maxScore)
    }
    
    private var scoreColor: Color {
        switch score {
        case 0...3:
            return Color(hex: "#FF3B30") // Rouge
        case 4...6:
            return Color(hex: "#FF9F0A") // Orange
        case 7...8:
            return Color(hex: "#4CD964") // Vert clair
        case 9...10:
            return Color(hex: "#34C759") // Vert foncé
        default:
            return .gray
        }
    }
    
    private var statusLabel: String {
        switch score {
        case 0...3:
            return "FAIBLE"
        case 4...6:
            return "NEUTRE"
        case 7...8:
            return "SOLIDE"
        case 9...10:
            return "OPTIMAL"
        default:
            return "—"
        }
    }
    
    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            onTap?()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            scoreColor.opacity(0.15),
                            lineWidth: lineWidth
                        )
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: animatedProgress)
                    
                    // Glow effect
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            scoreColor.opacity(0.3),
                            style: StrokeStyle(
                                lineWidth: lineWidth + 2,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .blur(radius: 4)
                        .opacity(0.6)
                    
                    // Score text
                    VStack(spacing: 0) {
                        Text("\(score)")
                            .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                        
                        Text("/\(maxScore)")
                            .font(.system(size: size * 0.15, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .offset(y: -2)
                    }
                }
                .frame(width: size, height: size)
                
                // Label optionnel
                if showLabel {
                    Text(statusLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(scoreColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(scoreColor.opacity(0.15))
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44) // Zone tactile min
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animatedProgress = progress
            }
        }
        .onChange(of: score) { _, _ in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        HStack(spacing: 30) {
            ScoreRadial(score: 2, showLabel: true, onTap: {
                print("Score tapped")
            })
            
            ScoreRadial(score: 5, showLabel: true)
            
            ScoreRadial(score: 7, showLabel: true)
            
            ScoreRadial(score: 10, showLabel: true)
        }
        
        HStack(spacing: 30) {
            ScoreRadial(score: 3, size: 72, lineWidth: 5, showLabel: false)
            ScoreRadial(score: 6, size: 72, lineWidth: 5, showLabel: false)
            ScoreRadial(score: 9, size: 72, lineWidth: 5, showLabel: false)
        }
    }
    .padding()
    .background(AppColors.background)
}
