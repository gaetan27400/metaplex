//
//  EmotionalChartView.swift
//  Journal de trading 2025
//
//  Graphique de la charge émotionnelle avec zones visuelles distinctes
//  Solution au problème des labels textuels sur axe numérique
//

import SwiftUI
import Charts

/// Vue principale : Graphique de charge émotionnelle avec zones de couleur (Version Standalone)
struct StandaloneEmotionalChartView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedPoint: EmotionalDataPoint?
    
    private var calendar: Calendar { .current }
    
    private struct EmotionalDataPoint: Identifiable {
        let id = UUID()
        let day: Date
        let rawLoad: Double
        let smoothedLoad: Double
    }
    
    // ✅ Définition des zones émotionnelles (séparation claire)
    private enum EmotionalZone: CaseIterable {
        case calm       // 0-30
        case attention  // 30-60
        case tension    // 60-80
        case danger     // 80-100
        
        var range: ClosedRange<Double> {
            switch self {
            case .calm: return 0...30
            case .attention: return 30...60
            case .tension: return 60...80
            case .danger: return 80...100
            }
        }
        
        var label: String {
            switch self {
            case .calm: return "Calme"
            case .attention: return "Attention"
            case .tension: return "Tension"
            case .danger: return "Danger"
            }
        }
        
        var color: Color {
            switch self {
            case .calm: return Color(hex: "#10B981") // Green
            case .attention: return Color(hex: "#F59E0B") // Amber
            case .tension: return Color(hex: "#F97316") // Orange
            case .danger: return Color(hex: "#EF4444") // Red
            }
        }
        
        var midpoint: Double {
            (range.lowerBound + range.upperBound) / 2
        }
    }
    
    private var dataPoints: [EmotionalDataPoint] {
        let days = appState.emotionalLoadByDay.keys.sorted()
        guard !days.isEmpty else { return [] }
        
        let filteredDays = days.filter { day in
            switch selectedTimeframe {
            case .week:
                let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return day >= calendar.startOfDay(for: start)
            case .month:
                let start = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                return day >= calendar.startOfDay(for: start)
            case .threeMonths:
                let start = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                return day >= calendar.startOfDay(for: start)
            case .sixMonths:
                let start = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                return day >= calendar.startOfDay(for: start)
            case .year:
                let start = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                return day >= calendar.startOfDay(for: start)
            case .all:
                return true
            }
        }
        
        let raw = filteredDays.map { (day: $0, load: appState.emotionalLoadByDay[$0] ?? 0) }
            .sorted { $0.day < $1.day }
        
        // EMA (lissage) pour une courbe plus lisible
        let alpha = 0.25
        var ema: Double = raw.first?.load ?? 0
        var out: [EmotionalDataPoint] = []
        out.reserveCapacity(raw.count)
        for p in raw {
            ema = alpha * p.load + (1 - alpha) * ema
            out.append(EmotionalDataPoint(day: p.day, rawLoad: p.load, smoothedLoad: ema))
        }
        return out
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    
                    if dataPoints.isEmpty {
                        emptyState
                    } else {
                        chartSection
                        legendSection
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("emotionalLoad"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("pressionmotionnelle0100"))
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            Text(t("zonesDeVigilanceAvecLissagePourRvlerLesTendances"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Timeframe.allCases, id: \.self) { tf in
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.3)) { selectedTimeframe = tf }
                        } label: {
                            Text(tf.title)
                                .font(AppTypography.labelMedium)
                                .foregroundColor(selectedTimeframe == tf ? .white : AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    Capsule()
                                        .fill(selectedTimeframe == tf ? AppColors.primary : AppColors.cardBackground)
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Chart {
                // ✅ 1. Arrière-plan : zones émotionnelles colorées
                ForEach(EmotionalZone.allCases, id: \.label) { zone in
                    RectangleMark(
                        yStart: .value("Min", zone.range.lowerBound),
                        yEnd: .value("Max", zone.range.upperBound)
                    )
                    .foregroundStyle(zone.color.opacity(0.08))
                }
                
                // ✅ 2. Ligne de charge lissée (signal principal)
                ForEach(dataPoints) { point in
                    LineMark(
                        x: .value("Jour", point.day, unit: .day),
                        y: .value("Charge", point.smoothedLoad)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent, AppColors.accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                
                // ✅ 3. Area sous la courbe pour renforcer la lecture
                ForEach(dataPoints) { point in
                    AreaMark(
                        x: .value("Jour", point.day, unit: .day),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Charge", point.smoothedLoad)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                // ✅ 4. Point sélectionné (interaction)
                if let selected = selectedPoint {
                    // Ligne verticale
                    RuleMark(x: .value("Date", selected.day, unit: .day))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(AppColors.primary.opacity(0.4))
                    
                    // Halo
                    PointMark(
                        x: .value("Jour", selected.day, unit: .day),
                        y: .value("Charge", selected.smoothedLoad)
                    )
                    .symbolSize(220)
                    .foregroundStyle(AppColors.primary.opacity(0.15))
                    
                    // Point principal
                    PointMark(
                        x: .value("Jour", selected.day, unit: .day),
                        y: .value("Charge", selected.smoothedLoad)
                    )
                    .symbolSize(140)
                    .foregroundStyle(AppColors.primary)
                    .annotation(position: .top, alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selected.day.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(.white.opacity(0.9))
                            Text("Charge: \(Int(selected.smoothedLoad))")
                                .font(AppTypography.labelMedium)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(zoneLabel(for: selected.smoothedLoad))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(zoneColor(for: selected.smoothedLoad))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.75))
                        )
                    }
                }
                
                // ✅ 5. Lignes de séparation des zones (discrètes)
                RuleMark(y: .value("Zone", 30))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(AppColors.border.opacity(0.3))
                
                RuleMark(y: .value("Zone", 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(AppColors.border.opacity(0.3))
                
                RuleMark(y: .value("Zone", 80))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(AppColors.border.opacity(0.3))
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(AppColors.border.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(AppTypography.captionSmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .chartYAxis {
                // ✅ SOLUTION : Axe Y numérique propre (0, 25, 50, 75, 100)
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine().foregroundStyle(AppColors.border.opacity(0.1))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(AppTypography.captionSmall)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geo.frame(in: .local).minX
                                    guard let date: Date = proxy.value(atX: x) else { return }
                                    let closest = dataPoints.min(by: {
                                        abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date))
                                    })
                                    if let c = closest {
                                        HapticFeedback.selection()
                                        withAnimation(.easeInOut(duration: 0.15)) { selectedPoint = c }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) { selectedPoint = nil }
                                }
                        )
                }
            }
            .frame(height: 320)
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xlarge)
                    .fill(AppColors.cardBackground.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.xlarge)
                            .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)
        }
    }
    
    // MARK: - Legend Section
    
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("zonesDeVigilance"))
                .font(AppTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.sm) {
                ForEach(EmotionalZone.allCases, id: \.label) { zone in
                    HStack(spacing: AppSpacing.xs) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(zone.color)
                            .frame(width: 24, height: 16)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.label)
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            Text("\(Int(zone.range.lowerBound))–\(Int(zone.range.upperBound))")
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(zone.color.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(zone.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "heart.slash")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textSecondary.opacity(0.8))
            Text(t("pasEncoreDeDonnesmotionnelles"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
    
    // MARK: - Helpers
    
    private func zoneLabel(for value: Double) -> String {
        EmotionalZone.allCases.first { $0.range.contains(value) }?.label ?? "Neutre"
    }
    
    private func zoneColor(for value: Double) -> Color {
        EmotionalZone.allCases.first { $0.range.contains(value) }?.color ?? AppColors.textSecondary
    }
    
    // MARK: - Supporting Types
    
    private enum Timeframe: CaseIterable {
        case week, month, threeMonths, sixMonths, year, all
        
        var title: String {
            switch self {
            case .week: return "7j"
            case .month: return "30j"
            case .threeMonths: return "3m"
            case .sixMonths: return "6m"
            case .year: return "1a"
            case .all: return "Tout"
            }
        }
    }
}
