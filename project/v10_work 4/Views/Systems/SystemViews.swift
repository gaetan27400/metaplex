import Foundation
import SwiftUI
import Combine

// MARK: - Add System View
struct AddSystemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var appState = AppState.shared
    @Binding var language: Localizable.Language
    
    @State private var name = ""
    @State private var selectedColor = Color.cyan
    
    let colors: [Color] = [.cyan, .green, .blue, .purple, .pink, .orange, .red, .yellow, .indigo, .teal]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(loc("systemName"), text: $name)
                }
                
                Section("Couleur") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 4 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(loc("newSystem"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("add")) {
                        addSystem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addSystem() {
        guard !name.isEmpty else { return }
        
        if appState.systems.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            dismiss()
            return
        }
        
        let hexColor = selectedColor.toHex() ?? "#00D9FF"
        let system = TradingSystem(name: name, color: hexColor)
        appState.addSystem(system)
        
        print("AddSystemView - System added: \(system.name)")
        print("AddSystemView - Total systems: \(appState.systems.count)")
        print("AddSystemView - All systems: \(appState.systems.map { $0.name })")
        
        dismiss()
    }
    
    private func loc(_ key: String) -> String {
        Localizable.text(key, language: language)
    }
}

// MARK: - System Manager View
struct SystemManagerView: View {
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    @Environment(\.dismiss) var dismiss
    @State private var systemToEdit: TradingSystem?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.systems) { system in
                    HStack {
                        Circle()
                            .fill(Color(hex: system.color))
                            .frame(width: 20, height: 20)
                        
                        Text(system.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        let tradeCount = appState.trades.filter { $0.systemId == system.id }.count
                        Text("\(tradeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        systemToEdit = system
                    }
                }
                .onDelete(perform: deleteSystems)
            }
            .navigationTitle("Gérer les Systèmes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $systemToEdit) { system in
                EditSystemView(system: system, language: $language)
            }
        }
    }
    
    private func deleteSystems(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let system = appState.systems[index]
                do {
                    try await appState.deleteSystem(system)
                } catch {
                    print("⚠️ Erreur lors de la suppression du système \(system.name): \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Edit System View
struct EditSystemView: View {
    let system: TradingSystem
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    
    @State private var name: String
    @State private var selectedColor: Color
    
    let colors: [Color] = [.cyan, .green, .blue, .purple, .pink, .orange, .red, .yellow, .indigo, .teal]
    
    init(system: TradingSystem, language: Binding<Localizable.Language>) {
        self.system = system
        self._language = language
        _name = State(initialValue: system.name)
        _selectedColor = State(initialValue: Color(hex: system.color))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(loc("systemName"), text: $name)
                }
                
                Section("Couleur") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 4 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Statistiques") {
                    let tradeCount = appState.trades.filter { $0.systemId == system.id }.count
                    HStack {
                        Text("Nombre de trades")
                        Spacer()
                        Text("\(tradeCount)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Modifier Système")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        saveSystem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveSystem() {
        guard !name.isEmpty else { return }
        
        var updatedSystem = system
        updatedSystem.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedSystem.color = selectedColor.toHex() ?? "#00D9FF"
        
        Task {
            do {
                try await appState.updateSystem(updatedSystem)
                await MainActor.run {
                    HapticFeedback.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    HapticFeedback.error()
                    // Afficher une alerte d'erreur si nécessaire
                    print("⚠️ Erreur lors de la mise à jour du système: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loc(_ key: String) -> String {
        Localizable.text(key, language: language)
    }
}

// MARK: - System Radar Section
struct SystemRadarSection: View {
    let title: String
    let type: TradeType
    let color: Color
    let appState: AppState
    let language: Localizable.Language
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(color)
                Spacer()
                Text("\(appState.systems.count) systèmes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            ZStack {
                RadarBackground(systemCount: appState.systems.count)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                
                if appState.systems.count > 0 {
                    RadarShape(systems: appState.systems, type: type, appState: appState)
                        .fill(color.opacity(0.3))
                    
                    RadarShape(systems: appState.systems, type: type, appState: appState)
                        .stroke(color, lineWidth: 2)
                    
                    RadarLabels(systems: appState.systems)
                }
            }
            .frame(height: 300)
            .padding()
            .background(Color.surface2)
            .cornerRadius(16)
            
            VStack(spacing: 12) {
                ForEach(Array(appState.systems.enumerated()), id: \.element.id) { index, system in
                    SystemStatRow(
                        system: system,
                        type: type,
                        color: color,
                        appState: appState
                    )
                }
            }
        }
    }
}

// MARK: - System Stat Row
struct SystemStatRow: View {
    let system: TradingSystem
    let type: TradeType
    let color: Color
    let appState: AppState
    
    var stats: (trades: Int, wins: Int, pnl: Double) {
        let filtered = appState.trades.filter { $0.systemId == system.id && $0.type == type }
        let wins = filtered.filter { trade in
            guard let pnl = appState.netPnL(for: trade) else { return false }
            return pnl >= 0
        }.count
        let pnl = filtered.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
        return (filtered.count, wins, pnl)
    }
    
    var body: some View {
        let s = stats
        let winRate = s.trades > 0 ? Double(s.wins) / Double(s.trades) * 100 : 0
        
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: system.color))
                .frame(width: 12, height: 12)
            
            Text(system.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(minWidth: 60, alignment: .leading)
            
            Spacer()
            
            Text(s.trades > 0 ? String(format: "%.1f%%", winRate) : "-")
                .font(.subheadline)
                .foregroundColor(s.trades > 0 ? (winRate >= 50 ? .green : .red) : .secondary)
                .frame(width: 60, alignment: .trailing)
            
            Text("\(s.trades)")
                .font(.subheadline)
                .foregroundColor(s.trades > 0 ? .primary : .secondary)
                .frame(width: 40, alignment: .trailing)
            
            Text(s.trades > 0 ? String(format: "$%.0f", s.pnl) : "$0")
                .font(.subheadline.bold())
                .foregroundColor(s.trades > 0 ? (s.pnl >= 0 ? .green : .red) : .secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(12)
        .background(Color.surface2)
        .cornerRadius(12)
        .opacity(s.trades > 0 ? 1.0 : 0.6)
    }
}

// MARK: - Radar Chart Components
struct RadarBackground: Shape {
    let systemCount: Int
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 40
        
        var path = Path()
        
        for i in 0..<systemCount {
            let angle = (Double(i) / Double(systemCount)) * 2 * .pi - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        return path
    }
}

struct RadarShape: Shape {
    let systems: [TradingSystem]
    let type: TradeType
    let appState: AppState
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2 - 40
        
        var path = Path()
        
        for (index, system) in systems.enumerated() {
            let filtered = appState.trades.filter { $0.systemId == system.id && $0.type == type }
            let wins = filtered.filter { trade in
                guard let pnl = appState.netPnL(for: trade) else { return false }
                return pnl >= 0
            }.count
            let winRate = filtered.isEmpty ? 0 : Double(wins) / Double(filtered.count)
            
            let angle = (Double(index) / Double(systems.count)) * 2 * .pi - .pi / 2
            let radius = maxRadius * winRate
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        return path
    }
}

struct RadarLabels: View {
    let systems: [TradingSystem]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(systems.enumerated()), id: \.offset) { item in
                RadarLabel(
                    system: item.element,
                    index: item.offset,
                    totalCount: systems.count,
                    geometry: geometry
                )
            }
        }
    }
}

struct RadarLabel: View {
    let system: TradingSystem
    let index: Int
    let totalCount: Int
    let geometry: GeometryProxy
    
    private var center: CGPoint {
        CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    
    private var radius: CGFloat {
        min(geometry.size.width, geometry.size.height) / 2 - 20
    }
    
    private var position: CGPoint {
        let angle = (Double(index) / Double(totalCount)) * 2 * .pi - .pi / 2
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        Text(system.name)
            .font(.caption)
            .foregroundColor(.secondary)
            .position(position)
    }
}


// MARK: - Trade Row
struct TradeRow: View {
    let trade: Trade
    let language: Localizable.Language
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trade.symbol)
                    .font(.headline)
                
                Spacer()
                
                if let pnl = appState.netPnL(for: trade) {
                    Text(String(format: "$%.2f", pnl))
                        .font(.headline)
                        .foregroundColor(pnl >= 0 ? .green : .red)
                }
            }
            
            HStack {
                Label(trade.type.rawValue, systemImage: trade.type == .long ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundColor(trade.type == .long ? .green : .red)
                
                Text("â€¢")
                    .foregroundColor(.secondary)
                
                if let system = appState.system(for: trade.systemId) {
                    Text(system.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("â€¢")
                    .foregroundColor(.secondary)
                
                Text(trade.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Color Extension
// Note: Color extensions moved to Utils/ColorExtensions.swift to avoid conflicts

    // MARK: - API Configuration View

    public struct APIConfigurationView: View {
        @EnvironmentObject var appState: AppState
        @Environment(\.dismiss) private var dismiss

        @State private var selectedExchange: ExchangeAPI.ExchangeType = .binance
        @State private var apiName: String = ""
        @State private var apiKey: String = ""
        @State private var secretKey: String = ""

        @State private var isLoading = false
        @State private var showError = false
        @State private var errorMessage = ""
        @State private var showSuccess = false

        public var body: some View {
            NavigationView {
                Form {
                    Section("Exchange") {
                            Picker("Exchange", selection: $selectedExchange) {
                            Text("Binance").tag(ExchangeAPI.ExchangeType.binance)
                            Text("MEXC").tag(ExchangeAPI.ExchangeType.mexc)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section("API Configuration") {
                        TextField("API Name", text: $apiName)
                                TextField("API Key", text: $apiKey)
                        TextField("Secret Key", text: $secretKey)
                    }
                    
                    Section {
                        Button("Test Connection") {
                            testConnection()
                        }
                        .disabled(apiKey.isEmpty || secretKey.isEmpty)
                        
                        Button("Save Configuration") {
                            saveConfiguration()
                                }
                                .disabled(apiName.isEmpty || apiKey.isEmpty || secretKey.isEmpty)
                            }
                        }
                .navigationTitle("API Configuration")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                        dismiss()
                    }
                }
                }
            }
        }
        
        private func testConnection() {
            // Implementation for testing API connection
        }
        
        private func saveConfiguration() {
            // Implementation for saving API configuration
                        dismiss()
        }
    }

// MARK: - Missing Views Stubs
struct MEXCImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("MEXC Import")
                    .font(.title)
                    .padding()
                
                Text("This view is not yet implemented")
                        .foregroundColor(.secondary)
                        .padding()
                
                Button("Close") {
                            dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("MEXC Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}


