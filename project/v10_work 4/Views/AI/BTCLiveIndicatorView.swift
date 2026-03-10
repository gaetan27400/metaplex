//
//  BTCLiveIndicatorView.swift
//  Journal de trading 2025
//

import SwiftUI
import Foundation

struct BTCLiveIndicatorView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @State private var currentPrice: Double? = nil
    @State private var priceChange: Double? = nil
    @State private var isLoading = false
    @State private var lastUpdate = Date()
    
    // Customizable timeframes
    @State private var selectedTimeframes: Set<String> = ["1h", "4h", "1d", "1w"]
    @State private var showTimeframeSelector = false
    
    // Available timeframes
    private let availableTimeframes: [String] = ["5m", "15m", "1h", "4h", "1d", "1w"]
    
    // Multi-timeframe data structure
    @State private var timeframeData: [TimeframeData] = []
    
    // Display options
    var showHeader: Bool = true
    var showPrice: Bool = true
    var showTable: Bool = true
    var showMarketAnalysis: Bool = true
    
    struct TimeframeData: Identifiable {
        let id = UUID()
        let name: String
        let rsi: Double?
        let macd: Double?
        let vmc: Double?
        let trix: Double?
        let odp: Double?
        let trend: String
        let recommendation: String
    }
    
    struct LiquidationLevel {
        let price: Double
        let liquidity: Double
    }
    
    struct LiquidationData {
        let shorts: [LiquidationLevel]?
        let longs: [LiquidationLevel]?
    }
    
    @State private var marketAnalysis: String = ""
    @State private var isAnalyzing = false
    @State private var selectedAnalysisTab: AnalysisTimeframe = .shortTerm
    
    // VMC Dashboard
    @State private var vmcSnapshot: VMCSnapshot?
    @State private var isLoadingVMC = false
    @State private var showVMCDashboard = true
    
    enum AnalysisTimeframe: String, CaseIterable {
        case shortTerm = "M15/H1"
        case mediumTerm = "H4/Daily"
        case longTerm = "Weekly"
        
        var displayName: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .shortTerm: return "bolt.fill"
            case .mediumTerm: return "clock.fill"
            case .longTerm: return "calendar"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                if showHeader {
                    headerView
                }
                
                // Price display
                if showPrice, let price = currentPrice {
                    priceDisplay(price: price)
                }
                
                // Multi-timeframe analysis table
                if showTable && !timeframeData.isEmpty {
                    analysisTableView
                }
                
                // Market Analysis section
                if showMarketAnalysis {
                    marketAnalysisSection
                }
                
                // VMC Dashboard section
                if showVMCDashboard {
                    vmcdashboardSection
                }
                
                // Espacement pour éviter que le contenu soit coupé par la barre de navigation
                Spacer()
                    .frame(height: 100)
            }
            .padding()
        }
        .onAppear {
            Task {
                await fetchLiveData()
                // Automatically trigger market analysis after fetching data
                await analyzeMarket()
                // Load VMC Dashboard
                await loadVMCSnapshot()
            }
        }
        .onChange(of: selectedTimeframes) { oldValue, newValue in
            // Refresh data when timeframes change
            Task {
                await updateTimeframeAnalysis()
                await analyzeMarket()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("analyse"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(t("btcusdt"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Button {
                        showTimeframeSelector = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Button {
                        Task { await fetchLiveData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(isLoading)
                }
            }
            
            // Selected timeframes pills
            if !selectedTimeframes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTimeframes).sorted(), id: \.self) { tf in
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(tf)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .sheet(isPresented: $showTimeframeSelector) {
            TimeframeSelectorView(
                availableTimeframes: availableTimeframes,
                selectedTimeframes: $selectedTimeframes
            )
        }
    }
    
    private func priceDisplay(price: Double) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(t("btcusdt"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if let change = priceChange {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        Text(String(format: "%.2f%%", abs(change)))
                    }
                    .font(.subheadline)
                    .foregroundColor(change >= 0 ? .green : .red)
                }
            }
            
            Text("$\(String(format: "%.2f", price))")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(priceChange ?? 0 >= 0 ? .green : .red)
            
            Text(t("date"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.06))
        .cornerRadius(12)
    }
    
    private var analysisTableView: some View {
        ScrollView {
            VStack(spacing: 0) {
            // Table header with gradient
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text(t("indicateurs"))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .frame(width: 100, alignment: .leading)
                
                ForEach(timeframeData) { tf in
                    VStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(tf.name)
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // RSI row
            indicatorRow(title: "RSI", icon: "waveform", data: timeframeData, thresholdHigh: 70, thresholdLow: 30, getValue: { $0.rsi }, decimals: 1)
            
            // MACD row
            indicatorRow(title: "MACD", icon: "chart.xyaxis.line", data: timeframeData, thresholdHigh: 0, thresholdLow: 0, getValue: { $0.macd }, decimals: 1)
            
            // VMC row
            indicatorRow(title: "VMC", icon: "percent", data: timeframeData, thresholdHigh: 40, thresholdLow: -50, getValue: { $0.vmc }, decimals: 1)
            
            // TRIX row
            indicatorRow(title: "TRIX", icon: "triangle.fill", data: timeframeData, thresholdHigh: 0, thresholdLow: 0, getValue: { $0.trix }, decimals: 1)
            
            // ODP row
            indicatorRow(title: "ODP", icon: "waveform.path", data: timeframeData, thresholdHigh: 60, thresholdLow: -60, getValue: { $0.odp }, decimals: 1)
            
            Divider()
                .padding(.horizontal)
            
            // Trend row with improved styling
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text(t("trend"))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .frame(width: 100, alignment: .leading)
                
                ForEach(timeframeData) { tf in
                    Text(trendShortText(tf.trend))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(trendColor(tf.trend))
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            
            // Recommendation row with improved styling
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text(t("reco"))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .frame(width: 100, alignment: .leading)
                
                ForEach(timeframeData) { tf in
                    VStack(spacing: 2) {
                        Image(systemName: recommendationIcon(tf.recommendation))
                            .font(.system(size: 10))
                        Text(recommendationShortText(tf.recommendation))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(recommendationColor(tf.recommendation))
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
    
    private func indicatorRow(title: String, icon: String, data: [TimeframeData], thresholdHigh: Double, thresholdLow: Double, getValue: @escaping (TimeframeData) -> Double?, decimals: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 100, alignment: .leading)
            
            ForEach(data) { tf in
                let value = getValue(tf)
                let color = indicatorColor(value: value, thresholdHigh: thresholdHigh, thresholdLow: thresholdLow)
                
                Text(formatValue(value, decimals: decimals))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(color)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func indicatorColor(value: Double?, thresholdHigh: Double, thresholdLow: Double) -> Color {
        guard let value = value, !value.isNaN, !value.isInfinite else {
            return Color.gray.opacity(0.3)
        }
        
        // If thresholds are 0, compare to 0 instead
        if thresholdHigh == 0 && thresholdLow == 0 {
            if value > 0 {
                return Color.red.opacity(0.7)
            } else if value < 0 {
                return Color.green.opacity(0.7)
            } else {
                return Color.gray.opacity(0.3)
            }
        }
        
        // Color coding based on thresholds
        if value >= thresholdHigh {
            return Color.red.opacity(0.7)  // Bearish overbought
        } else if value <= thresholdLow {
            return Color.green.opacity(0.7)  // Bullish oversold
        } else {
            return Color.gray.opacity(0.3)  // Neutral
        }
    }
    
    private func formatValue(_ value: Double?, decimals: Int) -> String {
        guard let value = value, !value.isNaN, !value.isInfinite else {
            return "—"
        }
        return String(format: "%.\(decimals)f", value)
    }
    
    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "Bullish": return .green
        case "Bearish": return .red
        default: return .orange
        }
    }
    
    private func recommendationColor(_ reco: String) -> Color {
        switch reco {
        case "BUY": return .green
        case "SELL": return .red
        case "WAIT": return .orange
        default: return .gray
        }
    }
    
    private func recommendationIcon(_ reco: String) -> String {
        switch reco {
        case "BUY": return "arrow.up.circle.fill"
        case "SELL": return "arrow.down.circle.fill"
        case "WAIT": return "pause.circle.fill"
        default: return "circle"
        }
    }
    
    // MARK: - Text Shortening Functions
    private func trendShortText(_ trend: String) -> String {
        switch trend {
        case "Bullish": return "BULL"
        case "Bearish": return "BEAR"
        default: return trend.prefix(4).uppercased()
        }
    }
    
    private func recommendationShortText(_ reco: String) -> String {
        switch reco {
        case "BUY": return "BUY"
        case "SELL": return "SELL"
        case "WAIT": return "WAIT"
        case "NEUTRAL": return "NEU"
        case "DELIVER": return "DLV"
        default: return reco.prefix(3).uppercased()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func fetchLiveData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch current price
            let url = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let ticker = try JSONDecoder().decode(BinanceTicker.self, from: data)
            await MainActor.run {
                let newPrice = Double(ticker.price) ?? 0
                if let oldPrice = currentPrice {
                    priceChange = ((newPrice - oldPrice) / oldPrice) * 100
                }
                currentPrice = newPrice
                lastUpdate = Date()
            }
            
            // Fetch multi-timeframe analysis
            await updateTimeframeAnalysis()
        } catch {
            print("❌ Error fetching live data: \(error)")
        }
    }
    
    private func updateTimeframeAnalysis() async {
        // Use selected timeframes instead of hardcoded ones
        let timeframes = Array(selectedTimeframes).sorted()
        var data: [TimeframeData] = []
        
        for tf in timeframes {
            do {
                // Fetch candles for each timeframe
                let candles = try await MarketDataService.shared.fetchKlines(symbol: "BTCUSDT", interval: tf, limit: 200)
                
                // Calculate indicators
                let rsi = calculateRSI(prices: candles.map { $0.close })
                let macd = calculateMACD(prices: candles.map { $0.close })
                let vmc = calculateVMC(candles: candles)
                let trix = calculateTRIX(prices: candles.map { $0.close })
                let odp = calculateODP(candles: candles)
                
                // Determine trend
                let trend = determineTrend(candles: candles, timeframe: tf)
                
                // Generate recommendation
                let recommendation = generateRecommendation(rsi: rsi, macd: macd, vmc: vmc, trend: trend)
                
                data.append(TimeframeData(
                    name: tf,
                    rsi: rsi,
                    macd: macd,
                    vmc: vmc,
                    trix: trix,
                    odp: odp,
                    trend: trend,
                    recommendation: recommendation
                ))
            } catch {
                print("❌ Error analyzing timeframe \(tf): \(error)")
            }
        }
        
        await MainActor.run {
            self.timeframeData = data
        }
    }
    
    // MARK: - Indicator Calculations
    
    private func calculateRSI(prices: [Double], period: Int = 14) -> Double? {
        guard prices.count > period + 1 else { return nil }
        
        // Calculate RSI using Wilder's smoothing method
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<prices.count {
            let change = prices[i] - prices[i-1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }
        
        // Initial averages
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        
        // Apply Wilder's smoothing to subsequent values
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
        }
        
        guard avgLoss != 0 else { return 50.0 }
        
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    private func calculateEMA(_ values: [Double], length: Int) -> [Double] {
        guard length > 0, !values.isEmpty else { return Array(repeating: 0, count: values.count) }
        let k = 2.0 / (Double(length) + 1.0)
        var out = Array(repeating: 0.0, count: values.count)
        out[0] = values[0]
        for i in 1..<values.count {
            out[i] = values[i] * k + out[i-1] * (1 - k)
        }
        return out
    }
    
    private func calculateMACD(prices: [Double], fast: Int = 12, slow: Int = 26) -> Double? {
        guard prices.count >= slow else { return nil }
        
        let fastEMA = calculateEMA(prices, length: fast)
        let slowEMA = calculateEMA(prices, length: slow)
        
        guard let fastVal = fastEMA.last, let slowVal = slowEMA.last else { return nil }
        return fastVal - slowVal
    }
    
    private func calculateLinearRegression(_ values: [Double], length: Int, offset: Int = 0) -> Double? {
        guard values.count >= length + offset else { return nil }
        guard length > 0 else { return nil }
        
        let end = values.count - 1 - offset
        let start = end - length + 1
        
        // Calculate linear regression
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0
        
        for i in 0..<length {
            let x = Double(i)
            let y = values[start + i]
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let n = Double(length)
        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        return slope
    }
    
    private func transform(_ src: Double, mult: Double) -> Double {
        let tmp = (src / 100.0 - 0.5) * 2.0
        return mult * 100.0 * (tmp >= 0 ? 1 : -1) * pow(abs(tmp), 0.75)
    }
    
    private func calculateMFI(high: [Double], low: [Double], close: [Double], volume: [Double], length: Int) -> [Double] {
        guard high.count == low.count && low.count == close.count && close.count == volume.count else {
            return Array(repeating: 0, count: high.count)
        }
        
        var mfi = Array(repeating: 0.0, count: high.count)
        var hlc3: [Double] = []
        
        for i in 0..<high.count {
            let hlc = (high[i] + low[i] + close[i]) / 3.0
            hlc3.append(hlc)
        }
        
        for i in length..<high.count {
            var positiveFlow: Double = 0
            var negativeFlow: Double = 0
            
            for j in (i - length + 1)...i {
                let rawMoneyFlow = hlc3[j] * volume[j]
                if j > 0 {
                    if hlc3[j] > hlc3[j - 1] {
                        positiveFlow += rawMoneyFlow
                    } else if hlc3[j] < hlc3[j - 1] {
                        negativeFlow += rawMoneyFlow
                    }
                }
            }
            
            if negativeFlow == 0 {
                mfi[i] = 100
            } else {
                let moneyFlowRatio = positiveFlow / negativeFlow
                mfi[i] = 100 - (100 / (1 + moneyFlowRatio))
            }
        }
        
        return mfi
    }
    
    private func calculateStoch(source: [Double], length: Int) -> [Double] {
        var stoch = Array(repeating: 50.0, count: source.count)
        
        for i in length..<source.count {
            let slice = Array(source[(i - length + 1)...i])
            guard let highest = slice.max(), let lowest = slice.min(), highest != lowest else {
                continue
            }
            stoch[i] = ((source[i] - lowest) / (highest - lowest)) * 100.0
        }
        
        return stoch
    }
    
    private func calculateVMC(candles: [Candle]) -> Double? {
        // VMC optimized parameters from configuration
        let rsiLen = 14
        let _ = 30  // mfiLen: not used directly in current implementation
        let smoothLen = 10  // Lissage principal
        let smoothMult = 1.75
        let mfiWeight = 0.40  // Poids MFI
        let stochWeight = 0.40  // Poids Stoch
        let _ = 0  // rrScoreMin: not used directly in current implementation
        
        guard candles.count >= rsiLen * 3 else { return nil }
        
        let close = candles.map { $0.close }
        let high = candles.map { $0.high }
        let low = candles.map { $0.low }
        let volume = candles.map { $0.volume }
        let hlc3 = zip(zip(high, low).map { ($0 + $1) / 2.0 }, close).map { ($0 + $1) / 2.0 }
        
        // Calculate RSI, MFI, and Stochastic
        var rsiValues: [Double] = []
        for i in 0..<hlc3.count {
            if i >= rsiLen {
                let slice = Array(hlc3[(i - rsiLen + 1)...i])
                if let rsiVal = calculateRSI(prices: slice, period: rsiLen) {
                    rsiValues.append(rsiVal)
                } else {
                    rsiValues.append(50)
                }
            } else {
                rsiValues.append(50)
            }
        }
        
        let mfi = calculateMFI(high: high, low: low, close: close, volume: volume, length: 7)
        let stoch = calculateStoch(source: rsiValues, length: rsiLen)
        let stochSmooth = calculateEMA(stoch, length: 2)
        
        // Calculate core
        let denom = 1.0 + mfiWeight + stochWeight
        var core: [Double] = []
        for i in 0..<rsiValues.count {
            let c = (rsiValues[i] + mfiWeight * mfi[i] + stochWeight * stochSmooth[i]) / denom
            core.append(c)
        }
        
        // Calculate EMA fast and slow
        let emaFast = calculateEMA(core, length: smoothLen)
        let emaSlow = calculateEMA(core, length: Int((Double(smoothLen) * smoothMult).rounded()))
        
        // Apply transform
        let sig = emaFast.map { transform($0, mult: 1.0) }
        let _ = emaSlow.map { transform($0, mult: 1.0) }  // sigSignal: not used in current implementation
        
        return sig.last
    }
    
    private func calculateTRIX(prices: [Double], period: Int = 9) -> Double? {
        guard prices.count >= period * 3 else { return nil }
        
        // Calculate triple EMA for TRIX
        let ema1 = calculateEMA(prices, length: period)
        let ema2 = calculateEMA(ema1, length: period)
        let ema3 = calculateEMA(ema2, length: period)
        
        guard ema3.count >= 2 else { return nil }
        guard let prevVal = ema3.dropLast().last, let currVal = ema3.last, prevVal != 0 else { return nil }
        
        // Return rate of change of triple EMA (TRIX formula)
        return ((currVal - prevVal) / prevVal) * 100
    }
    
    private func calculateODP(candles: [Candle]) -> Double? {
        guard candles.count >= 21 else { return nil }
        
        // ODP parameters from settings: n1=10, n2=21
        let n1 = 10  // Channel length
        let n2 = 21  // Average length
        
        let ap = candles.map { ($0.high + $0.low + $0.close) / 3.0 }  // HLC3
        
        // Calculate ESA (EMA of ap with n1)
        let esa = calculateEMA(ap, length: n1)
        
        // Calculate d (EMA of absolute difference between ap and esa)
        let diff = zip(ap, esa).map { abs($0 - $1) }
        let d = calculateEMA(diff, length: n1)
        
        // Calculate CI (Channel Indicator) for all points
        var ci: [Double] = []
        for i in 0..<min(ap.count, min(esa.count, d.count)) {
            let denom = 0.015 * d[i]
            if denom != 0 {
                ci.append((ap[i] - esa[i]) / denom)
            } else {
                ci.append(0)
            }
        }
        
        // Calculate WT1 = EMA of CI with n2
        let wt1 = calculateEMA(ci, length: n2)
        
        return wt1.last
    }
    
    private func fastSMA(_ timeframe: String) -> Int {
        switch timeframe {
        case "1w", "1W": return 10
        case "1d", "1D": return 50
        case "240", "4h", "4H": return 50
        default: return 20
        }
    }
    
    private func slowSMA(_ timeframe: String) -> Int {
        switch timeframe {
        case "1w", "1W": return 40
        case "1d", "1D": return 200
        case "240", "4h", "4H": return 200
        default: return 50
        }
    }
    
    private func determineTrend(candles: [Candle], timeframe: String) -> String {
        let fastLen = fastSMA(timeframe)
        let slowLen = slowSMA(timeframe)
        
        guard candles.count >= slowLen else { return "Unstable" }
        
        let fastSMA = candles.suffix(fastLen).map { $0.close }.reduce(0, +) / Double(fastLen)
        let slowSMA = candles.suffix(slowLen).map { $0.close }.reduce(0, +) / Double(slowLen)
        
        if fastSMA > slowSMA {
            return "Bullish"
        } else if fastSMA < slowSMA {
            return "Bearish"
        } else {
            return "Unstable"
        }
    }
    
    private func generateRecommendation(rsi: Double?, macd: Double?, vmc: Double?, trend: String) -> String {
        var score = 0
        
        if let rsi = rsi, rsi < 30 {
            score += 1
        } else if let rsi = rsi, rsi > 70 {
            score -= 1
        }
        
        // Updated VMC thresholds: 40 (high) and -50 (low)
        if let vmc = vmc, vmc < -50 {
            score += 1
        } else if let vmc = vmc, vmc > 40 {
            score -= 1
        }
        
        if let macd = macd, macd > 0 {
            score += 1
        } else if let macd = macd, macd < 0 {
            score -= 1
        }
        
        if trend == "Bullish" && score > 0 {
            return "BUY"
        } else if trend == "Bearish" && score < 0 {
            return "SELL"
        } else if score > 0 {
            return "WAIT"
        } else {
            return "NEUTRAL"
        }
    }
    
    private var marketAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header without button (automatic analysis)
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(t("tuesday"))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(t("analysisInProgress"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Timeframe Tabs
            if !marketAnalysis.isEmpty {
                HStack(spacing: 12) {
                    ForEach(AnalysisTimeframe.allCases, id: \.self) { timeframe in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedAnalysisTab = timeframe
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: timeframe.icon)
                                    .font(.caption)
                                Text(timeframe.displayName)
                                    .font(.subheadline)
                                    .fontWeight(selectedAnalysisTab == timeframe ? .semibold : .regular)
                            }
                            .foregroundColor(selectedAnalysisTab == timeframe ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedAnalysisTab == timeframe ?
                                          LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                                          LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .leading)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedAnalysisTab == timeframe ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Analysis content with better formatting
            if !marketAnalysis.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Filter and display only the selected timeframe analysis
                        if let relevantSection = getAnalysisSection(for: selectedAnalysisTab) {
                            VStack(alignment: .leading, spacing: 16) {
                                formattedAnalysisText(relevantSection)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: getGradientColors(for: selectedAnalysisTab.rawValue),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        getBorderColor(for: selectedAnalysisTab.rawValue),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: getShadowColor(for: selectedAnalysisTab.rawValue), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.visible)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.65)
            } else if !isAnalyzing {
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(t("analysisWaiting"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(t("tuesday"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - VMC Dashboard Section
    
    private var vmcdashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text(t("dashboard"))
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isLoadingVMC {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(t("loading"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // VMC Dashboard Content
            if let snapshot = vmcSnapshot {
                VMCDashboardMTFView(snapshot: snapshot)
            } else if !isLoadingVMC {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(t("noData"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Recharger") {
                        Task {
                            await loadVMCSnapshot()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Load VMC Snapshot
    
    private func loadVMCSnapshot() async {
        isLoadingVMC = true
        defer { isLoadingVMC = false }
        
        do {
            let snapshot = try await VMCService.shared.fetchVMCSnapshotCached(
                symbol: "BTCUSDT"
            )
            await MainActor.run {
                self.vmcSnapshot = snapshot
            }
        } catch {
            Logger.default.error("Failed to load VMC snapshot: \(error.localizedDescription)")
        }
    }
    
    private func parseAnalysis(_ text: String) -> [String] {
        // Split by PARTIE markers to extract complete timeframe sections
        var sections: [String] = []
        let lines = text.components(separatedBy: "\n")
        var currentSection: [String] = []
        
        for line in lines {
            // Check if line is a section header
            if line.contains("PARTIE 1") || line.contains("PARTIE 2") || line.contains("PARTIE 3") ||
               line.contains("COURTE TERME") || line.contains("MOYEN TERME") || line.contains("LONG TERME") ||
               (line.contains("━━━━") && (line.contains("1") || line.contains("2") || line.contains("3"))) {
                
                // Save previous section if exists
                if !currentSection.isEmpty {
                    sections.append(currentSection.joined(separator: "\n"))
                    currentSection = []
                }
            }
            
            currentSection.append(line)
        }
        
        // Add last section
        if !currentSection.isEmpty {
            sections.append(currentSection.joined(separator: "\n"))
        }
        
        // Fallback: if no sections found, return the whole text as one section
        if sections.isEmpty {
            return [text]
        }
        
        return sections.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    private func formatText(_ text: String) -> String {
        // Basic text formatting for better readability
        var formatted = text
        
        // Replace multiple spaces with single space
        formatted = formatted.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        // Trim excessive line breaks
        formatted = formatted.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @ViewBuilder
    private func formattedAnalysisText(_ text: String) -> some View {
        let lines = text.split(separator: "\n")
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let processedLine = cleanLine(String(line))
                
                // Skip separator lines (dash lines)
                if !processedLine.isEmpty && !processedLine.trimmingCharacters(in: .whitespaces).hasPrefix("━") {
                    Text(processedLine)
                        .font(shouldBeBold(line) ? .title3.weight(.bold) : .body)
                        .foregroundColor(shouldBeBold(line) ? getTitleColor(line) : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(6)
                        .kerning(0.1)
                }
            }
        }
    }
    
    private func cleanLine(_ line: String) -> String {
        var cleaned = line
        
        // Remove "PARTIE X :" patterns
        cleaned = cleaned.replacingOccurrences(of: "PARTIE 1 :", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "PARTIE 2 :", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "PARTIE 3 :", with: "", options: .caseInsensitive)
        
        // Remove "COURTE TERME", "MOYEN TERME", "LONG TERME" patterns
        cleaned = cleaned.replacingOccurrences(of: "COURTE TERME", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "MOYEN TERME", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "LONG TERME", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "Courte terme", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "Moyen terme", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "Long terme", with: "", options: .caseInsensitive)
        
        // Remove separator lines (only dash characters)
        let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
        if trimmed.allSatisfy({ $0 == "━" }) {
            return ""
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    private func shouldBeBold(_ line: String.SubSequence) -> Bool {
        let trimmed = String(line).trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("━") ||
               trimmed.hasPrefix("🔹") ||
               trimmed.hasPrefix("📊") ||
               trimmed.hasPrefix("💰") ||
               trimmed.hasPrefix("🌊") ||
               trimmed.hasPrefix("🌍") ||
               trimmed.hasPrefix("🎯") ||
               trimmed.hasPrefix("PARTIE")
    }
    
    private func getTitleColor(_ line: String.SubSequence) -> Color {
        let trimmed = String(line).trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("━") {
            return .blue
        } else if trimmed.contains("COURTE TERME") {
            return .red
        } else if trimmed.contains("MOYEN TERME") {
            return .orange
        } else if trimmed.contains("LONG TERME") {
            return .green
        } else if trimmed.hasPrefix("🔹") || trimmed.hasPrefix("📊") {
            return .blue
        } else if trimmed.hasPrefix("💰") {
            return .yellow
        } else if trimmed.hasPrefix("🌊") {
            return .cyan
        } else if trimmed.hasPrefix("🌍") {
            return .mint
        } else if trimmed.hasPrefix("🎯") {
            return .purple
        }
        return .primary
    }
    
    private func getAnalysisSection(for timeframe: AnalysisTimeframe) -> String? {
        let sections = parseAnalysis(marketAnalysis)
        
        // Debug: print found sections
        print("🔍 Found \(sections.count) sections")
        for (index, section) in sections.enumerated() {
            let preview = String(section.prefix(100))
            print("  Section \(index): \(preview)...")
        }
        
        switch timeframe {
        case .shortTerm:
            // Look for PARTIE 1 or COURTE TERME or M15/H1
            return sections.first { section in
                let uppercased = section.uppercased()
                return uppercased.contains("PARTIE 1") ||
                       uppercased.contains("PARTIE 1 :") ||
                       uppercased.contains("COURTE TERME") ||
                       uppercased.contains("M15/H1") ||
                       uppercased.contains("M15")
            }
        case .mediumTerm:
            // Look for PARTIE 2 or MOYEN TERME or H4/DAILY
            return sections.first { section in
                let uppercased = section.uppercased()
                return uppercased.contains("PARTIE 2") ||
                       uppercased.contains("PARTIE 2 :") ||
                       uppercased.contains("MOYEN TERME") ||
                       uppercased.contains("H4/DAILY") ||
                       uppercased.contains("H4")
            }
        case .longTerm:
            // Look for PARTIE 3 or LONG TERME or WEEKLY
            return sections.first { section in
                let uppercased = section.uppercased()
                return uppercased.contains("PARTIE 3") ||
                       uppercased.contains("PARTIE 3 :") ||
                       uppercased.contains("LONG TERME") ||
                       uppercased.contains("WEEKLY")
            }
        }
    }
    
    private func getGradientColors(for timeframe: String) -> [Color] {
        if timeframe == "M15/H1" || timeframe == "COURTE TERME" {
            return [Color.red.opacity(0.1), Color.orange.opacity(0.05)]
        } else if timeframe == "H4/Daily" || timeframe == "MOYEN TERME" {
            return [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)]
        } else {
            return [Color.green.opacity(0.1), Color.mint.opacity(0.05)]
        }
    }
    
    private func getBorderColor(for timeframe: String) -> Color {
        if timeframe == "M15/H1" || timeframe == "COURTE TERME" {
            return Color.red.opacity(0.3)
        } else if timeframe == "H4/Daily" || timeframe == "MOYEN TERME" {
            return Color.blue.opacity(0.3)
        } else {
            return Color.green.opacity(0.3)
        }
    }
    
    private func getShadowColor(for timeframe: String) -> Color {
        if timeframe == "M15/H1" || timeframe == "COURTE TERME" {
            return Color.red.opacity(0.2)
        } else if timeframe == "H4/Daily" || timeframe == "MOYEN TERME" {
            return Color.blue.opacity(0.2)
        } else {
            return Color.green.opacity(0.2)
        }
    }
    
    private func analyzeMarket() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let lang = LanguageManager.shared.currentLanguage
        let isEN = lang == .english
        
        // Prepare market data summary with technical indicators
        var summary = isEN
            ? "📊 COMPLETE TECHNICAL ANALYSIS - BTC/USDT\n"
            : "📊 ANALYSE TECHNIQUE COMPLÈTE - BTC/USDT\n"
        summary += "Timestamp: \(Date().formatted())\n"
        summary += isEN
            ? "Current price: $\(String(format: "%.2f", currentPrice ?? 0))\n"
            : "Prix actuel: $\(String(format: "%.2f", currentPrice ?? 0))\n"
        summary += isEN
            ? "24h Change: \(String(format: "%.2f", priceChange ?? 0))%\n\n"
            : "Variation 24h: \(String(format: "%.2f", priceChange ?? 0))%\n\n"
        
        summary += "════════════════════════════════════════\n"
        summary += isEN
            ? "TECHNICAL INDICATORS BY TIMEFRAME\n"
            : "INDICATEURS TECHNIQUES PAR TIMEFRAME\n"
        summary += "════════════════════════════════════════\n\n"
        
        for tf in timeframeData {
            summary += "📊 TIMEFRAME: \(tf.name)\n"
            summary += "────────────────────────────────────\n"
            if let rsi = tf.rsi {
                summary += "RSI: \(formatValue(rsi, decimals: 2))"
                if rsi > 70 {
                    summary += " ⚠️ SURACHAT (\(String(format: "%.1f", (rsi - 70))))\n"
                } else if rsi < 30 {
                    summary += " 📉 SURVENTE (\(String(format: "%.1f", 30 - rsi))))\n"
                } else {
                    summary += " ✅ Neutre\n"
                }
            }
            
            if let macd = tf.macd {
                summary += "MACD: \(formatValue(macd, decimals: 6))"
                if macd > 0 {
                    summary += " 📈 Haussier (+\(String(format: "%.6f", macd)))\n"
                } else {
                    summary += " 📉 Baissier (\(String(format: "%.6f", macd)))\n"
                }
            }
            
            if let vmc = tf.vmc {
                summary += "VMC: \(formatValue(vmc, decimals: 2))"
                if vmc > 40 {
                    summary += " ⚠️ SURACHAT (écart: \(String(format: "%.1f", vmc - 40)))\n"
                } else if vmc < -50 {
                    summary += " 📉 SURVENTE (écart: \(String(format: "%.1f", abs(vmc + 50))))\n"
                } else {
                    summary += " ✅ Neutre\n"
                }
            }
            
            if let trix = tf.trix {
                summary += "TRIX: \(formatValue(trix, decimals: 6))"
                if trix > 0 {
                    summary += " 📈 Pente ↗️\n"
                } else {
                    summary += " 📉 Pente ↘️\n"
                }
            }
            
            if let odp = tf.odp {
                summary += "ODP: \(formatValue(odp, decimals: 2))"
                if odp > 60 {
                    summary += " ⚠️ SUR-ACHAT\n"
                } else if odp < -60 {
                    summary += " 📉 SUR-VENTE\n"
                } else {
                    summary += " ✅ Neutre\n"
                }
            }
            
            summary += "TREND: \(tf.trend.uppercased())\n"
            summary += "RECO: \(tf.recommendation)\n\n"
        }
        
        summary += "\n📈 \(isEN ? "Requested analysis" : "Analyse demandée"):\n"
        summary += isEN
            ? "Analyze the BTC/USDT market dynamics by comparing technical indicators (RSI, MACD, VMC, TRIX, ODP) across 4 timeframes (1h, 4h, 1d, 1w). Identify divergence zones, convergence, and directional forces. Provide a qualitative analysis of market technical health."
            : "Analyse la dynamique du marché BTC/USDT en comparant les indicateurs techniques (RSI, MACD, VMC, TRIX, ODP) sur les 4 timeframes (1h, 4h, 1d, 1w). Identifie les zones de divergence, convergence, et forces directionnelles. Fournis une analyse qualitative de la santé technique du marché."
        
        // Call AI for analysis
        print("🔄 [BTCLiveIndicator] Starting market analysis...")
        do {
            let aiResponse = try await callOpenAIForAnalysis(prompt: summary, language: lang)
            print("✅ [BTCLiveIndicator] Market analysis completed, length: \(aiResponse.count)")
            await MainActor.run {
                marketAnalysis = aiResponse
            }
        } catch {
            print("❌ [BTCLiveIndicator] Market analysis error: \(error.localizedDescription)")
            // Fallback to basic analysis
            await MainActor.run {
                marketAnalysis = generateIndicatorBasedAnalysis()
            }
        }
    }
    
    private func callOpenAIForAnalysis(prompt: String, language: Localizable.Language = .french) async throws -> String {
        print("✅ [BTCLiveIndicator] Using Cloud Functions for OpenAI analysis")
        
        let isEN = language == .english
        
        // Fetch external market data
        let externalData = await fetchExternalMarketData()
        
        // Extract only Funding Rate and Open Interest from external data
        let cleanedExternalData = extractOnlyCoinGlassData(externalData)
        
        // Language-specific system instructions
        let languageInstruction = isEN
            ? "You MUST respond ONLY in English."
            : "Tu DOIS répondre UNIQUEMENT en français."
        
        let styleInstruction = isEN
            ? """
            You are an expert technical analyst in cryptocurrencies and derivatives markets.
            Write in an elegant, professional and aesthetically refined manner.
            Use short sentences, precise vocabulary, airy layout with short paragraphs (2-3 sentences max).
            Round all numbers to 1 decimal place. Be factual, neutral and confident.
            Structure your response with visual separators and judicious use of emojis (📊 📈 📉 ⚠️ ✅).
            \(languageInstruction)
            """
            : """
            Tu es un analyste technique expert en cryptomonnaies et marchés dérivés.
            Rédige une analyse professionnelle, élégante et esthétiquement agréable du marché BTC/USDT.
            Phrases courtes, vocabulaire précis, paragraphes aérés (2-3 phrases max).
            Numéros arrondis à 1 décimale. Ton neutre, factuel et confiant.
            Structure ta réponse avec des séparateurs visuels et un usage judicieux des emojis (📊 📈 📉 ⚠️ ✅).
            \(languageInstruction)
            """
        
        // Structure labels based on language
        let part1Label = isEN ? "SHORT TERM (M15/H1)" : "COURTE TERME (M15/H1)"
        let part2Label = isEN ? "MEDIUM TERM (H4/Daily)" : "MOYEN TERME (H4/Daily)"
        let part3Label = isEN ? "LONG TERM (Weekly)" : "LONG TERME (Weekly)"
        let techLabel = isEN ? "Technical Analysis" : "Analyse Technique"
        let fundingLabel = isEN ? "Funding Rate" : "Funding Rate"
        let oiLabel = isEN ? "Open Interest" : "Open Interest"
        let macroLabel = isEN ? "Macro Context" : "Contexte Macro"
        let synthLabel = isEN ? "Summary" : "Synthèse"
        let trendLabel = isEN ? "Trend" : "Tendance"
        let momentumLabel = isEN ? "Momentum" : "Momentum"
        let positionLabel = isEN ? "Position" : "Position"
        let bullish = isEN ? "Bullish/Bearish/Neutral" : "Haussière/Baissière/Neutre"
        let strength = isEN ? "Strong/Moderate/Weak" : "Fort/Modéré/Faible"
        let pos = isEN ? "Long/Short/Wait" : "Long/Short/Wait"
        let sameStructure = isEN ? "[Same structure as Part 1]" : "[Même structure que Partie 1]"
        let dataLabel = isEN ? "DATA TO ANALYZE" : "DONNÉES À ANALYSER"
        
        // Enhance prompt with external data
        let enhancedPrompt = """
        \(styleInstruction)

        🎯 \(isEN ? "OBJECTIVE" : "OBJECTIF") :
        \(isEN
            ? "Provide a comprehensive analysis integrating: technical indicators (RSI, MACD, TRIX, ODP, VMC), Funding Rate and sentiment impact, Open Interest and its relationship with price, macroeconomic context, synthesis and recommendation per timeframe."
            : "Fournir une analyse complète intégrant : indicateurs techniques (RSI, MACD, TRIX, ODP, VMC), Funding Rate et impact sentiment, Open Interest et sa relation avec le prix, contexte macroéconomique, synthèse et recommandation par timeframe.")

        📋 \(isEN ? "REQUIRED STRUCTURE" : "STRUCTURE IMPOSÉE") :
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🔹 PART 1 : \(part1Label)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        📊 \(techLabel)
        [\(isEN ? "Concise synthesis of indicators with values" : "Synthèse concise des indicateurs avec valeurs")]
        
        💰 \(fundingLabel)
        [\(isEN ? "Value + Interpretation + Sentiment impact" : "Valeur + Interprétation + Impact sentiment")]
        
        🌊 \(oiLabel)
        [\(isEN ? "Value + Level + Price relationship" : "Valeur + Niveau + Relation prix")]
        
        🌍 \(macroLabel)
        [\(isEN ? "Market sentiment" : "Sentiment du marché")]
        
        🎯 \(synthLabel)
        \(trendLabel) : [\(bullish)]
        \(momentumLabel) : [\(strength)]
        \(positionLabel) : [\(pos)]
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🔹 PART 2 : \(part2Label)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        \(sameStructure)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        🔹 PART 3 : \(part3Label)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        \(sameStructure)
        
        \(dataLabel) :
        """ + prompt + "\n\n" + cleanedExternalData
        
        do {
            print("🔄 [BTCLiveIndicator] Calling OpenAI via Cloud Function, prompt length: \(enhancedPrompt.count)")
            let aiResponse = try await CloudFunctionService.shared.openAIChat(
                messages: [ChatMessagePayload(role: "user", content: enhancedPrompt)]
            )
            print("✅ [BTCLiveIndicator] Response received, length: \(aiResponse.count)")
            return aiResponse
        } catch {
            print("⚠️ [BTCLiveIndicator] Cloud Function error: \(error.localizedDescription)")
            
            let errorMsg: String
            if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
                errorMsg = isEN
                    ? "❌ Network connection error.\n\nCheck your internet connection and try again."
                    : "❌ Erreur de connexion réseau.\n\nVérifiez votre connexion internet et réessayez."
            } else if error.localizedDescription.contains("timeout") {
                errorMsg = isEN
                    ? "⏱️ Connection timeout.\n\nThe server is taking too long to respond. Try again later."
                    : "⏱️ Timeout de connexion.\n\nLe serveur prend trop de temps à répondre. Réessayez plus tard."
            } else if error.localizedDescription.contains("unauthenticated") {
                errorMsg = isEN
                    ? "🔑 Authentication error.\n\nCheck your Firebase connection."
                    : "🔑 Erreur d'authentification.\n\nVérifiez votre connexion Firebase."
            } else {
                errorMsg = isEN
                    ? "⚠️ AI analysis error.\n\nDetails: \(error.localizedDescription)"
                    : "⚠️ Erreur lors de l'analyse IA.\n\nDétails: \(error.localizedDescription)"
            }
            
            return errorMsg
        }
    }
    
    // ✅ OpenAI passe désormais par CloudFunctionService — plus de client local
    
    private func refreshLLMClientFromKeychain() {
        // Plus nécessaire — les appels passent par Firebase Cloud Functions
    }
    
    private func fetchExternalMarketData() async -> String {
        var marketData = ""
        
        // Fetch enhanced funding rate data
        if let fundingData = await fetchFundingRateData() {
            marketData += "💰 FUNDING RATE (CoinGlass-style):\n"
            marketData += fundingData
        }
        
        // Fetch enhanced open interest data
        if let oiData = await fetchOpenInterestData() {
            marketData += "🌊 OPEN INTEREST (CoinGlass-style):\n"
            marketData += oiData
        }
        
        // Fetch real liquidation data
        if let liqData = await fetchLiquidationLevels() {
            marketData += "════════════════════════════════════════\n"
            marketData += "🔥 ZONES DE LIQUIDATION RÉELLES (Binance)\n"
            marketData += "════════════════════════════════════════\n"
            marketData += "Prix actuel: $\(String(format: "%.2f", currentPrice ?? 0))\n\n"
            
            if let shorts = liqData.shorts, shorts.count > 0 {
                marketData += "📉 SUPPORTS (Liquidations SHORT - Prix haussier):\n"
                for (idx, level) in shorts.prefix(3).enumerated() {
                    let distance = abs(currentPrice ?? 0 - level.price) / (currentPrice ?? 1) * 100
                    let diffDollar = level.price - (currentPrice ?? 0)
                    let riskLevel = distance < 1 ? "🔥 TRÈS ÉLEVÉ" : distance < 2 ? "⚠️ ÉLEVÉ" : "✅ MOYEN"
                    
                    marketData += "\n🔸 Zone \(idx + 1):\n"
                    marketData += "   Prix: $\(String(format: "%.2f", level.price))\n"
                    marketData += "   Distance: \(String(format: "%.2f", diffDollar))$ (\(String(format: "%.2f", distance))%)\n"
                    marketData += "   Liquidité: $\(String(format: "%.2f", level.liquidity / 1_000_000))M\n"
                    marketData += "   Risque: \(riskLevel)\n"
                    
                    if distance < 2 && level.liquidity > 100_000_000 {
                        marketData += "   ⚠️⚠️⚠️ DANGER: Zone très proche avec forte liquidité!\n"
                    }
                }
                marketData += "\n"
            }
            
            if let longs = liqData.longs, longs.count > 0 {
                marketData += "📈 RÉSISTANCES (Liquidations LONG - Prix baissier):\n"
                for (idx, level) in longs.prefix(3).enumerated() {
                    let distance = abs(level.price - (currentPrice ?? 0)) / (currentPrice ?? 1) * 100
                    let diffDollar = level.price - (currentPrice ?? 0)
                    let riskLevel = distance < 1 ? "🔥 TRÈS ÉLEVÉ" : distance < 2 ? "⚠️ ÉLEVÉ" : "✅ MOYEN"
                    
                    marketData += "\n🔸 Zone \(idx + 1):\n"
                    marketData += "   Prix: $\(String(format: "%.2f", level.price))\n"
                    marketData += "   Distance: \(String(format: "%.2f", abs(diffDollar)))$ (\(String(format: "%.2f", distance))%)\n"
                    marketData += "   Liquidité: $\(String(format: "%.2f", level.liquidity / 1_000_000))M\n"
                    marketData += "   Risque: \(riskLevel)\n"
                    
                    if distance < 2 && level.liquidity > 100_000_000 {
                        marketData += "   ⚠️⚠️⚠️ DANGER: Zone très proche avec forte liquidité!\n"
                    }
                }
                marketData += "\n"
            }
            
            marketData += "💡 Utilisation:\n"
            marketData += "• Positionner stop-loss au-delà des zones de liqudation\n"
            marketData += "• Prendre profit avant les zones de liquidation massive\n"
            marketData += "• Les zones de forte liquidité sont des aimants pour le prix\n\n"
        }
        
        // Market timing recommendation
        marketData += "⏰ TIMING DE TRADE:\n"
        if let priceChange = priceChange {
            if priceChange > 5 {
                marketData += "⚠️ Hausse forte (+\(String(format: "%.2f", priceChange))%): Possible sur-achat, attendre pullback\n"
            } else if priceChange < -5 {
                marketData += "📉 Baisse forte (\(String(format: "%.2f", priceChange))%): Possible survente, opportunité d'achat\n"
            } else {
                marketData += "✅ Mouvement modéré: Bon moment pour analyser les entrées\n"
            }
        }
        
        marketData += "\n📊 SYNTHÈSE MARCHÉ & ZONES DE LIQUIDATION:\n"
        if let fundingRate = await fetchFundingRate(), let liqData = await fetchLiquidationLevels() {
            let isGoodEntry = fundingRate < 0.05 && fundingRate > -0.05 && abs(priceChange ?? 0) < 5
            
            // Analyze liquidation proximity
            let closestShort = liqData.shorts?.first
            let closestLong = liqData.longs?.first
            let price = currentPrice ?? 0
            
            if let shortPrice = closestShort?.price {
                let shortDist = abs(price - shortPrice) / price * 100
                marketData += "📉 Support le plus proche: $\(String(format: "%.0f", shortPrice)) (-\(String(format: "%.1f", shortDist))%)\n"
                if shortDist < 2 {
                    marketData += "⚠️ ZONE DE SUPPORT TRÈS PROCHE!\n"
                }
            }
            
            if let longPrice = closestLong?.price {
                let longDist = abs(longPrice - price) / price * 100
                marketData += "📈 Résistance la plus proche: $\(String(format: "%.0f", longPrice)) (+\(String(format: "%.1f", longDist))%)\n"
                if longDist < 2 {
                    marketData += "⚠️ ZONE DE RÉSISTANCE TRÈS PROCHE!\n"
                }
            }
            
            if isGoodEntry {
                marketData += "\n✅ CONDITIONS FAVORABLES:\n"
                marketData += "• Funding rate neutre (\(String(format: "%.4f", fundingRate))%)\n"
                marketData += "• Pas de mouvement extrême\n"
                marketData += "• Bon timing pour entrer sur le marché\n"
                marketData += "• Positionner stop-loss en dessous des zones de liquidation\n"
            } else {
                marketData += "\n⚠️ CONDITIONS CAUTIEUSES:\n"
                if abs(fundingRate) > 0.05 {
                    marketData += "• Funding rate extrême (\(String(format: "%.4f", fundingRate))%) → Attendre correction\n"
                }
                if abs(priceChange ?? 0) > 5 {
                    marketData += "• Mouvement volatil récent (\(String(format: "%.2f", abs(priceChange ?? 0)))%)\n"
                }
                marketData += "• Attendre meilleur setup\n"
            }
        }
        
        return marketData
    }
    
    private func fetchFundingRate() async -> Double? {
        do {
            let url = URL(string: "https://fapi.binance.com/fapi/v1/premiumIndex?symbol=BTCUSDT")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            if let rateString = json["lastFundingRate"] as? String,
               let rate = Double(rateString) {
                return rate * 100 // Convert to percentage
            }
        } catch {
            print("⚠️ Error fetching funding rate: \(error)")
        }
        return nil
    }
    
    private func fetchOpenInterest() async -> Double? {
        do {
            let url = URL(string: "https://fapi.binance.com/fapi/v1/openInterest?symbol=BTCUSDT")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            if let oiString = json["openInterest"] as? String,
               let oi = Double(oiString) {
                return oi
            }
        } catch {
            print("⚠️ Error fetching open interest: \(error)")
        }
        return nil
    }
    
    // Enhanced data fetching for CoinGlass-style analysis
    private func fetchFundingRateData() async -> String? {
        guard let rate = await fetchFundingRate() else { return nil }
        
        var analysis = "💰 FUNDING RATE (CoinGlass):\n"
        analysis += "Source: https://www.coinglass.com/FundingRate\n"
        analysis += "Valeur: \(String(format: "%.4f", rate))% par 8h\n\n"
        
        // Interpretation based on CoinGlass standards
        if rate > 0.1 {
            analysis += "🔥 Funding EXTREMEMENT POSITIF (Sentiment très haussier):\n"
            analysis += "• Forte pression haussière sur le marché BTC\n"
            analysis += "• Les longs paient beaucoup les shorts (crowding long)\n"
            analysis += "• Risque élevé de correction/recadrage à court terme\n"
            analysis += "• Signal d'alarme: possibilité de squeeze baissier imminent\n\n"
        } else if rate > 0.05 {
            analysis += "📈 Funding POSITIF (Sentiment haussier modéré):\n"
            analysis += "• Sentiment globalement haussier sur le marché\n"
            analysis += "• Pression d'achat modérée mais significative\n"
            analysis += "• Bénéfique pour les longs si la tendance continue\n\n"
        } else if rate < -0.1 {
            analysis += "❄️ Funding EXTREMEMENT NÉGATIF (Sentiment très baissier):\n"
            analysis += "• Forte pression baissière sur le marché BTC\n"
            analysis += "• Les shorts paient beaucoup les longs (crowding short)\n"
            analysis += "• Risque élevé de rebond/squeeze haussier imminent\n"
            analysis += "• Opportunité potentielle pour les longs\n\n"
        } else if rate < -0.05 {
            analysis += "📉 Funding NÉGATIF (Sentiment baissier modéré):\n"
            analysis += "• Sentiment globalement baissier sur le marché\n"
            analysis += "• Pression de vente modérée mais significative\n"
            analysis += "• Favorable aux shorts si la tendance se maintient\n\n"
        } else {
            analysis += "⚖️ Funding NEUTRE (Sentiment équilibré):\n"
            analysis += "• Pas de pression directionnelle forte sur le marché\n"
            analysis += "• Marché équilibré entre acheteurs/vendeurs\n"
            analysis += "• Pas de signal clair de sur-achat/survente sur les futures\n\n"
        }
        
        return analysis
    }
    
    private func fetchOpenInterestData() async -> String? {
        guard let oi = await fetchOpenInterest() else { return nil }
        
        // Convert to BTC equivalent
        let oiBTC = oi / (currentPrice ?? 65000)
        
        var analysis = "🌊 OPEN INTEREST (CoinGlass):\n"
        analysis += "Source: https://www.coinglass.com/BitcoinOpenInterest\n"
        analysis += "Valeur: \(String(format: "%.2f", oiBTC))K BTC ($\(String(format: "%.0f", oi / 1_000_000))M)\n\n"
        
        // Interpretation based on OI levels
        // Typical BTC OI ranges: 200K-400K BTC is normal, >400K is high, <150K is low
        if oiBTC > 400 {
            analysis += "🔥 Open Interest TRÈS ÉLEVÉ:\n"
            analysis += "• Forte concentration de positions sur le marché BTC\n"
            analysis += "• Risque élevé de liquidation massive (cascade de liquidations)\n"
            analysis += "• Volatilité potentielle accrue et mouvements violents possibles\n"
            analysis += "• Signal d'alerte: marché congestionné, prudence requise\n\n"
        } else if oiBTC < 150 {
            analysis += "📉 Open Interest FAIBLE:\n"
            analysis += "• Peu de positions ouvertes sur le marché BTC\n"
            analysis += "• Marché peu risqué mais moins liquide\n"
            analysis += "• Opportunités de trading limitées, faible engagement\n"
            analysis += "• Mouvements de prix potentiellement moins fiables\n\n"
        } else {
            analysis += "✅ Open Interest NORMAL:\n"
            analysis += "• Niveau de positions sain sur le marché BTC\n"
            analysis += "• Bon équilibre liquidité/risque\n"
            analysis += "• Marché actif sans sur-concentration\n\n"
        }
        
        // Add context about OI vs Price relationship
        if let priceChange = priceChange {
            analysis += "📊 RELATION OI vs PRIX:\n"
            if priceChange > 0 && oiBTC > 300 {
                analysis += "• Prix ↗️ + OI élevé = Confirmation haussière forte ✓\n"
            } else if priceChange < 0 && oiBTC > 300 {
                analysis += "• Prix ↘️ + OI élevé = Pression baissière forte ⚠️\n"
            } else if priceChange > 0 && oiBTC < 200 {
                analysis += "• Prix ↗️ + OI faible = Hausse fragile (peu d'engagement)\n"
            } else if priceChange < 0 && oiBTC < 200 {
                analysis += "• Prix ↘️ + OI faible = Baisse modérée (engagement limité)\n"
            }
        }
        
        return analysis
    }
    
    private func extractOnlyCoinGlassData(_ fullData: String) -> String {
        // Extract only Funding Rate and Open Interest sections
        let lines = fullData.components(separatedBy: "\n")
        var extractedData = ""
        var inSection = false
        var sectionBuffer = ""
        
        for line in lines {
            if line.contains("FUNDING RATE") || line.contains("OPEN INTEREST") {
                if inSection && !sectionBuffer.isEmpty {
                    extractedData += sectionBuffer + "\n\n"
                }
                inSection = true
                sectionBuffer = line + "\n"
            } else if inSection {
                if line.contains("═════") || line.contains("🔥 ZONES") {
                    inSection = false
                    if !sectionBuffer.isEmpty {
                        extractedData += sectionBuffer
                        sectionBuffer = ""
                    }
                } else {
                    sectionBuffer += line + "\n"
                }
            }
        }
        
        if inSection && !sectionBuffer.isEmpty {
            extractedData += sectionBuffer
        }
        
        return extractedData.isEmpty ? "Données CoinGlass en cours de chargement..." : extractedData
    }
    
    private func fetchLiquidationLevels() async -> LiquidationData? {
        // Note: Binance doesn't provide direct liquidation heatmap API
        // We'll use volume/liquidity data to estimate liquidation zones
        // Based on: https://github.com/StephanAkkerman/liquidations-chart
        
        guard let currentPrice = currentPrice else { return nil }
        
        do {
            // Fetch order book depth (to estimate liquidity zones)
            let url = URL(string: "https://api.binance.com/api/v3/depth?symbol=BTCUSDT&limit=100")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            // Parse bids (short liquidations - support levels)
            var shortLiquidationLevels: [LiquidationLevel] = []
            if let bids = json["bids"] as? [[String]] {
                var cumulativeLiquidity: Double = 0
                for bid in bids.prefix(50) {
                    if let price = Double(bid[0]), let qty = Double(bid[1]) {
                        cumulativeLiquidity += price * qty
                        if cumulativeLiquidity > 10_000_000 { // Filter for significant liquidity
                            shortLiquidationLevels.append(LiquidationLevel(
                                price: price,
                                liquidity: cumulativeLiquidity
                            ))
                        }
                    }
                }
            }
            
            // Parse asks (long liquidations - resistance levels)
            var longLiquidationLevels: [LiquidationLevel] = []
            if let asks = json["asks"] as? [[String]] {
                var cumulativeLiquidity: Double = 0
                for ask in asks.prefix(50) {
                    if let price = Double(ask[0]), let qty = Double(ask[1]) {
                        cumulativeLiquidity += price * qty
                        if cumulativeLiquidity > 10_000_000 { // Filter for significant liquidity
                            longLiquidationLevels.append(LiquidationLevel(
                                price: price,
                                liquidity: cumulativeLiquidity
                            ))
                        }
                    }
                }
            }
            
            // Sort shorts by distance from current price (closest first)
            let sortedShorts = shortLiquidationLevels.sorted { abs($0.price - currentPrice) < abs($1.price - currentPrice) }
            
            // Sort longs by distance from current price (closest first)
            let sortedLongs = longLiquidationLevels.sorted { abs($0.price - currentPrice) < abs($1.price - currentPrice) }
            
            return LiquidationData(
                shorts: sortedShorts.prefix(5).map { $0 },
                longs: sortedLongs.prefix(5).map { $0 }
            )
        } catch {
            print("⚠️ Error fetching liquidation levels: \(error)")
            return nil
        }
    }
    
    private func generateDetailedAnalysis() -> String {
        var analysis = "1️⃣ RÉSUMÉ TECHNIQUE:\n"
        analysis += "────────────────────────────────────────\n\n"
        
        // Technical summary
        let h1 = timeframeData.first(where: { $0.name == "1h" })
        let h4 = timeframeData.first(where: { $0.name == "4h" })
        let d1 = timeframeData.first(where: { $0.name == "1d" })
        let w1 = timeframeData.first(where: { $0.name == "1w" })
        
        var bullishCount = 0
        var bearishCount = 0
        var neutralCount = 0
        
        analysis += "📊 ÉTAT DES INDICATEURS:\n\n"
        for tf in [h1, h4, d1, w1].compactMap({ $0 }) {
            analysis += "\(tf.name): "
            if tf.recommendation == "BUY" {
                analysis += "✅ Haussier"
                bullishCount += 1
            } else if tf.recommendation == "SELL" {
                analysis += "❌ Baissier"
                bearishCount += 1
            } else {
                analysis += "⚪ Neutre"
                neutralCount += 1
            }
            analysis += " (RSI:\(formatValue(tf.rsi, decimals: 1)), MACD:\(formatValue(tf.macd, decimals: 4)), VMC:\(formatValue(tf.vmc, decimals: 1)))\n"
        }
        
        analysis += "\n🔗 CONVERGENCE:\n"
        if bullishCount >= 3 {
            analysis += "✅ Forte convergence HAUSSIÈRE (3-4 timeframes)\n"
        } else if bearishCount >= 3 {
            analysis += "❌ Forte convergence BAISSIÈRE (3-4 timeframes)\n"
        } else if neutralCount >= 3 {
            analysis += "⚪ Divergence - Marché en consolidation\n"
        } else {
            analysis += "⚠️ Signaux mixtes - Attendre clarification\n"
        }
        
        analysis += "\n\n2️⃣ CONTEXTE LIQUIDATION & RISQUE:\n"
        analysis += "────────────────────────────────────────\n"
        
        if let price = currentPrice {
            analysis += "Prix actuel: $\(String(format: "%.2f", price))\n\n"
            analysis += "📊 Zones de liquidation à récupérer...\n"
            analysis += "(Les données exactes seront intégrées dans l'analyse complète)\n"
        }
        
        analysis += "\n\n3️⃣ CONTEXTE MACRO:\n"
        analysis += "────────────────────────────────────────\n"
        analysis += "Funding Rate: À vérifier\n"
        analysis += "Open Interest: À vérifier\n"
        
        analysis += "\n\n4️⃣ RECOMMANDATION FINALE:\n"
        analysis += "────────────────────────────────────────\n"
        
        // Final recommendation
        if bullishCount >= 3 {
            analysis += "✅ ACHETEZ MAINTENANT\n\n"
            analysis += "Niveau d'entrée: $\(String(format: "%.2f", currentPrice ?? 0))\n"
            analysis += "Stop-loss: -3% du prix d'entrée\n"
            analysis += "Take-profit: +5% du prix d'entrée\n"
            analysis += "Confiance: 7/10\n\n"
            analysis += "5️⃣ RÉSERVE:\nSi RSI > 75 ou MACD négatif sur 2+ timeframes, annuler.\n"
        } else if bearishCount >= 3 {
            analysis += "❌ VENDEZ MAINTENANT\n\n"
            analysis += "Niveau d'entrée: $\(String(format: "%.2f", currentPrice ?? 0))\n"
            analysis += "Stop-loss: +3% du prix d'entrée\n"
            analysis += "Take-profit: -5% du prix d'entrée\n"
            analysis += "Confiance: 7/10\n\n"
            analysis += "5️⃣ RÉSERVE:\nSi RSI < 25 ou MACD positif sur 2+ timeframes, annuler.\n"
        } else {
            analysis += "⏸️ ATTENDEZ\n\n"
            analysis += "Raison: Signaux mixtes sur les timeframes\n"
            analysis += "Action: Attendre convergence claire des indicateurs\n"
            analysis += "Confiance: N/A (pas de trade)\n\n"
            analysis += "5️⃣ RÉSERVE:\nEntrer en position dès qu'une convergence claire apparaît.\n"
        }
        
        return analysis
    }
    
    private func generateIndicatorBasedAnalysis() -> String {
        guard !timeframeData.isEmpty else {
            return "❌ Données insuffisantes pour l'analyse."
        }
        
        var analysis = "🤖 ANALYSE TECHNIQUE BTC/USDT\n\n"
        
        // Analyze RSI across timeframes
        analysis += "📊 RSI (Relative Strength Index):\n"
        var oversoldCount = 0
        var overboughtCount = 0
        for tf in timeframeData {
            if let rsi = tf.rsi {
                if rsi < 30 {
                    oversoldCount += 1
                    analysis += "  • \(tf.name): \(formatValue(rsi, decimals: 2)) - Zone de survente\n"
                } else if rsi > 70 {
                    overboughtCount += 1
                    analysis += "  • \(tf.name): \(formatValue(rsi, decimals: 2)) - Zone de surachat\n"
                } else {
                    analysis += "  • \(tf.name): \(formatValue(rsi, decimals: 2)) - Zone neutre\n"
                }
            }
        }
        
        analysis += "\n📈 MACD (Moving Average Convergence Divergence):\n"
        var bullishMacdCount = 0
        for tf in timeframeData {
            if let macd = tf.macd {
                if macd > 0 {
                    bullishMacdCount += 1
                    analysis += "  • \(tf.name): \(formatValue(macd, decimals: 4)) - Momentum positif\n"
                } else {
                    analysis += "  • \(tf.name): \(formatValue(macd, decimals: 4)) - Momentum négatif\n"
                }
            }
        }
        
        analysis += "\n🔮 VMC (Volume Market Compressor):\n"
        var extremeVmcCount = 0
        for tf in timeframeData {
            if let vmc = tf.vmc {
                if abs(vmc) > 40 {
                    extremeVmcCount += 1
                    analysis += "  • \(tf.name): \(formatValue(vmc, decimals: 2)) - Signal extrême\n"
                } else {
                    analysis += "  • \(tf.name): \(formatValue(vmc, decimals: 2)) - Zone normale\n"
                }
            }
        }
        
        analysis += "\n📉 TRIX (Triple Exponential Average):\n"
        for tf in timeframeData {
            if let trix = tf.trix {
                if trix > 0 {
                    analysis += "  • \(tf.name): \(formatValue(trix, decimals: 4)) - Accélération haussière\n"
                } else {
                    analysis += "  • \(tf.name): \(formatValue(trix, decimals: 4)) - Accélération baissière\n"
                }
            }
        }
        
        analysis += "\n🌊 ODP (Oscillator Divergence Profile):\n"
        for tf in timeframeData {
            if let odp = tf.odp {
                if odp > 60 {
                    analysis += "  • \(tf.name): \(formatValue(odp, decimals: 2)) - Sur-achat\n"
                } else if odp < -60 {
                    analysis += "  • \(tf.name): \(formatValue(odp, decimals: 2)) - Sur-vente\n"
                } else {
                    analysis += "  • \(tf.name): \(formatValue(odp, decimals: 2)) - Neutre\n"
                }
            }
        }
        
        // Synthesis
        analysis += "\n\n🎯 SYNTHÈSE:\n"
        if oversoldCount >= 2 {
            analysis += "• Conditions de survente détectées sur plusieurs timeframes\n"
        }
        if overboughtCount >= 2 {
            analysis += "• Conditions de surachat détectées sur plusieurs timeframes\n"
        }
        if bullishMacdCount >= 3 {
            analysis += "• Momentum haussier dominant sur la plupart des timeframes\n"
        } else if bullishMacdCount <= 1 {
            analysis += "• Momentum baissier dominant\n"
        }
        if extremeVmcCount >= 2 {
            analysis += "• Signaux VMC extrêmes suggèrent une volatilité élevée\n"
        }
        
        analysis += "\n⚠️ Note: Cette analyse est automatique. Consultez d'autres indicateurs avant de trader."
        
        return analysis
    }
}

struct BinanceTicker: Codable {
    let price: String
}

// MARK: - Timeframe Selector View
struct TimeframeSelectorView: View {
    let availableTimeframes: [String]
    @Binding var selectedTimeframes: Set<String>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header info
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(t("slectionnezLesTimeframes"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(t("analyse"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Timeframe grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(availableTimeframes, id: \.self) { tf in
                        TimeframeCard(
                            timeframe: tf,
                            isSelected: selectedTimeframes.contains(tf)
                        ) {
                            toggleTimeframe(tf)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Summary
                VStack(spacing: 8) {
                    Text("\(selectedTimeframes.count) timeframes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTimeframes).sorted(), id: \.self) { tf in
                            Text(tf)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        if selectedTimeframes.isEmpty {
                            // At least one must be selected
                            selectedTimeframes = ["1h"]
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(t("add"))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    Button {
                        selectedTimeframes = ["1h", "4h", "1d", "1w"]
                    } label: {
                        Text(t("ai"))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
            .navigationTitle(t("timeframes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleTimeframe(_ tf: String) {
        if selectedTimeframes.contains(tf) {
            selectedTimeframes.remove(tf)
        } else {
            selectedTimeframes.insert(tf)
        }
    }
}

struct TimeframeCard: View {
    let timeframe: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text(timeframe)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(timeframeName(timeframe))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isSelected ?
                LinearGradient(
                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) : nil
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func timeframeName(_ tf: String) -> String {
        switch tf {
        case "5m": return "5 minutes"
        case "15m": return "15 minutes"
        case "1h": return "1 heure"
        case "4h": return "4 heures"
        case "1d": return "1 jour"
        case "1w": return "1 semaine"
        default: return tf
        }
    }
}
