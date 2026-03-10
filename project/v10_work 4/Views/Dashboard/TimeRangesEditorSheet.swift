import Foundation
import SwiftUI
import Charts
import Combine

// MARK: - Time Ranges Editor Sheet
struct TimeRangesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    @Binding var ranges: [DashboardTimeRange]
    let onSave: () -> Void
    
    private enum EditorMode: String, CaseIterable, Identifiable {
        case read = "Lecture"
        case edit = "Édition"
        var id: String { rawValue }
    }
    
    @State private var mode: EditorMode = .edit
    @State private var originalRanges: [DashboardTimeRange] = []
    @State private var toast: ToastData?
    
    @State private var pendingDeleteIndex: Int?
    @State private var showDeleteConfirm: Bool = false
    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.headline)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("Mode", selection: $mode) {
                            ForEach(EditorMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
                
                if let warning = validationError, mode == .edit {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Plages") {
                    ForEach(ranges.indices, id: \.self) { index in
                        let binding = $ranges[index]
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                TextField("Nom (ex: Londres)", text: binding.name)
                                    .textInputAutocapitalization(.words)
                                    .disabled(mode == .read)
                                
                                Spacer()
                                
                                Text(ranges[index].label)
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 12) {
                                Picker("Début", selection: binding.startHour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02dh", h)).tag(h)
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(mode == .read)
                                
                                Picker("Fin", selection: binding.endHour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02dh", h)).tag(h)
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(mode == .read)
                                
                                Spacer()
                                
                                if mode == .edit {
                                    Button(role: .destructive) {
                                        requestDelete(index: index)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(ranges.count <= 1)
                                    .accessibilityLabel("Supprimer")
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if mode == .edit {
                                Button(role: .destructive) {
                                    requestDelete(index: index)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                                .disabled(ranges.count <= 1)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Édition")
            .navigationBarTitleDisplayMode(.inline)
            .toast($toast)
            .onAppear {
                if originalRanges.isEmpty {
                    originalRanges = ranges
                }
            }
            .alert("Confirmer la suppression", isPresented: $showDeleteConfirm) {
                Button("Annuler", role: .cancel) { pendingDeleteIndex = nil }
                Button("Supprimer", role: .destructive) {
                    confirmDelete()
                }
            } message: {
                Text(ranges.count <= 1 ? "Impossible de supprimer la dernière plage." : "Cette action est irréversible.")
            }
            .alert("Configuration invalide", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if mode == .edit {
                        Button("Ajouter") {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                ranges.append(.init(name: "Nouvelle plage", startHour: 9, endHour: 12))
                            }
                            toast = ToastData(message: "Plage ajoutée", type: .info, duration: 1.2)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        guard let error = validationError else {
                            if !isDirty {
                                toast = ToastData(message: "Aucun changement", type: .info, duration: 1.2)
                                dismiss()
                                return
                            }
                            
                            onSave()
                            originalRanges = ranges
                            toast = ToastData(message: "Enregistré", type: .success, duration: 1.4)
                            
                            // Laisser le toast visible un instant avant fermeture
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                dismiss()
                            }
                            return
                        }
                        
                        validationMessage = error
                        showValidationAlert = true
                    }
                    .disabled(mode == .read || (!isDirty) || validationError != nil)
                }
            }
        }
    }
    
    private var isDirty: Bool {
        ranges != originalRanges
    }
    
    /// Renvoie un message d'erreur si la configuration est invalide.
    private var validationError: String? {
        // 1) Empêcher la plage "vide"
        if ranges.contains(where: { $0.startHour == $0.endHour }) {
            return "Une plage ne peut pas avoir la même heure de début et de fin."
        }
        
        // 2) Doublons exacts (start/end identiques)
        var seen = Set<String>()
        for r in ranges {
            let key = "\(r.startHour)-\(r.endHour)"
            if seen.contains(key) {
                return "Doublon détecté: \(r.label)."
            }
            seen.insert(key)
        }
        
        // 3) Chevauchements (sur les heures)
        var hourOwner: [Int: Int] = [:] // hour -> index
        for (idx, r) in ranges.enumerated() {
            for h in 0..<24 where r.contains(hour: h) {
                if let other = hourOwner[h], other != idx {
                    return "Chevauchement: \(ranges[other].name) (\(ranges[other].label)) ↔ \(r.name) (\(r.label))."
                }
                hourOwner[h] = idx
            }
        }
        
        return nil
    }
    
    private func requestDelete(index: Int) {
        guard ranges.indices.contains(index) else { return }
        guard ranges.count > 1 else {
            toast = ToastData(message: "Impossible de supprimer la dernière plage", type: .warning, duration: 1.6)
            return
        }
        pendingDeleteIndex = index
        showDeleteConfirm = true
    }
    
    private func confirmDelete() {
        guard let index = pendingDeleteIndex, ranges.indices.contains(index) else { return }
        pendingDeleteIndex = nil
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            _ = ranges.remove(at: index)
        }
        toast = ToastData(message: "Plage supprimée", type: .success, duration: 1.2)
    }
}

// MARK: - “+ Ajouter” Secondary Card (dashed)
struct AddDashedCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(
                                AppColors.border.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(subtitle)")
    }
}

// MARK: - Mini Heatmap (last 4 weeks)
struct MiniWeeklyHeatmapView: View {
    let trades: [Trade]
    
    private struct DayCell: Identifiable {
        let id = UUID()
        let date: Date
        let pnl: Double
    }
    
    private var cells: [DayCell] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -27, to: today) ?? today
        let days = (0..<28).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        
        return days.map { day in
            let dayTrades = trades.filter { cal.isDate($0.date, inSameDayAs: day) }
            let dayPnL = dayTrades.reduce(0.0) { acc, trade in
                acc + (trade.flashPnLNet ?? trade.pnl)
            }
            return DayCell(date: day, pnl: dayPnL)
        }
    }
    
    private var maxAbs: Double {
        max(1.0, cells.map { abs($0.pnl) }.max() ?? 1.0)
    }
    
    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let cols = 7
            let rows = 4
            let cellSize = min(
                (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols),
                (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            )
            
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: cols)
            
            LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                ForEach(cells) { cell in
                    let t = min(1.0, abs(cell.pnl) / maxAbs)
                    let intensity = pow(t, 0.65)
                    let base: Color = cell.pnl > 0 ? AppColors.success : cell.pnl < 0 ? AppColors.error : AppColors.border
                    let fill = cell.pnl == 0 ? AppColors.border.opacity(0.30) : base.opacity(0.18 + 0.70 * intensity)
                    let isCurrentWeek = Calendar.current.isDate(cell.date, equalTo: Date(), toGranularity: .weekOfYear)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(isCurrentWeek ? Color.white.opacity(0.16) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .frame(width: cellSize, height: cellSize)
                        .accessibilityLabel(accessibilityText(for: cell))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
    
    private func accessibilityText(for cell: DayCell) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        let date = f.string(from: cell.date)
        return "Jour \(date), P&L \(String(format: "%.0f", cell.pnl))"
    }
}

// MARK: - Mini P&L Curve (last 30 days)
struct MiniPnLCurveView: View {
    let trades: [Trade]
    let appState: AppState
    
    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let cumulative: Double
    }
    
    private var points: [Point] {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .day, value: -30, to: now) ?? now
        let filtered = trades
            .filter { $0.date >= start }
            .sorted { $0.date < $1.date }
        
        var cumulative = 0.0
        var out: [Point] = []
        for t in filtered {
            let pnl = appState.netPnL(for: t) ?? t.flashPnLNet ?? t.pnl
            cumulative += pnl
            out.append(Point(date: t.date, cumulative: cumulative))
        }
        return out
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if #available(iOS 16.0, *) {
                let currentValue = points.last?.cumulative ?? 0
                let baseColor = currentValue >= 0 ? AppColors.success : AppColors.error
                let values = points.map { $0.cumulative }
                let minV = values.min() ?? 0
                let maxV = values.max() ?? 0
                let padding = max(50, (maxV - minV) * 0.15)
                let yDomain = (minV - padding)...(maxV + padding)
                
                Chart {
                    let total = points.count
                    let recentCount = max(2, Int(Double(total) * 0.20))
                    let splitIndex = max(0, total - recentCount)
                    let past = Array(points.prefix(max(0, splitIndex + 1)))
                    let recent = Array(points.suffix(max(0, total - splitIndex)))
                    
                    ForEach(past) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("P&L", p.cumulative)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [baseColor.opacity(0.16), baseColor.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(.init(lineWidth: 2))
                    }
                    
                    ForEach(recent) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("P&L", p.cumulative)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [baseColor.opacity(0.55), baseColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(.init(lineWidth: 3.2))
                    }
                    
                    RuleMark(y: .value("BreakEven", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.25))
                    
                    if let last = points.last {
                        PointMark(
                            x: .value("Date", last.date),
                            y: .value("P&L", last.cumulative)
                        )
                        .symbolSize(120)
                        .foregroundStyle(last.cumulative >= 0 ? AppColors.success : AppColors.error)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            } else {
                Text("Chart nécessite iOS 16+")
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

