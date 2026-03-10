import Foundation
import SwiftUI
import Charts
import Combine

// MARK: - Cumulative P&L Curve View
struct CumulativePnLView: View {
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    @State private var selectedPeriod: PeriodFilter = .all
    @Environment(\.dismiss) var dismiss
    
    private var filteredTrades: [(date: Date, cumulative: Double)] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date = {
            switch selectedPeriod {
            case .all:
                return Date.distantPast
            case .currentWeek:
                return calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .lastWeek:
                return calendar.date(byAdding: .day, value: -14, to: now) ?? now
            case .last2Weeks:
                return calendar.date(byAdding: .day, value: -14, to: now) ?? now
            case .lastMonth:
                return calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .last3Months:
                return calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .last6Months:
                return calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .lastYear:
                return calendar.date(byAdding: .year, value: -1, to: now) ?? now
            }
        }()
        
        let trades = appState.trades
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
        
        var cumulative = 0.0
        var result: [(Date, Double)] = []
        
        for trade in trades {
            if let pnl = appState.netPnL(for: trade) {
                cumulative += pnl
                result.append((trade.date, cumulative))
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Courbe de P&L Cumulé")
                        .font(.title2.bold())
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                    
                    VStack(alignment: .trailing, spacing: 12) {
                        Menu {
                            ForEach(PeriodFilter.allCases) { period in
                                Button(action: { selectedPeriod = period }) {
                                    HStack {
                                        Text(period.rawValue)
                                        if selectedPeriod == period {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedPeriod.rawValue)
                                Image(systemName: "chevron.down")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.surface2)
                            .cornerRadius(8)
                        }
                        
                        if #available(iOS 16.0, *) {
                            Chart {
                                ForEach(Array(filteredTrades.enumerated()), id: \.offset) { index, point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("P&L", point.cumulative)
                                    )
                                    .foregroundStyle(.green)
                                    .interpolationMethod(.catmullRom)
                                    
                                    AreaMark(
                                        x: .value("Date", point.date),
                                        y: .value("P&L", point.cumulative)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.green.opacity(0.3), .green.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month().day())
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 300)
                        } else {
                            Text("Chart nécessite iOS 16+")
                                .foregroundColor(.secondary)
                                .frame(height: 300)
                        }
                    }
                    .padding()
                    .background(Color.surface2)
                    .cornerRadius(16)
                    
                    if let lastPoint = filteredTrades.last {
                        VStack(spacing: 8) {
                            Text("P&L Cumulé")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", lastPoint.cumulative))
                                .font(.title.bold())
                                .foregroundColor(lastPoint.cumulative >= 0 ? .green : .red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.surface2)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Courbe P&L")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

