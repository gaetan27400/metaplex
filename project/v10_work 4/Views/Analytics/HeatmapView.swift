import SwiftUI
import Charts

struct HeatmapView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @StateObject private var heatmapService: HeatmapService
    @State private var selectedType: HeatmapType = .symbol
    @State private var selectedMetric: HeatmapMetric = .pnl
    @State private var selectedAggregation: HeatmapAggregation = .sum
    @State private var selectedPeriod: DateInterval
    @State private var heatmapResult: HeatmapResult?
    @State private var isLoading = false
    @State private var showingConfiguration = false
    
    init() {
        // Initialisation avec des stores mock pour l'instant
        let mockTradeStore = MockTradeStore()
        let mockSystemStore = MockSystemStore()
        self._heatmapService = StateObject(wrappedValue: HeatmapService(tradeStore: mockTradeStore, systemStore: mockSystemStore))
        
        // Période par défaut : 6 derniers mois
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        self._selectedPeriod = State(initialValue: DateInterval(start: startDate, end: endDate))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Configuration Header
                configurationHeader
                
                // Heatmap Content
                if isLoading {
                    loadingView
                } else if let result = heatmapResult {
                    heatmapContent(result: result)
                } else {
                    emptyState
                }
            }
            .navigationTitle(t("performanceHeatmaps"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Config") {
                        showingConfiguration = true
                    }
                }
            }
            .sheet(isPresented: $showingConfiguration) {
                HeatmapConfigurationView(
                    selectedType: $selectedType,
                    selectedMetric: $selectedMetric,
                    selectedAggregation: $selectedAggregation,
                    selectedPeriod: $selectedPeriod
                ) {
                    Task {
                        await loadHeatmap()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadHeatmap()
                }
            }
        }
    }
    
    // MARK: - Configuration Header
    private var configurationHeader: some View {
        VStack(spacing: 12) {
            // Type et Métrique
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("type"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(t("mtrique"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedMetric.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Période
            HStack {
                Text(t("priode"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(periodDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(t("generatingHeatmap"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)
            
            Text(t("noData"))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(t("trades"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Heatmap Content
    private func heatmapContent(result: HeatmapResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Heatmap Grid
                heatmapGrid(result: result)
                
                // Insights
                if !result.insights.isEmpty {
                    insightsSection(insights: result.insights)
                }
                
                // Métadonnées
                metadataSection(result: result)
            }
            .padding()
        }
    }
    
    // MARK: - Heatmap Grid
    private func heatmapGrid(result: HeatmapResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("heatmapDePerformance"))
                .font(.headline)
            
            // Légende
            legendView(result: result)
            
            // Grille
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Y-Axis Labels
                    VStack(spacing: 0) {
                        // Corner cell
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 60, height: 30)
                        
                        // Y-axis labels
                        ForEach(result.yAxisLabels, id: \.self) { label in
                            Text(label)
                                .font(.caption)
                                .frame(width: 60, height: 30)
                                .background(Color.gray.opacity(0.1))
                        }
                    }
                    
                    // Heatmap cells
                    VStack(spacing: 0) {
                        // X-axis labels
                        HStack(spacing: 0) {
                            ForEach(result.xAxisLabels, id: \.self) { label in
                                Text(label)
                                    .font(.caption)
                                    .frame(width: 60, height: 30)
                                    .background(Color.gray.opacity(0.1))
                            }
                        }
                        
                        // Data cells
                        ForEach(result.yAxisLabels, id: \.self) { yLabel in
                            HStack(spacing: 0) {
                                ForEach(result.xAxisLabels, id: \.self) { xLabel in
                                    let value = result.valueAt(x: xLabel, y: yLabel) ?? 0.0
                                    let color = result.colorFor(value: value)
                                    
                                    VStack(spacing: 2) {
                                        Text(String(format: "%.1f", value))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                        
                                        if let metadata = result.data.first(where: { $0.xAxis == xLabel && $0.yAxis == yLabel })?.metadata {
                                            Text("\(metadata.tradeCount) trades")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 60, height: 30)
                                    .background(color.opacity(0.7))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Legend View
    private func legendView(result: HeatmapResult) -> some View {
        HStack {
            Text(t("lgende"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    let value = result.minValue + (result.maxValue - result.minValue) * Double(index) / 4.0
                    let color = result.colorFor(value: value)
                    
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                            .cornerRadius(2)
                        
                        Text(String(format: "%.1f", value))
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    // MARK: - Insights Section
    private func insightsSection(insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("insights"))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text(insight)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Metadata Section
    private func metadataSection(result: HeatmapResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("informations"))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(t("type"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(result.configuration.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text(t("mtrique"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(result.configuration.metric.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text(t("agrgation"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(result.configuration.aggregation.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text(t("valeurMin"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", result.minValue))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text(t("valeurMax"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", result.maxValue))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var periodDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: selectedPeriod.start)) - \(formatter.string(from: selectedPeriod.end))"
    }
    
    // MARK: - Actions
    private func loadHeatmap() async {
        isLoading = true
        
        do {
            let configuration = HeatmapConfiguration(
                type: selectedType,
                period: selectedPeriod,
                metric: selectedMetric,
                aggregation: selectedAggregation
            )
            
            heatmapResult = try await heatmapService.generateHeatmap(configuration: configuration)
        } catch {
            print("Erreur lors de la génération de la heatmap: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Heatmap Configuration View
struct HeatmapConfigurationView: View {
    @Binding var selectedType: HeatmapType
    @Binding var selectedMetric: HeatmapMetric
    @Binding var selectedAggregation: HeatmapAggregation
    @Binding var selectedPeriod: DateInterval
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Type de Heatmap") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(HeatmapType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }.tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Métrique") {
                    Picker("Métrique", selection: $selectedMetric) {
                        ForEach(HeatmapMetric.allCases, id: \.self) { metric in
                            Text(metric.displayName).tag(metric)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Agrégation") {
                    Picker("Agrégation", selection: $selectedAggregation) {
                        ForEach(HeatmapAggregation.allCases, id: \.self) { aggregation in
                            Text(aggregation.displayName).tag(aggregation)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Période") {
                    DatePicker("Début", selection: Binding(
                        get: { selectedPeriod.start },
                        set: { selectedPeriod = DateInterval(start: $0, end: selectedPeriod.end) }
                    ), displayedComponents: .date)
                    
                    DatePicker("Fin", selection: Binding(
                        get: { selectedPeriod.end },
                        set: { selectedPeriod = DateInterval(start: selectedPeriod.start, end: $0) }
                    ), displayedComponents: .date)
                }
            }
            .navigationTitle(t("configuration"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("add")) {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HeatmapView()
}
