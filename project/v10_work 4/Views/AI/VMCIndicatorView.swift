//
//  VMCIndicatorView.swift
//  Journal de trading 2025
//

import SwiftUI
import Charts

struct VMCIndicatorView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let candles: [Candle]
    let preset: IndicatorPreset
    @State private var result: VMCSignalResult?
    
    var body: some View {
        VStack(spacing: 16) {
            if let result = result {
                // Signal status
                HStack {
                    Text(t("signal"))
                        .font(.headline)
                    Spacer()
                    Text(result.status)
                        .font(.headline)
                        .foregroundColor(result.status == "BUY" ? .green : result.status == "SELL" ? .red : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(result.status == "BUY" ? Color.green.opacity(0.2) : result.status == "SELL" ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                        )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("ai"))
                        .font(.headline)
                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Chart placeholder (simple visualization)
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("vmc"))
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text(t("vmc"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", result.sig))
                                .font(.caption)
                                .bold()
                        }
                        
                        VStack(alignment: .leading) {
                            Text(t("signalLine"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", result.sigSignal))
                                .font(.caption)
                                .bold()
                        }
                        
                        VStack(alignment: .leading) {
                            Text(t("momentum"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", result.momentum))
                                .font(.caption)
                                .bold()
                                .foregroundColor(result.momentum >= 0 ? .green : .red)
                        }
                    }
                    
                    // Simple bars visualization
                    VStack(spacing: 4) {
                        // VMC Signal bar
                        HStack {
                            Text(t("vmc"))
                                .font(.caption2)
                                .frame(width: 40, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: abs(geo.size.width * CGFloat(result.sig / 100.0)))
                                }
                            }
                            .frame(height: 8)
                            Text(String(format: "%.1f", result.sig))
                                .font(.caption2)
                                .frame(width: 40)
                        }
                        
                        // Signal line bar
                        HStack {
                            Text(t("signIn"))
                                .font(.caption2)
                                .frame(width: 40, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.orange.opacity(0.3))
                                        .frame(width: abs(geo.size.width * CGFloat(result.sigSignal / 100.0)))
                                }
                            }
                            .frame(height: 8)
                            Text(String(format: "%.1f", result.sigSignal))
                                .font(.caption2)
                                .frame(width: 40)
                        }
                        
                        // Momentum histogram
                        HStack {
                            Text(t("mom"))
                                .font(.caption2)
                                .frame(width: 40, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(result.momentum >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                                        .frame(width: geo.size.width * CGFloat(max(0, min(1, abs(result.momentum / 100.0)))))
                                }
                            }
                            .frame(height: 8)
                            Text(String(format: "%.1f", result.momentum))
                                .font(.caption2)
                                .frame(width: 40)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
                // Conditions
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("conditions"))
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Bull Confirm", systemImage: result.bullConfirm ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(result.bullConfirm ? .green : .red)
                            Label("Bear Confirm", systemImage: result.bearConfirm ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(result.bearConfirm ? .red : .green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Label(result.ribbonBull ? "Bull Ribbon" : result.ribbonBear ? "Bear Ribbon" : "Neutral", systemImage: "lines.horizontal.3")
                                .foregroundColor(result.ribbonBull ? .green : result.ribbonBear ? .red : .gray)
                            Label(result.compression ? "Compression" : "Normal", systemImage: "circle.dotted")
                                .foregroundColor(result.compression ? .yellow : .gray)
                        }
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else {
                ProgressView("Calcul de l'indicateur...")
            }
        }
        .padding()
        .onAppear {
            calculateIndicator()
        }
    }
    
    private func calculateIndicator() {
        let convertedCandles = candles.map { candle in
            VMCIndicatorCandle(open: candle.open, high: candle.high, low: candle.low, close: candle.close, volume: candle.volume)
        }
        result = VMCIndicator.evaluate(candles: convertedCandles, preset: preset)
    }
}
