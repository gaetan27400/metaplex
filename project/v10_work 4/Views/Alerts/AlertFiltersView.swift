//
//  AlertFiltersView.swift
//  Journal de trading 2025
//

import SwiftUI

struct AlertFiltersView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @Binding var filters: AlertFilters
    @Environment(\.dismiss) private var dismiss
    @State private var tempFilters: AlertFilters
    
    init(filters: Binding<AlertFilters>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Symbol Filter
                symbolSection
                
                // Severity Filter
                severitySection
                
                // Tags Filter
                tagsSection
                
                // Date Range Filter
                dateRangeSection
                
                // Read Status Filter
                readStatusSection
                
                // Source Filter
                sourceSection
                
                // Clear Filters
                clearSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(t("filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("add")) {
                        filters = tempFilters
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Symbol Section
    
    private var symbolSection: some View {
        Section(header: Text(t("symbole"))) {
            TextField("Rechercher par symbole", text: Binding(
                get: { tempFilters.symbol ?? "" },
                set: { tempFilters.symbol = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }
    
    // MARK: - Severity Section
    
    private var severitySection: some View {
        Section(header: Text(t("svrit"))) {
            Picker("Sévérité", selection: Binding(
                get: { tempFilters.severity },
                set: { tempFilters.severity = $0 }
            )) {
                Text(t("toutes")).tag(AlertSeverity?.none)
                ForEach(AlertSeverity.allCases, id: \.self) { severity in
                    HStack {
                        Circle()
                            .fill(Color(hex: severity.color))
                            .frame(width: 12, height: 12)
                        Text(severity.displayName)
                    }
                    .tag(AlertSeverity?.some(severity))
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        Section(header: Text(t("tags"))) {
            TextField("Tags (séparés par des virgules)", text: Binding(
                get: { tempFilters.tags?.joined(separator: ", ") ?? "" },
                set: { tempFilters.tags = $0.isEmpty ? nil : $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }
    
    // MARK: - Date Range Section
    
    private var dateRangeSection: some View {
        Section(header: Text(t("priode"))) {
            DatePicker("Début", selection: Binding(
                get: { tempFilters.dateRange?.start ?? Date().addingTimeInterval(-30 * 24 * 60 * 60) },
                set: { 
                    if let end = tempFilters.dateRange?.end {
                        tempFilters.dateRange = DateInterval(start: $0, end: end)
                    } else {
                        tempFilters.dateRange = DateInterval(start: $0, end: Date())
                    }
                }
            ), displayedComponents: .date)
            
            DatePicker("Fin", selection: Binding(
                get: { tempFilters.dateRange?.end ?? Date() },
                set: { 
                    if let start = tempFilters.dateRange?.start {
                        tempFilters.dateRange = DateInterval(start: start, end: $0)
                    } else {
                        tempFilters.dateRange = DateInterval(start: Date().addingTimeInterval(-30 * 24 * 60 * 60), end: $0)
                    }
                }
            ), displayedComponents: .date)
            
            // Quick date range buttons
            VStack(spacing: 8) {
                Text(t("priodesRapides"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Button(t("today")) {
                        setQuickDateRange(.today)
                    }
                    .buttonStyle(QuickFilterButtonStyle())
                    
                    Button("7 jours") {
                        setQuickDateRange(.last7Days)
                    }
                    .buttonStyle(QuickFilterButtonStyle())
                    
                    Button("30 jours") {
                        setQuickDateRange(.last30Days)
                    }
                    .buttonStyle(QuickFilterButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Read Status Section
    
    private var readStatusSection: some View {
        Section(header: Text(t("statutDeLecture"))) {
            Picker("Statut", selection: Binding(
                get: { tempFilters.isRead },
                set: { tempFilters.isRead = $0 }
            )) {
                Text(t("toutes")).tag(Bool?.none)
                Text(t("no")).tag(Bool?.some(false))
                Text(t("lues")).tag(Bool?.some(true))
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Source Section
    
    private var sourceSection: some View {
        Section(header: Text(t("source"))) {
            Picker("Source", selection: Binding(
                get: { tempFilters.source },
                set: { tempFilters.source = $0 }
            )) {
                Text(t("toutes")).tag(AlertSource?.none)
                ForEach(AlertSource.allCases, id: \.self) { source in
                    HStack {
                        Image(systemName: source.icon)
                        Text(source.displayName)
                    }
                    .tag(AlertSource?.some(source))
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    // MARK: - Clear Section
    
    private var clearSection: some View {
        Section {
            Button("Effacer tous les filtres", role: .destructive) {
                tempFilters = AlertFilters.default
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setQuickDateRange(_ range: QuickDateRange) {
        let now = Date()
        let calendar = Calendar.current
        
        switch range {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            tempFilters.dateRange = DateInterval(start: start, end: end)
            
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            tempFilters.dateRange = DateInterval(start: start, end: now)
            
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            tempFilters.dateRange = DateInterval(start: start, end: now)
        }
    }
}

// MARK: - Quick Date Range

enum QuickDateRange {
    case today
    case last7Days
    case last30Days
}

// MARK: - Quick Filter Button Style

struct QuickFilterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
    }
}

#Preview {
    AlertFiltersView(filters: .constant(AlertFilters.default))
}











