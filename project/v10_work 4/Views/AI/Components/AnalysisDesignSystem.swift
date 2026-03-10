//
//  AnalysisDesignSystem.swift
//  Journal de trading 2025
//
//  Design system spécifique pour l'écran Analyse IA

import SwiftUI

// MARK: - Analysis Design Tokens

enum AnalysisDesign {
    // MARK: - Spacing (Grid 8px)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Corner Radius
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
    }
    
    // MARK: - Typography
    enum Typography {
        // Headers
        static let headerTitle = Font.system(size: 16, weight: .semibold)
        static let headerSubtitle = Font.system(size: 14, weight: .medium)
        static let headerTime = Font.system(size: 10, weight: .regular)
        
        // Card Titles
        static let cardTitle = Font.system(size: 16, weight: .semibold)
        static let cardSubtitle = Font.system(size: 12, weight: .medium)
        
        // Body Text
        static let bodyLarge = Font.system(size: 16, weight: .medium)
        static let bodyRegular = Font.system(size: 14, weight: .regular)
        static let bodySmall = Font.system(size: 13, weight: .regular)
        
        // Labels
        static let labelLarge = Font.system(size: 14, weight: .semibold)
        static let labelMedium = Font.system(size: 13, weight: .medium)
        static let labelSmall = Font.system(size: 12, weight: .medium)
        
        // Values (monospaced pour prix)
        static let valueLarge = Font.system(size: 18, weight: .bold, design: .monospaced)
        static let valueMedium = Font.system(size: 16, weight: .bold, design: .monospaced)
        static let valueSmall = Font.system(size: 14, weight: .semibold, design: .monospaced)
        
        // Scores
        static let scoreHuge = Font.system(size: 48, weight: .bold, design: .rounded)
        static let scoreLarge = Font.system(size: 36, weight: .bold, design: .rounded)
        static let scoreMedium = Font.system(size: 24, weight: .bold, design: .rounded)
        static let scoreSmall = Font.system(size: 18, weight: .bold, design: .rounded)
        
        // Captions
        static let captionMedium = Font.system(size: 12, weight: .medium)
        static let captionSmall = Font.system(size: 11, weight: .regular)
        static let captionTiny = Font.system(size: 10, weight: .regular)
    }
    
    // MARK: - Colors
    enum Colors {
        // Backgrounds
        static let background = AppColors.background
        static let cardBackground = AppColors.cardBackground
        static let overlayBackground = Color.black.opacity(0.3)
        
        // Text
        static let textPrimary = AppColors.textPrimary
        static let textSecondary = AppColors.textSecondary
        static let textTertiary = AppColors.textTertiary
        
        // Semantic Colors
        static let success = Color(hex: "#4CD964")
        static let error = Color(hex: "#FF3B30")
        static let warning = Color(hex: "#FF9F0A")
        static let info = Color(hex: "#00D9FF")
        
        // Score Colors
        static let scoreRed = Color(hex: "#FF3B30")      // 0-3
        static let scoreOrange = Color(hex: "#FF9F0A")   // 4-6
        static let scoreGreenLight = Color(hex: "#4CD964") // 7-8
        static let scoreGreenDark = Color(hex: "#34C759")  // 9-10
        
        // Accent (Analysis tab)
        static let analysisPrimary = Color(hex: "#933CFF")
        static let analysisSecondary = Color(hex: "#5A3BFF")
        
        // Border
        static let border = Color.white.opacity(0.1)
        static let borderAccent = Color(hex: "#933CFF").opacity(0.3)
        
        // Divider
        static let divider = Color.white.opacity(0.2)
    }
    
    // MARK: - Shadows
    enum Shadow {
        static let small = {
            return Color.black.opacity(0.1)
        }
        
        static let medium = {
            return Color.black.opacity(0.15)
        }
        
        static let large = {
            return Color.black.opacity(0.2)
        }
    }
    
    // MARK: - Touch Targets
    enum TouchTarget {
        static let minimum: CGFloat = 44 // iOS HIG minimum
        static let comfortable: CGFloat = 48
    }
    
    // MARK: - Card Heights
    enum CardHeight {
        static let header: CGFloat = 90
        static let scenarioMinimum: CGFloat = 240
        static let scenarioComfortable: CGFloat = 260
    }
}

// MARK: - Reusable Card Styles

struct AnalysisCardStyle: ViewModifier {
    let accentColor: Color?
    let hasBorder: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AnalysisDesign.Radius.large)
                    .fill(AnalysisDesign.Colors.cardBackground)
            )
            .overlay(
                Group {
                    if hasBorder, let accent = accentColor {
                        RoundedRectangle(cornerRadius: AnalysisDesign.Radius.large)
                            .stroke(accent.opacity(0.3), lineWidth: 1)
                    }
                }
            )
    }
}

extension View {
    func analysisCardStyle(accentColor: Color? = nil, hasBorder: Bool = true) -> some View {
        self.modifier(AnalysisCardStyle(accentColor: accentColor, hasBorder: hasBorder))
    }
}

// MARK: - Divider Styles

struct AnalysisDivider: View {
    let opacity: Double
    
    init(opacity: Double = 0.2) {
        self.opacity = opacity
    }
    
    var body: some View {
        Divider()
            .background(AnalysisDesign.Colors.divider.opacity(opacity))
    }
}

// MARK: - Data Row Component (Reusable)

struct AnalysisDataRow: View {
    let label: String
    let value: String
    let valueColor: Color
    let icon: String?
    let font: Font
    
    init(
        label: String,
        value: String,
        valueColor: Color = AnalysisDesign.Colors.textPrimary,
        icon: String? = nil,
        font: Font = AnalysisDesign.Typography.valueMedium
    ) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.icon = icon
        self.font = font
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(valueColor.opacity(0.7))
                    .frame(width: 20)
            }
            
            Text(label)
                .font(AnalysisDesign.Typography.labelMedium)
                .foregroundColor(AnalysisDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(font)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Tag Component

struct AnalysisTag: View {
    let text: String
    let color: Color
    let size: TagSize
    
    enum TagSize {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small: return AnalysisDesign.Typography.captionTiny
            case .medium: return AnalysisDesign.Typography.captionSmall
            case .large: return AnalysisDesign.Typography.captionMedium
            }
        }
        
        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small: return (6, 3)
            case .medium: return (8, 4)
            case .large: return (10, 5)
            }
        }
    }
    
    init(text: String, color: Color, size: TagSize = .medium) {
        self.text = text
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Text(text)
            .font(size.font)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, size.padding.horizontal)
            .padding(.vertical, size.padding.vertical)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Section Header Component

struct AnalysisSectionHeader: View {
    let title: String
    let icon: String
    let accentColor: Color
    let action: (() -> Void)?
    
    init(
        title: String,
        icon: String,
        accentColor: Color,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(accentColor)
                .frame(width: 28)
            
            Text(title)
                .font(AnalysisDesign.Typography.cardTitle)
                .foregroundColor(AnalysisDesign.Colors.textPrimary)
            
            Spacer()
            
            if let action = action {
                Button(action: {
                    HapticFeedback.selection()
                    action()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Card with style
        VStack(alignment: .leading, spacing: 12) {
            AnalysisSectionHeader(
                title: "Plan de Trade",
                icon: "chart.line.uptrend.xyaxis",
                accentColor: .green
            )
            
            AnalysisDataRow(
                label: "Entrée",
                value: "67,250",
                valueColor: .green,
                icon: "arrow.up.right"
            )
            
            AnalysisDivider()
            
            HStack {
                AnalysisTag(text: "CASSURE", color: .green, size: .small)
                AnalysisTag(text: "RR 2:1", color: .blue, size: .medium)
                AnalysisTag(text: "H4", color: .orange, size: .large)
            }
        }
        .padding(16)
        .analysisCardStyle(accentColor: .green)
        
        Spacer()
    }
    .padding()
    .background(AnalysisDesign.Colors.background)
}
