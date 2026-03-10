//
//  RSIDashboardMTFView.swift
//  Journal de trading 2025
//
//  Vue Dashboard RSI Multi-Timeframe (style TradingView)
//

import SwiftUI

struct RSIDashboardMTFView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let snapshot: RSISnapshot
    let symbol: String
    @State private var selectedTimeframe: VMCTimeframe?
    @State private var showFullScreen = false
    
    init(snapshot: RSISnapshot, symbol: String = "BTCUSDT") {
        self.snapshot = snapshot
        self.symbol = symbol
    }
    
    var body: some View {
        compactView
            .fullScreenCover(isPresented: $showFullScreen) {
                fullScreenView
            }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        VStack(spacing: 16) {
            // Header avec signal global et RSI global
            HStack {
                globalHeaderView
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        showFullScreen = true
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(6)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            
            // Colonnes horizontales
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Colonne Ticker (symbole)
                    tickerColumn
                    
                    // Colonne Global
                    globalColumn
                    
                    // Colonnes par timeframe (dans l'ordre inverse comme le VMC)
                    ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                        if let reading = snapshot.readings[tf] {
                            timeframeColumn(reading: reading, timeframe: tf)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Légende
            legendView
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Global Header (Compact)
    
    private var globalHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("signalGlobal"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text(snapshot.globalSignal.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(snapshot.globalSignal.color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text(t("rsi"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                HStack(spacing: 6) {
                    if snapshot.isTurningUp {
                        Text("▲") // TODO: Traduire avec clé appropriée
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if snapshot.isTurningDown {
                        Text("▼") // TODO: Traduire avec clé appropriée
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Text(String(format: "%.0f", snapshot.globalRSI))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundColor(rsiGradientColor(snapshot.globalRSI))
                }
            }
        }
    }
    
    // MARK: - Ticker Column
    
    private var tickerColumn: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                let parts = symbol.replacingOccurrences(of: "USDT", with: "").components(separatedBy: "USDT")
                let ticker = parts.first ?? symbol
                Text(ticker)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text(t("mexc"))
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.7))
            }
            .frame(height: 60)
            .padding(.vertical, 8)
            Spacer()
        }
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    // MARK: - Global Column
    
    private var globalColumn: some View {
        let gradient = rsiGradient(snapshot.globalRSI)
        let isTurningUp = snapshot.isTurningUp
        
        return VStack(spacing: 8) {
            Text(snapshot.globalSignal.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(snapshot.globalSignal.color)
                .frame(height: 24)
                .padding(.top, 4)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                    
                    // RSI : barre depuis le bas (0-100)
                    Rectangle()
                        .fill(gradient)
                        .frame(
                            width: geometry.size.width - 4,
                            height: min(snapshot.globalRSI * 0.8, geometry.size.height * 0.9)
                        )
                        .offset(y: geometry.size.height * 0.45 - min(snapshot.globalRSI * 0.4, geometry.size.height * 0.45))
                }
            }
            .frame(height: 110)
            
            VStack(spacing: 4) {
                if isTurningUp {
                    Text("▲") // TODO: Traduire avec clé appropriée
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(t("assistant"))
                        .font(.caption)
                }
                Text(String(format: "%.0f", snapshot.globalRSI))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .monospacedDigit()
                if !isTurningUp {
                    Text("▼") // TODO: Traduire avec clé appropriée
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(t("assistant"))
                        .font(.caption)
                }
            }
            .frame(height: 50)
            
            Text(t("global"))
                .font(.caption)
                .foregroundColor(.white)
                .frame(height: 24)
                .padding(.bottom, 4)
        }
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    // MARK: - Timeframe Column
    
    @ViewBuilder
    private func timeframeColumn(reading: RSIReading, timeframe: VMCTimeframe) -> some View {
        let gradient = rsiGradient(reading.value)
        
        return VStack(spacing: 8) {
            Text(reading.status.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(reading.status.color)
                .frame(height: 24)
                .padding(.top, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                    
                    // RSI : barre depuis le bas (0-100)
                    Rectangle()
                        .fill(gradient)
                        .frame(
                            width: geometry.size.width - 4,
                            height: min(reading.value * 0.8, geometry.size.height * 0.9)
                        )
                        .offset(y: geometry.size.height * 0.45 - min(reading.value * 0.4, geometry.size.height * 0.45))
                }
            }
            .frame(height: 110)
            
            Text(String(format: "%.0f", reading.value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .monospacedDigit()
                .frame(height: 30)
            
            Text(timeframe.displayName)
                .font(.caption)
                .foregroundColor(.white)
                .frame(height: 24)
                .padding(.bottom, 4)
        }
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    // MARK: - RSI Gradient
    
    static func rsiGradient(_ value: Double) -> LinearGradient {
        let normalized = max(0, min(100, value))
        
        if normalized >= 70 {
            // Overbought : rouge
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= 50 {
            // 50-70 : violet → rouge
            return LinearGradient(
                colors: [
                    Color(red: 0.54, green: 0.17, blue: 0.89),
                    Color.red.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= 30 {
            // 30-50 : bleu → violet
            return LinearGradient(
                colors: [
                    Color.blue,
                    Color(red: 0.54, green: 0.17, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Oversold : bleu foncé
            return LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.blue],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private func rsiGradient(_ value: Double) -> LinearGradient {
        Self.rsiGradient(value)
    }
    
    private func rsiGradientColor(_ value: Double) -> Color {
        let normalized = max(0, min(100, value))
        if normalized >= 70 {
            return .red
        } else if normalized >= 50 {
            return Color(red: 0.54, green: 0.17, blue: 0.89)
        } else {
            return .blue
        }
    }
    
    // MARK: - Legend
    
    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: .blue, text: "Oversold")
            legendItem(color: Color(red: 0.54, green: 0.17, blue: 0.89), text: "Neutre")
            legendItem(color: .red, text: "Overbought")
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.top, 12)
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Full Screen View (similaire à VMC)
    
    private var fullScreenView: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea(.all)
                    
                    VStack(spacing: 12) {
                        fullScreenHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                tickerColumn
                                
                                if snapshot.globalRSI != 0 {
                                    globalColumn
                                }
                                
                                ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                                    if let reading = snapshot.readings[tf] {
                                        timeframeColumn(reading: reading, timeframe: tf)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: geometry.size.height * 0.65)
                        
                        VStack(spacing: 8) {
                            fullScreenStats
                                .padding(.horizontal, 16)
                            legendView
                                .padding(.horizontal, 16)
                        }
                        .frame(height: geometry.size.height * 0.2)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(t("dashboard"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        AppDelegate.orientationLock = .all
                        showFullScreen = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
            .onAppear {
                AppDelegate.orientationLock = .landscapeLeft
                DispatchQueue.main.async {
                    if #available(iOS 16.0, *) {
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
                    } else {
                        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                    }
                }
            }
            .onDisappear {
                AppDelegate.orientationLock = .all
            }
        }
    }
    
    private var fullScreenHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("rsi"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                HStack(spacing: 6) {
                    if snapshot.isTurningUp {
                        Text("▲") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else if snapshot.isTurningDown {
                        Text("▼") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    Text(String(format: "%.0f", snapshot.globalRSI))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(rsiGradientColor(snapshot.globalRSI))
                }
                Text(snapshot.globalSignal.displayName)
                    .font(.subheadline)
                    .foregroundColor(snapshot.globalSignal.color)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    private var fullScreenStats: some View {
        HStack(spacing: 12) {
            StatCardCompact(
                title: "Timeframes",
                value: "\(snapshot.readings.count)",
                color: .blue
            )
            StatCardCompact(
                title: "Signal",
                value: snapshot.globalSignal.displayName,
                color: snapshot.globalSignal.color
            )
            StatCardCompact(
                title: "Tendance",
                value: snapshot.isTurningUp ? "▲ Hausse" : snapshot.isTurningDown ? "▼ Baisse" : "→ Stable",
                color: snapshot.isTurningUp ? .green : snapshot.isTurningDown ? .red : .gray
            )
        }
    }
    
    private struct StatCardCompact: View {
        let title: String
        let value: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.6))
            )
        }
    }
}
