//
//  CombinedIndicatorsDashboardView.swift
//  Journal de trading 2025
//
//  Dashboard combiné VMC + RSI Multi-Timeframe
//

import SwiftUI

struct CombinedIndicatorsDashboardView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let vmcSnapshot: VMCSnapshot
    let rsiSnapshot: RSISnapshot
    let symbol: String
    @State private var showFullScreen = false
    
    init(vmcSnapshot: VMCSnapshot, rsiSnapshot: RSISnapshot, symbol: String = "BTCUSDT") {
        self.vmcSnapshot = vmcSnapshot
        self.rsiSnapshot = rsiSnapshot
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
        VStack(spacing: 12) {
            // Header avec signaux globaux
            HStack {
                // VMC Global
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("vmc"))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    HStack(spacing: 4) {
                        if vmcSnapshot.isTurningUp {
                            Text("▲") // TODO: Traduire avec clé appropriée
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else if vmcSnapshot.isTurningDown {
                            Text("▼") // TODO: Traduire avec clé appropriée
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        Text(String(format: "%.1f", vmcSnapshot.globalScore))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    Text(vmcSnapshot.globalSignal.displayName)
                        .font(.caption2)
                        .foregroundColor(vmcSnapshot.globalSignal.color)
                }
                
                Spacer()
                
                // RSI Global
                VStack(alignment: .trailing, spacing: 4) {
                    Text(t("rsi"))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    HStack(spacing: 4) {
                        if rsiSnapshot.isTurningUp {
                            Text("▲") // TODO: Traduire avec clé appropriée
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else if rsiSnapshot.isTurningDown {
                            Text("▼") // TODO: Traduire avec clé appropriée
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        Text(String(format: "%.0f", rsiSnapshot.globalRSI))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(rsiGradientColor(rsiSnapshot.globalRSI))
                    }
                    Text(rsiSnapshot.globalSignal.displayName)
                        .font(.caption2)
                        .foregroundColor(rsiSnapshot.globalSignal.color)
                }
                
                Spacer()
                
                // Bouton plein écran
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
            )
            
            // Colonnes combinées VMC + RSI
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Colonne Ticker
                    tickerColumn
                    
                    // Colonne Global VMC
                    if vmcSnapshot.globalScore != 0 {
                        globalColumn(
                            value: vmcSnapshot.globalScore,
                            signal: vmcSnapshot.globalSignal.rawValue,
                            color: vmcSnapshot.globalSignal.color,
                            isTurningUp: vmcSnapshot.isTurningUp,
                            label: "VMC"
                        )
                    }
                    
                    // Colonne Global RSI
                    globalColumn(
                        value: rsiSnapshot.globalRSI,
                        signal: rsiSnapshot.globalSignal.rawValue,
                        color: rsiSnapshot.globalSignal.color,
                        isTurningUp: rsiSnapshot.isTurningUp,
                        label: "RSI"
                    )
                    
                    // Colonnes par timeframe (VMC + RSI côte à côte)
                    ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                        if let vmcReading = vmcSnapshot.readings[tf],
                           let rsiReading = rsiSnapshot.readings[tf] {
                            HStack(spacing: 4) {
                                // Colonne VMC
                                timeframeColumn(
                                    reading: vmcReading,
                                    value: vmcReading.value,
                                    status: vmcReading.status.rawValue,
                                    color: vmcReading.status.color,
                                    timeframe: tf,
                                    isVMC: true
                                )
                                
                                // Colonne RSI
                                timeframeColumn(
                                    reading: rsiReading,
                                    value: rsiReading.value,
                                    status: rsiReading.status.rawValue,
                                    color: rsiReading.status.color,
                                    timeframe: tf,
                                    isVMC: false
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Components
    
    private var tickerColumn: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 4) {
                let parts = symbol.replacingOccurrences(of: "USDT", with: "").components(separatedBy: "USDT")
                let ticker = parts.first ?? symbol
                Text(ticker)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text(t("mexc"))
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.7))
            }
            .frame(height: 50)
            .padding(.vertical, 6)
            Spacer()
        }
        .frame(width: 50)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    @ViewBuilder
    private func globalColumn(
        value: Double,
        signal: String,
        color: Color,
        isTurningUp: Bool,
        label: String
    ) -> some View {
        let gradient = label == "VMC" ? VMCDashboardMTFView.vmcGradient(value) : rsiGradient(value)
        
        VStack(spacing: 6) {
            Text(signal)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(height: 20)
                .padding(.top, 4)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                    
                    if label == "VMC" {
                        // VMC : barre centrée (positif vers le haut, négatif vers le bas)
                        if value > 0 {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 4,
                                    height: min(abs(value) * 0.6, geometry.size.height * 0.9)
                                )
                                .offset(y: -min(abs(value) * 0.3, geometry.size.height * 0.45))
                        } else {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 4,
                                    height: min(abs(value) * 0.6, geometry.size.height * 0.9)
                                )
                                .offset(y: min(abs(value) * 0.3, geometry.size.height * 0.45))
                        }
                    } else {
                        // RSI : barre depuis le bas (0-100)
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(value * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: geometry.size.height * 0.45 - min(value * 0.4, geometry.size.height * 0.45))
                    }
                }
            }
            .frame(height: 90)
            
            VStack(spacing: 2) {
                if isTurningUp {
                    Text("▲") // TODO: Traduire avec clé appropriée
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(t("assistant"))
                        .font(.caption2)
                }
                Text(String(format: label == "VMC" ? "%.1f" : "%.0f", value))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .monospacedDigit()
                if !isTurningUp {
                    Text("▼") // TODO: Traduire avec clé appropriée
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(t("assistant"))
                        .font(.caption2)
                }
            }
            .frame(height: 40)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white)
                .frame(height: 18)
                .padding(.bottom, 4)
        }
        .frame(width: 50)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    @ViewBuilder
    private func timeframeColumn(
        reading: Any, // Accepte VMCReading ou RSIReading
        value: Double,
        status: String,
        color: Color,
        timeframe: VMCTimeframe,
        isVMC: Bool
    ) -> some View {
        let gradient = isVMC ? VMCDashboardMTFView.vmcGradient(value) : rsiGradient(value)
        
        VStack(spacing: 6) {
            Text(status)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(height: 18)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                    
                    if isVMC {
                        // VMC : barre centrée
                        if value > 0 {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 2,
                                    height: min(abs(value) * 0.6, geometry.size.height * 0.9)
                                )
                                .offset(y: -min(abs(value) * 0.3, geometry.size.height * 0.45))
                        } else {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 2,
                                    height: min(abs(value) * 0.6, geometry.size.height * 0.9)
                                )
                                .offset(y: min(abs(value) * 0.3, geometry.size.height * 0.45))
                        }
                    } else {
                        // RSI : barre depuis le bas (0-100)
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 2,
                                height: min(value * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: geometry.size.height * 0.45 - min(value * 0.4, geometry.size.height * 0.45))
                    }
                }
            }
            .frame(height: 90)
            
            Text(String(format: isVMC ? "%.1f" : "%.0f", value))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .monospacedDigit()
                .frame(height: 20)
            
            Text(timeframe.displayName)
                .font(.caption2)
                .foregroundColor(.white)
                .frame(height: 16)
                .padding(.bottom, 2)
        }
        .frame(width: 40)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    // MARK: - RSI Gradient
    
    /// Gradient RSI (rouge → violet → bleu) selon le Pine Script
    static func rsiGradient(_ value: Double) -> LinearGradient {
        return rsiGradientSimple(value)
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
    
    // MARK: - Full Screen View
    
    private var fullScreenView: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea(.all)
                    
                    VStack(spacing: 12) {
                        // Header compact
                        fullScreenHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        // Colonnes combinées
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                tickerColumn
                                
                                if vmcSnapshot.globalScore != 0 {
                                    fullScreenGlobalColumn(
                                        value: vmcSnapshot.globalScore,
                                        signal: vmcSnapshot.globalSignal.rawValue,
                                        color: vmcSnapshot.globalSignal.color,
                                        isTurningUp: vmcSnapshot.isTurningUp,
                                        label: "VMC"
                                    )
                                }
                                
                                fullScreenGlobalColumn(
                                    value: rsiSnapshot.globalRSI,
                                    signal: rsiSnapshot.globalSignal.rawValue,
                                    color: rsiSnapshot.globalSignal.color,
                                    isTurningUp: rsiSnapshot.isTurningUp,
                                    label: "RSI"
                                )
                                
                                ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                                    if let vmcReading = vmcSnapshot.readings[tf],
                                       let rsiReading = rsiSnapshot.readings[tf] {
                                        HStack(spacing: 6) {
                                            fullScreenTimeframeColumn(
                                                value: vmcReading.value,
                                                status: vmcReading.status.rawValue,
                                                color: vmcReading.status.color,
                                                timeframe: tf,
                                                isVMC: true
                                            )
                                            fullScreenTimeframeColumn(
                                                value: rsiReading.value,
                                                status: rsiReading.status.rawValue,
                                                color: rsiReading.status.color,
                                                timeframe: tf,
                                                isVMC: false
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: geometry.size.height * 0.65)
                        
                        // Stats et légende
                        VStack(spacing: 8) {
                            fullScreenStats
                                .padding(.horizontal, 16)
                            fullScreenLegend
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
    
    // MARK: - Full Screen Components
    
    private var fullScreenHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("vmc"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                HStack(spacing: 6) {
                    if vmcSnapshot.isTurningUp {
                        Text("▲") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else if vmcSnapshot.isTurningDown {
                        Text("▼") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    Text(String(format: "%.1f", vmcSnapshot.globalScore))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                Text(vmcSnapshot.globalSignal.displayName)
                    .font(.subheadline)
                    .foregroundColor(vmcSnapshot.globalSignal.color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(t("rsi"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                HStack(spacing: 6) {
                    if rsiSnapshot.isTurningUp {
                        Text("▲") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else if rsiSnapshot.isTurningDown {
                        Text("▼") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    Text(String(format: "%.0f", rsiSnapshot.globalRSI))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(rsiGradientColor(rsiSnapshot.globalRSI))
                }
                Text(rsiSnapshot.globalSignal.displayName)
                    .font(.subheadline)
                    .foregroundColor(rsiSnapshot.globalSignal.color)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    @ViewBuilder
    private func fullScreenGlobalColumn(
        value: Double,
        signal: String,
        color: Color,
        isTurningUp: Bool,
        label: String
    ) -> some View {
        let gradient = label == "VMC" ? VMCDashboardMTFView.vmcGradient(value) : rsiGradient(value)
        
        VStack(spacing: 8) {
            Text(signal)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(height: 24)
                .padding(.top, 4)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                    
                    if label == "VMC" {
                        if value > 0 {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 4,
                                    height: min(abs(value) * 0.8, geometry.size.height * 0.9)
                                )
                                .offset(y: -min(abs(value) * 0.4, geometry.size.height * 0.45))
                        } else {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 4,
                                    height: min(abs(value) * 0.8, geometry.size.height * 0.9)
                                )
                                .offset(y: min(abs(value) * 0.4, geometry.size.height * 0.45))
                        }
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(value * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: geometry.size.height * 0.45 - min(value * 0.4, geometry.size.height * 0.45))
                    }
                }
            }
            .frame(height: 140)
            
            VStack(spacing: 4) {
                if isTurningUp {
                    Text("▲") // TODO: Traduire avec clé appropriée
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(t("assistant"))
                        .font(.caption)
                }
                Text(String(format: label == "VMC" ? "%.1f" : "%.0f", value))
                    .font(.headline)
                    .fontWeight(.bold)
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
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
                .frame(height: 20)
                .padding(.bottom, 4)
        }
        .frame(width: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    @ViewBuilder
    private func fullScreenTimeframeColumn(
        value: Double,
        status: String,
        color: Color,
        timeframe: VMCTimeframe,
        isVMC: Bool
    ) -> some View {
        let gradient = isVMC ? VMCDashboardMTFView.vmcGradient(value) : rsiGradient(value)
        
        VStack(spacing: 8) {
            Text(status)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(height: 24)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 4)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                    
                    if isVMC {
                        if value > 0 {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 4,
                                    height: min(abs(value) * 0.8, geometry.size.height * 0.9)
                                )
                                .offset(y: -min(abs(value) * 0.4, geometry.size.height * 0.45))
                        } else {
                            Rectangle()
                                .fill(gradient)
                                .frame(
                                    width: geometry.size.width - 4,
                                    height: min(abs(value) * 0.8, geometry.size.height * 0.9)
                                )
                                .offset(y: min(abs(value) * 0.4, geometry.size.height * 0.45))
                        }
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(value * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: geometry.size.height * 0.45 - min(value * 0.4, geometry.size.height * 0.45))
                    }
                }
            }
            .frame(height: 140)
            
            Text(String(format: isVMC ? "%.1f" : "%.0f", value))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .monospacedDigit()
                .frame(height: 30)
            
            Text(timeframe.displayName)
                .font(.caption)
                .foregroundColor(.white)
                .frame(height: 20)
                .padding(.bottom, 4)
        }
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    private var fullScreenStats: some View {
        HStack(spacing: 12) {
            StatCardCompact(
                title: "Timeframes",
                value: "\(max(vmcSnapshot.readings.count, rsiSnapshot.readings.count))",
                color: .blue
            )
            StatCardCompact(
                title: "VMC Signal",
                value: vmcSnapshot.globalSignal.displayName,
                color: vmcSnapshot.globalSignal.color
            )
            StatCardCompact(
                title: "RSI Signal",
                value: rsiSnapshot.globalSignal.displayName,
                color: rsiSnapshot.globalSignal.color
            )
        }
    }
    
    private var fullScreenLegend: some View {
        HStack(spacing: 16) {
            Text(t("vmc"))
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            legendItemCompact(color: .green, text: "Achat")
            legendItemCompact(color: Color.yellow.opacity(0.7), text: "Baissier")
            legendItemCompact(color: .gray, text: "Neutre")
            legendItemCompact(color: .orange, text: "Haussier")
            legendItemCompact(color: .red, text: "Vente")
            
            Text(t("rsi"))
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            legendItemCompact(color: .blue, text: "Oversold")
            legendItemCompact(color: Color(red: 0.54, green: 0.17, blue: 0.89), text: "Neutre")
            legendItemCompact(color: .red, text: "Overbought")
        }
        .font(.caption)
        .padding(.vertical, 4)
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
    
    private func legendItemCompact(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - RSI Gradient Helper

extension CombinedIndicatorsDashboardView {
    /// Gradient RSI simplifié (rouge → violet → bleu)
    static func rsiGradientSimple(_ value: Double) -> LinearGradient {
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
}
