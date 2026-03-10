import SwiftUI

enum HeatmapMode: CaseIterable, Identifiable {
    case pnl
    case emotional
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .pnl: return "P&L"
        case .emotional: return "Charge émotionnelle"
        }
    }
}

struct UnifiedHeatmapBlock: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @ObservedObject var cache: DashboardAnalyticsCache
    let onOpenDetails: (() -> Void)?
    @State private var mode: HeatmapMode = .pnl
    @State private var period: DashboardHeatmapPeriod = .month
    @State private var selectedCell: DashboardHeatmapCell?
    @State private var previewCell: DashboardHeatmapCell?
    
    private let daysOfWeek = ["D", "L", "M", "M", "J", "V", "S"]
    
    init(cache: DashboardAnalyticsCache, onOpenDetails: (() -> Void)? = nil) {
        self.cache = cache
        self.onOpenDetails = onOpenDetails
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            grid
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.18), value: mode)
        .animation(.easeInOut(duration: 0.18), value: period)
        .sheet(item: $selectedCell) { cell in
            DashboardHeatmapCellDetailsSheet(
                cell: cell,
                title: mode == .pnl ? "Détails (P&L)" : "Détails (charge émotionnelle)"
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("heatmap"))
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    Text(mode == .pnl ? "Résultat (P&L)" : "Contexte (pression)")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                
                Menu {
                    ForEach(HeatmapMode.allCases) { m in
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.easeInOut(duration: 0.18)) {
                                mode = m
                            }
                        } label: {
                            if mode == m {
                                Label(m.title, systemImage: "checkmark")
                            } else {
                                Text(m.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(mode.title)
                            .font(AppTypography.captionMedium.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppColors.cardBackground.opacity(0.9))
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .accessibilityLabel("Mode heatmap")
                .accessibilityValue(mode.title)
                
                if let onOpenDetails {
                    Button {
                        HapticFeedback.selection()
                        onOpenDetails()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppColors.cardBackground.opacity(0.9))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                                    )
                            )
                    }
                    .accessibilityLabel("Ouvrir en plein écran")
                }
            }
            
            Picker("Période", selection: $period) {
                ForEach(DashboardHeatmapPeriod.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: period) { _, _ in
                HapticFeedback.selection()
            }
            .accessibilityLabel("Période heatmap")
            .accessibilityValue(period.displayName)
        }
    }
    
    private var grid: some View {
        let grid: [[DashboardHeatmapCell]] = {
            switch mode {
            case .pnl:
                return cache.pnlHeatmapByPeriod[period] ?? []
            case .emotional:
                return cache.emotionalHeatmapByPeriod[period] ?? []
            }
        }()
        
        return VStack(spacing: 10) {
            if let previewCell {
                quickPreview(previewCell)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            HStack(spacing: 6) {
                Text("")
                    .frame(width: 18)
                ForEach(daysOfWeek, id: \.self) { d in
                    Text(d)
                        .font(AppTypography.captionSmall.weight(.bold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            ForEach(0..<grid.count, id: \.self) { rowIdx in
                HStack(spacing: 6) {
                    Text("")
                        .frame(width: 18)
                    ForEach(grid[rowIdx]) { cell in
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedCell = cell
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                let adjustedOpacity = adjustedFillOpacity(for: cell)
                                let adjustedStrokeOpacity = adjustedStrokeOpacity(for: cell)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: cell.fillHex).opacity(adjustedOpacity))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(adjustedStrokeOpacity), lineWidth: 1)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(AppColors.primary.opacity(isSelected(cell) ? 0.75 : 0.0), lineWidth: isSelected(cell) ? 2 : 0)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(cell.isCurrentWeek ? 0.18 : 0.0), lineWidth: cell.isCurrentWeek ? 1 : 0)
                                    )
                                
                                if cell.isBest {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppColors.success.opacity(0.95))
                                        .padding(2)
                                } else if cell.isWorst {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppColors.error.opacity(0.95))
                                        .padding(2)
                                }
                            }
                            .frame(height: grid.count > 13 ? 12 : 18)
                            .scaleEffect(isSelected(cell) ? 1.06 : 1.0)
                            .animation(.easeInOut(duration: 0.16), value: selectedCell?.id)
                        }
                        .buttonStyle(.plain)
                        .onLongPressGesture(minimumDuration: 0.35) {
                            HapticFeedback.selection()
                            withAnimation(.easeInOut(duration: 0.18)) {
                                previewCell = cell
                            }
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 1_400_000_000)
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    if previewCell?.id == cell.id {
                                        previewCell = nil
                                    }
                                }
                            }
                        }
                        .accessibilityLabel(cell.accessibilityLabel)
                    }
                }
            }
            
            if mode == .emotional {
                emotionalLegend
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(mode == .pnl ? "Heatmap P&L : le résultat." : "Heatmap charge émotionnelle : le contexte.")
    }
    
    private func adjustedFillOpacity(for cell: DashboardHeatmapCell) -> Double {
        guard mode == .emotional else { return cell.fillOpacity }
        let v = cell.value
        if v >= 80 { return min(1.0, cell.fillOpacity + 0.12) }
        if v >= 60 { return min(1.0, cell.fillOpacity + 0.08) }
        return cell.fillOpacity
    }
    
    private func adjustedStrokeOpacity(for cell: DashboardHeatmapCell) -> Double {
        guard mode == .emotional else { return cell.strokeOpacity }
        let v = cell.value
        if v >= 80 { return max(cell.strokeOpacity, 0.22) }
        if v >= 60 { return max(cell.strokeOpacity, 0.14) }
        return cell.strokeOpacity
    }
    
    private var emotionalLegend: some View {
        HStack(spacing: AppSpacing.sm) {
            legendPill(colorHex: "#5EEAD4", text: "Très calme")
            legendPill(colorHex: "#14B8A6", text: "Calme")
            legendPill(colorHex: "#38BDF8", text: "Vigilance")
            legendPill(colorHex: "#FACC15", text: "Attention")
            legendPill(colorHex: "#FB923C", text: "Tension")
            legendPill(colorHex: "#F87171", text: "Danger")
            Spacer(minLength: 0)
        }
        .font(AppTypography.captionSmall.weight(.semibold))
        .foregroundColor(AppColors.textSecondary)
    }
    
    private func legendPill(colorHex: String, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.9))
                .frame(width: 8, height: 8)
            Text(text)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppColors.cardBackground.opacity(0.7))
                .overlay(
                    Capsule()
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func isSelected(_ cell: DashboardHeatmapCell) -> Bool {
        selectedCell?.id == cell.id
    }
    
    private func quickPreview(_ cell: DashboardHeatmapCell) -> some View {
        HStack(spacing: AppSpacing.md) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: cell.fillHex).opacity(min(1.0, cell.fillOpacity + 0.15)))
                .frame(width: 34, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(cell.title)
                    .font(AppTypography.captionMedium.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(t("tuesday"))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            Text(t("aperu"))
                .font(AppTypography.captionSmall.weight(.bold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(AppColors.border.opacity(0.20), lineWidth: 1)
                )
        )
    }
}


