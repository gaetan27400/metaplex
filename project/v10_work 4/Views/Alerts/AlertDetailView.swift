//
//  AlertDetailView.swift
//  Journal de trading 2025
//

import SwiftUI

struct AlertDetailView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let alert: Alert
    @Environment(\.dismiss) private var dismiss
    @State private var showingTradeCreation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    alertHeader
                    
                    // Content
                    alertContent
                    
                    // Actions
                    alertActions
                    
                    // Metadata
                    alertMetadata
                }
                .padding()
            }
            .navigationTitle(t("alertDetail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showingTradeCreation) {
            // TODO: Show trade creation view
            Text(t("crationDeTrade"))
        }
    }
    
    // MARK: - Alert Header
    
    private var alertHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Severity indicator
                Image(systemName: alert.severity.icon)
                    .font(.title)
                    .foregroundColor(Color(hex: alert.severity.color))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.symbol)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(alert.severity.displayName)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: alert.severity.color))
                }
                
                Spacer()
                
                // Read status
                if !alert.isRead {
                    Text(t("no"))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
            
            // Timestamp
            Text("Reçu le \(alert.createdAt, style: .date) à \(alert.createdAt, style: .time)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Alert Content
    
    private var alertContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Message
            VStack(alignment: .leading, spacing: 8) {
                Text(t("message"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(alert.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Price information
            if let price = alert.price {
                HStack {
                    Text(t("price"))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(String(format: "$%.4f", price))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Exchange
            if let exchange = alert.exchange {
                HStack {
                    Text(t("exchanges"))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(exchange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Alert Actions
    
    private var alertActions: some View {
        VStack(spacing: 12) {
            Text(t("actions"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: { showingTradeCreation = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(t("crerUnTrade"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                if !alert.isRead {
                    Button(action: markAsRead) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(t("tuesday"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Alert Metadata
    
    private var alertMetadata: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("informations"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tags
            if !alert.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("tags"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(alert.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Source
            HStack {
                Text(t("source"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: alert.source.icon)
                    Text(alert.source.displayName)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            // Linked trade
            if alert.linkedTradeId != nil {
                HStack {
                    Text(t("tradeLi"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Voir le trade") {
                        // TODO: Navigate to trade
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            // Payload (if available and not empty)
            if !alert.payloadJSON.isEmpty && alert.payloadJSON != "{}" {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("donnesTechniques"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(alert.payloadJSON)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func markAsRead() {
        // TODO: Mark alert as read in store
        print("Marking alert as read: \(alert.id)")
    }
}

// MARK: - Color Extension
// Note: Color extension with init(hex:) is defined elsewhere in the project

#Preview {
    AlertDetailView(alert: Alert(
        symbol: "BTCUSDT",
        exchange: "MEXC",
        price: 45000.50,
        message: "Prix de BTC a atteint un niveau de résistance important. Considérez une prise de bénéfices.",
        severity: AlertSeverity.high,
        tags: ["résistance", "bitcoin", "profit"],
        payloadJSON: "{\"price\": 45000.50, \"volume\": 1234567}",
        source: AlertSource.tradingView
    ))
}
