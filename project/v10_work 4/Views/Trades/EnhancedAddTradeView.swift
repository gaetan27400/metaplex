import Foundation
import SwiftUI
import Combine

// MARK: - Add Trade Mode
enum AddTradeMode: String, CaseIterable {
    case manual = "Manual"
    case fileUpload = "File Upload"
}

// MARK: - Trade Entry Type
enum TradeEntryType: String, CaseIterable {
    case trade = "Trade"
    case dailySummary = "Daily Summary"
}

// MARK: - Instrument Type
enum InstrumentType: String, CaseIterable, Identifiable {
    case stocks = "Stocks"
    case forex = "Forex"
    case crypto = "Crypto"
    case futures = "Futures"
    case options = "Options"
    
    var id: String { rawValue }
}

// MARK: - Enhanced Add Trade View
struct EnhancedAddTradeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    
    @State private var selectedMode: AddTradeMode = .manual
    @State private var entryType: TradeEntryType = .trade
    @State private var instrumentType: InstrumentType = .stocks
    @State private var symbol = ""
    @State private var date = Date()
    @State private var time = Date()
    @State private var type: TradeType = .long
    @State private var entryPrice = ""
    @State private var exitPrice = ""
    @State private var shares = ""
    @State private var fees = ""
    @State private var selectedSystemId: UUID?
    @State private var session: Session = .us
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Selection
                HStack(spacing: 12) {
                    ForEach([AddTradeMode.manual, .fileUpload], id: \.self) { mode in
                        Button(action: { selectedMode = mode }) {
                            Text(mode.rawValue)
                                .font(.subheadline.weight(selectedMode == mode ? .semibold : .regular))
                                .foregroundColor(selectedMode == mode ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedMode == mode ? Color.purple : Color.clear)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding()
                .background(Color.black)
                
                // Entry Type Selection
                HStack(spacing: 0) {
                    ForEach([TradeEntryType.trade, .dailySummary], id: \.self) { type in
                        Button(action: { entryType = type }) {
                            Text(type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(entryType == type ? .white : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .overlay(
                                    Rectangle()
                                        .frame(height: 2)
                                        .foregroundColor(entryType == type ? .purple : .clear)
                                    , alignment: .bottom
                                )
                        }
                    }
                }
                .background(Color.black)
                
                if selectedMode == .manual {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Instrument Type & Symbol
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Instrument type")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    Menu {
                                        ForEach(InstrumentType.allCases) { inst in
                                            Button(action: { instrumentType = inst }) {
                                                HStack {
                                                    Text(inst.rawValue)
                                                    if instrumentType == inst {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.caption)
                                            Text(instrumentType.rawValue)
                                            Spacer()
                                        }
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Symbol")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    TextField("AAPL", text: $symbol)
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Date & Time
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date & time")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: 12) {
                                    DatePicker("", selection: $date, displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                    
                                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Trade Side
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Trade side")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                HStack(spacing: 12) {
                                    Button(action: { type = .long }) {
                                        Text("Long")
                                            .font(.subheadline.weight(type == .long ? .semibold : .regular))
                                            .foregroundColor(AppColors.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(type == .long ? Color.tradingBlue.opacity(0.25) : Color.surface3)
                                            .cornerRadius(12)
                                    }
                                    
                                    Button(action: { type = .short }) {
                                        Text("Short")
                                            .font(.subheadline.weight(type == .short ? .semibold : .regular))
                                            .foregroundColor(AppColors.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(type == .short ? Color.tradingBlue.opacity(0.25) : Color.surface3)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            
                            // Entry & Exit Price
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Entry price")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    TextField("$0.00", text: $entryPrice)
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Exit price")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    TextField("$0.00", text: $exitPrice)
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Shares & Fees
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("# of shares")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    TextField("100", text: $shares)
                                        .keyboardType(.numberPad)
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Fees (optional)")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    TextField("$0.00", text: $fees)
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding()
                                        .background(Color.surface2)
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Save Button
                            Button(action: saveTrade) {
                                Text("Save & review")
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                            }
                            .padding(.top)
                        }
                        .padding()
                    }
                    .background(Color.black)
                } else if false { // brokerSync supprimé
                    VStack(spacing: 20) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Connect your broker")
                            .font(.title2.bold())
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Sync trades automatically from your trading platform")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {}) {
                            Text("Connect Broker")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Upload CSV file")
                            .font(.title2.bold())
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Import multiple trades from a CSV file")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {}) {
                            Text("Choose File")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                }
            }
            .background(Color.black)
            .navigationTitle("Add Trades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .onAppear {
                selectedSystemId = appState.defaultSystemId
            }
        }
    }
    
    private func saveTrade() {
        guard let entry = Double(entryPrice),
              let exit = Double(exitPrice),
              let qty = Double(shares),
              !symbol.isEmpty,
              let exchangeId = appState.defaultExchangeId,
              let systemId = selectedSystemId else { return }
        
        let trade = Trade(
            date: date,
            symbol: symbol,
            type: type,
            entryPrice: entry,
            exitPrice: exit,
            quantity: qty,
            leverage: 1.0,
            exchangeId: exchangeId,
            orderRole: .taker,
            systemId: systemId,
            session: session
        )
        
        appState.addTrade(trade)
        dismiss()
    }
}
enum TradingGoal: String, CaseIterable, Identifiable {
    case consistentProfits = "Consistent Profits"
    case reduceLosses = "Reduce Losses"
    case learnFaster = "Learn Faster"
    case allAbove = "All of the Above"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .consistentProfits: return "💰"
        case .reduceLosses: return "🛡"
        case .learnFaster: return "🚀"
        case .allAbove: return "⭐️"
        }
    }
    
    var subtitle: String {
        switch self {
        case .consistentProfits: return "Turn patterns into predictable wins."
        case .reduceLosses: return "Avoid emotional trades and false signals."
        case .learnFaster: return "Master psychology and advanced setups."
        case .allAbove: return "I want it all — profits, safety, and mastery."
        }
    }
}

// MARK: - Main App View
