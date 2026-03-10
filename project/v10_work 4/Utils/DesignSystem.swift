//
//  DesignSystem.swift
//  Journal de trading 2025
//

import SwiftUI

// MARK: - Design System Colors
struct AppColors {
    // Primary Colors
    static let primary = Color(red: 0.04, green: 0.52, blue: 1.0) // #0A85FF
    static let primaryDark = Color(red: 0.05, green: 0.45, blue: 0.9)
    static let primaryLight = Color(red: 0.2, green: 0.6, blue: 1.0)
    
    // Secondary Colors
    static let secondary = Color(red: 0.2, green: 0.78, blue: 0.37) // #22C759
    static let secondaryDark = Color(red: 0.15, green: 0.7, blue: 0.32)
    static let secondaryLight = Color(red: 0.3, green: 0.85, blue: 0.45)
    
    // Accent Colors
    static let accent = Color(red: 0.75, green: 0.35, blue: 0.95) // #BF5AF2
    static let accentDark = Color(red: 0.65, green: 0.28, blue: 0.85)
    static let accentLight = Color(red: 0.85, green: 0.45, blue: 0.98)
    
    // Semantic Colors
    static let success = Color(red: 0.2, green: 0.78, blue: 0.37) // #22C759
    static let warning = Color(red: 1.0, green: 0.58, blue: 0.0) // #FF9500
    static let error = Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
    static let info = Color(red: 0.0, green: 0.48, blue: 1.0) // #007AFF
    
    // Neutral Colors
    static let background = Color(red: 0.07, green: 0.09, blue: 0.15) // #121226
    static let cardBackground = Color(red: 0.11, green: 0.13, blue: 0.2) // #1C2133
    static let border = Color(red: 0.24, green: 0.26, blue: 0.33) // #3D4254
    static let textPrimary = Color(red: 1.0, green: 1.0, blue: 1.0) // #FFFFFF
    static let textSecondary = Color(red: 0.56, green: 0.58, blue: 0.64) // #8F94A3
    static let textTertiary = Color(red: 0.4, green: 0.42, blue: 0.48) // #666B7A
    
    // Chart Colors
    static let profit = success
    static let loss = error
    static let neutral = textSecondary
}

// MARK: - Typography
struct AppTypography {
    // Display
    static let displayLarge = Font.system(size: 57, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 45, weight: .bold, design: .default)
    static let displaySmall = Font.system(size: 36, weight: .semibold, design: .default)
    
    // Headline
    static let headlineLarge = Font.system(size: 32, weight: .semibold, design: .default)
    static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .default)
    
    // Title
    static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
    static let titleMedium = Font.system(size: 18, weight: .medium, design: .default)
    static let titleSmall = Font.system(size: 16, weight: .medium, design: .default)
    
    // Body
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
    
    // Label
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 12, weight: .medium, design: .default)
    
    // Caption
    static let captionLarge = Font.system(size: 12, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 11, weight: .regular, design: .default)
    static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)
}

// MARK: - Spacing
struct AppSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius
struct AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 24
}

// MARK: - Shadows
struct AppShadow {
    static let small = Color.black.opacity(0.05)
    static let medium = Color.black.opacity(0.08)
    static let large = Color.black.opacity(0.12)
    
    static let smallRadius: CGFloat = 4
    static let mediumRadius: CGFloat = 8
    static let largeRadius: CGFloat = 16
}

// MARK: - Animations
struct AppAnimations {
    static let quick = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.8)
    static let standard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let relaxed = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
}

// MARK: - Gradients
struct AppGradients {
    static let primary = LinearGradient(
        colors: [AppColors.primary, AppColors.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let success = LinearGradient(
        colors: [AppColors.success, AppColors.success.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let card = LinearGradient(
        colors: [AppColors.cardBackground, AppColors.cardBackground.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let overlay = LinearGradient(
        colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Common Components
struct AppButtonStyle: ButtonStyle {
    var variant: ButtonVariant = .primary
    var size: ButtonSize = .medium
    
    enum ButtonVariant {
        case primary, secondary, outline, ghost, danger
    }
    
    enum ButtonSize {
        case small, medium, large
        
        var padding: (vertical: CGFloat, horizontal: CGFloat) {
            switch self {
            case .small: return (8, 16)
            case .medium: return (12, 24)
            case .large: return (16, 32)
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return AppTypography.labelSmall
            case .medium: return AppTypography.labelMedium
            case .large: return AppTypography.labelLarge
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.fontSize)
            .fontWeight(.semibold)
            .foregroundColor(foregroundColor)
            .padding(.vertical, size.padding.vertical)
            .padding(.horizontal, size.padding.horizontal)
            .frame(maxWidth: size == .large ? .infinity : nil)
            .background(backgroundColor)
            .overlay(borderOverlay)
            .cornerRadius(AppRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppAnimations.quick, value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return AppColors.textPrimary
        case .outline: return AppColors.primary
        case .ghost: return AppColors.primary
        case .danger: return .white
        }
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .primary: return AppColors.primary
        case .secondary: return AppColors.cardBackground
        case .outline: return Color.clear
        case .ghost: return Color.clear
        case .danger: return AppColors.error
        }
    }
    
    private var borderOverlay: some View {
        Group {
            if variant == .outline {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.primary, lineWidth: 1.5)
            }
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static func appButton(variant: AppButtonStyle.ButtonVariant = .primary, size: AppButtonStyle.ButtonSize = .medium) -> AppButtonStyle {
        AppButtonStyle(variant: variant, size: size)
    }
}

// MARK: - Card Style
struct AppCardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.md
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColors.cardBackground)
            .cornerRadius(AppRadius.large)
            .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)
    }
}

extension View {
    func appCard(padding: CGFloat = AppSpacing.md) -> some View {
        modifier(AppCardStyle(padding: padding))
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}




