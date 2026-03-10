import SwiftUI
import Charts

/// Courbe "Charge émotionnelle" (0..100) — lissée — sans jugement.
struct EmotionalLoadChartView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedPoint: Point?
    
    private var calendar: Calendar { .current }
    
    private struct Point: Identifiable {
        let id = UUID()
        let day: Date
        let load: Double
        let loadSmoothed: Double
    }
    
    private var points: [Point] {
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
        
        // EMA simple pour lisser (UX)
        let alpha = 0.25
        var ema: Double = raw.first?.load ?? 0
        var out: [Point] = []
        out.reserveCapacity(raw.count)
        for p in raw {
            ema = alpha * p.load + (1 - alpha) * ema
            out.append(Point(day: p.day, load: p.load, loadSmoothed: ema))
        }
        return out
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    
                    if points.isEmpty {
                        emptyState
                    } else {
                        chart
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
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("pressionmotionnelle0100"))
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            Text(t("lissePourRvlerLaTendanceSansJugement"))
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
    
    private var chart: some View {
        let maxY = 100.0
        return Chart {
            ForEach(points) { p in
                LineMark(
                    x: .value("Jour", p.day, unit: .day),
                    y: .value("Charge (EMA)", p.loadSmoothed)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppColors.accent)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                if let selectedPoint, selectedPoint.id == p.id {
                    PointMark(
                        x: .value("Jour", p.day, unit: .day),
                        y: .value("Charge (EMA)", p.loadSmoothed)
                    )
                    .symbolSize(130)
                    .foregroundStyle(AppColors.accent)
                }
            }
            
            RuleMark(y: .value("Max", 75))
                .lineStyle(.init(lineWidth: 1, dash: [4]))
                .foregroundStyle(AppColors.textSecondary.opacity(0.20))
        }
        .chartYScale(domain: 0...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(AppColors.border.opacity(0.10))
                AxisValueLabel(format: .dateTime.month().day())
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine().foregroundStyle(AppColors.border.opacity(0.10))
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
                                let closest = points.min(by: { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) })
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
        .frame(height: 260)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "heart.slash")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textSecondary.opacity(0.8))
            Text(t("pasEncoreAssezDentresAftertradePourCalculerLaCharge"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
    
    private enum Timeframe: CaseIterable {
        case week, month, threeMonths, sixMonths, year, all
        
        var title: String {
            switch self {
            case .week: return "7j"
            case .month: return "30j"
            case .threeMonths: return "3m"
            case .sixMonths: return "6m"
            case .year: return "1a"
            case .all: return "All"
            }
        }
    }
}


