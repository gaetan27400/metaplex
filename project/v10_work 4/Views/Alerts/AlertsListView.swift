//
//  AlertsListView.swift
//  Journal de trading 2025
//

import SwiftUI
import Combine

struct AlertsListView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @StateObject private var viewModel = AlertsListViewModel()
    @State private var showingFilters = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var selectedAlert: Alert?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with filters
                alertsHeader
                
                // Alerts list
                alertsList
            }
            .navigationTitle(t("alerts"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showingFilters = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.white)
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                AlertFiltersView(filters: $viewModel.filters)
            }
            .sheet(isPresented: $showingSettings) {
                AlertSettingsView()
            }
            .sheet(item: $selectedAlert) { alert in
                AlertDetailView(alert: alert)
            }
            .searchable(text: $searchText, prompt: "Rechercher dans les alertes")
            .onAppear {
                viewModel.loadAlerts()
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.updateSearchText(newValue)
            }
        }
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Header
    
    private var alertsHeader: some View {
        VStack(spacing: 12) {
            // Statistics
            HStack(spacing: 20) {
                AlertsStatCard(
                    title: "Total",
                    value: "\(viewModel.alerts.count)",
                    color: .blue
                )
                
                AlertsStatCard(
                    title: "Non lues",
                    value: "\(viewModel.unreadCount)",
                    color: .red
                )
                
                AlertsStatCard(
                    title: "Aujourd'hui",
                    value: "\(viewModel.todayCount)",
                    color: .green
                )
            }
            
            // Active filters indicator
            if viewModel.hasActiveFilters {
                activeFiltersView
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.activeFilters, id: \.self) { filter in
                    Text(filter)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button("Effacer") {
                    viewModel.clearFilters()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Alerts List
    
    private var alertsList: some View {
        List {
            ForEach(viewModel.filteredAlerts) { alert in
                AlertRowView(alert: alert)
                    .onTapGesture {
                        selectedAlert = alert
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Supprimer", role: .destructive) {
                            viewModel.deleteAlert(alert)
                        }
                        
                        if !alert.isRead {
                            Button("Marquer lu") {
                                viewModel.markAsRead(alert)
                            }
                            .tint(.blue)
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await viewModel.refreshAlerts()
        }
    }
}

// MARK: - Alert Row View

struct AlertRowView: View {
    let alert: Alert
    
    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(Color(hex: alert.severity.color))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.symbol)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(alert.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    // Tags
                    if !alert.tags.isEmpty {
                        ForEach(alert.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    // Price if available
                    if let price = alert.price {
                        Text(String(format: "$%.2f", price))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Read indicator
            if !alert.isRead {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .background(alert.isRead ? Color.clear : Color.blue.opacity(0.1))
    }
}

// MARK: - Stat Card (Alerts scope)

struct AlertsStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - View Model

class AlertsListViewModel: ObservableObject {
    @Published var alerts: [Alert] = []
    @Published var filters = AlertFilters.default
    @Published var searchText = ""
    
    var unreadCount: Int {
        alerts.filter { !$0.isRead }.count
    }
    
    var todayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return alerts.filter { alert in
            alert.createdAt >= today && alert.createdAt < tomorrow
        }.count
    }
    
    var filteredAlerts: [Alert] {
        var filtered = alerts
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { alert in
                alert.symbol.localizedCaseInsensitiveContains(searchText) ||
                alert.message.localizedCaseInsensitiveContains(searchText) ||
                alert.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply other filters
        if let symbol = filters.symbol {
            filtered = filtered.filter { $0.symbol == symbol }
        }
        
        if let severity = filters.severity {
            filtered = filtered.filter { $0.severity == severity }
        }
        
        if let tags = filters.tags, !tags.isEmpty {
            filtered = filtered.filter { alert in
                tags.allSatisfy { tag in
                    alert.tags.contains(tag)
                }
            }
        }
        
        if let dateRange = filters.dateRange {
            filtered = filtered.filter { alert in
                alert.createdAt >= dateRange.start && alert.createdAt <= dateRange.end
            }
        }
        
        if let isRead = filters.isRead {
            filtered = filtered.filter { $0.isRead == isRead }
        }
        
        if let source = filters.source {
            filtered = filtered.filter { $0.source == source }
        }
        
        return filtered
    }
    
    var hasActiveFilters: Bool {
        filters.symbol != nil ||
        filters.severity != nil ||
        filters.tags?.isEmpty == false ||
        filters.dateRange != nil ||
        filters.isRead != nil ||
        filters.source != nil
    }
    
    var activeFilters: [String] {
        var active: [String] = []
        
        if let symbol = filters.symbol {
            active.append("Symbole: \(symbol)")
        }
        
        if let severity = filters.severity {
            active.append("Sévérité: \(severity.displayName)")
        }
        
        if let tags = filters.tags, !tags.isEmpty {
            active.append("Tags: \(tags.joined(separator: ", "))")
        }
        
        if filters.dateRange != nil {
            active.append("Période")
        }
        
        if let isRead = filters.isRead {
            active.append(isRead ? "Lues" : "Non lues")
        }
        
        if let source = filters.source {
            active.append("Source: \(source.displayName)")
        }
        
        return active
    }
    
    func loadAlerts() {
        // TODO: Load alerts from store
        // This will be implemented when we integrate with the actual store
    }
    
    func refreshAlerts() async {
        // TODO: Refresh alerts from store
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
    }
    
    func markAsRead(_ alert: Alert) {
        // TODO: Mark alert as read in store
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            var updatedAlert = alert
            updatedAlert = Alert(
                id: alert.id,
                createdAt: alert.createdAt,
                symbol: alert.symbol,
                exchange: alert.exchange,
                price: alert.price,
                message: alert.message,
                severity: alert.severity,
                tags: alert.tags,
                payloadJSON: alert.payloadJSON,
                isRead: true,
                source: alert.source,
                linkedTradeId: alert.linkedTradeId
            )
            alerts[index] = updatedAlert
        }
    }
    
    func deleteAlert(_ alert: Alert) {
        // TODO: Delete alert from store
        alerts.removeAll { $0.id == alert.id }
    }
    
    func clearFilters() {
        filters = AlertFilters.default
    }
}

#Preview {
    AlertsListView()
}
