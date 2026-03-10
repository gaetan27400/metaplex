//
//  VMCDashboardMTFView.swift
//  Journal de trading 2025
//
//  Vue Dashboard VMC Multi-Timeframe (style TradingView)
//

import SwiftUI
import UIKit

struct VMCDashboardMTFView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let snapshot: VMCSnapshot
    let symbol: String
    @State private var selectedTimeframe: VMCTimeframe?
    @State private var showFullScreen = false
    
    init(snapshot: VMCSnapshot, symbol: String = "BTCUSDT") {
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
            // Header avec signal global et VMC global
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
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                        )
                }
            }
            
            // Colonnes horizontales (style TradingView)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Colonne Ticker (symbole)
                    tickerColumn
                    
                    // Colonne Global
                    if snapshot.globalScore != 0 {
                        globalColumn
                    }
                    
                    // Colonnes par timeframe (de droite à gauche comme TradingView)
                    ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                        if let reading = snapshot.readings[tf] {
                            timeframeColumn(reading: reading, timeframe: tf)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 220)
            
            // Légende
            legendView
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
    }
    
    // MARK: - Full Screen View
    
    private var fullScreenView: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Fond plein écran
                    Color.black
                        .ignoresSafeArea(.all)
                    
                    VStack(spacing: 12) {
                        // Header compact avec signal global et VMC global
                        fullScreenCompactHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        // Layout principal : Header + Colonnes + Stats en bas
                        HStack(spacing: 12) {
                            // Colonnes VMC (scroll horizontal si nécessaire)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Colonne Ticker
                                    fullScreenTickerColumn
                                    
                                    // Colonne Global
                                    if snapshot.globalScore != 0 {
                                        fullScreenGlobalColumn
                                    }
                                    
                                    // Colonnes par timeframe
                                    ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                                        if let reading = snapshot.readings[tf] {
                                            fullScreenTimeframeColumn(reading: reading, timeframe: tf)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .frame(height: geometry.size.height * 0.65)
                        
                        // Stats et légende en bas (compact)
                        VStack(spacing: 8) {
                            fullScreenCompactStats
                                .padding(.horizontal, 16)
                            
                            fullScreenLegendView
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
                        // Restaurer l'orientation avant de fermer
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
                // Verrouiller en paysage uniquement pour cette vue
                AppDelegate.orientationLock = .landscapeLeft
                // Forcer la rotation
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
                // Restaurer toutes les orientations autorisées
                AppDelegate.orientationLock = .all
            }
        }
    }
    
    // Header compact pour plein écran
    private var fullScreenCompactHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("signalGlobal"))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text(snapshot.globalSignal.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(snapshot.globalSignal.color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(t("vmc"))
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
                    Text(String(format: "%.1f", snapshot.globalScore))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(.orange)
                }
            }
            
            // Indicateurs extrêmes (compact)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("extrmesBas"))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "%.1f%%", snapshot.extremeLowPercent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("extrmesHauts"))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "%.1f%%", snapshot.extremeHighPercent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // Stats compactes pour plein écran
    private var fullScreenCompactStats: some View {
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
                Text(t("vmc"))
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
                    Text(String(format: "%.1f", snapshot.globalScore))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Full Screen Header
    
    private var fullScreenHeaderView: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("signalGlobal"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    Text(snapshot.globalSignal.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(snapshot.globalSignal.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    Text(t("vmc"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    HStack(spacing: 8) {
                        if snapshot.isTurningUp {
                            Text("▲") // TODO: Traduire avec clé appropriée
                                .font(.title2)
                                .foregroundColor(.green)
                        } else if snapshot.isTurningDown {
                            Text("▼") // TODO: Traduire avec clé appropriée
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        Text(String(format: "%.1f", snapshot.globalScore))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Indicateurs supplémentaires
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("extrmesBas"))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "%.1f%%", snapshot.extremeLowPercent))
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("extrmesHauts"))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "%.1f%%", snapshot.extremeHighPercent))
                        .font(.title3)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Ticker Column
    
    private var tickerColumn: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Symbole
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
        let gradient = Self.vmcGradient(snapshot.globalScore)
        let isTurningUp = snapshot.isTurningUp
        
        return VStack(spacing: 8) {
            // Label en haut (signal)
            Text(snapshot.globalSignal.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(snapshot.globalSignal.color)
                .frame(height: 24)
                .padding(.top, 4)
            
            // Barre VMC
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    // Ligne zéro
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                        .offset(y: 0)
                    
                    // Barre
                    if snapshot.globalScore > 0 {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(snapshot.globalScore) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: -min(abs(snapshot.globalScore) * 0.4, geometry.size.height * 0.45))
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(snapshot.globalScore) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: min(abs(snapshot.globalScore) * 0.4, geometry.size.height * 0.45))
                    }
                }
            }
            .frame(height: 110)
            
            // Valeur au milieu avec flèche
            VStack(spacing: 4) {
                if isTurningUp {
                    Text("▲") // TODO: Traduire avec clé appropriée
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(t("assistant"))
                        .font(.caption)
                }
                Text(String(format: "%.1f", snapshot.globalScore))
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
            
            // Label en bas
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
    private func timeframeColumn(reading: VMCReading, timeframe: VMCTimeframe) -> some View {
        let gradient = Self.vmcGradient(reading.value)
        let previousValue = reading.value // TODO: Comparer avec valeur précédente pour flèche
        let isTurningUp = previousValue > 0 // Simplifié pour l'instant
        
        return VStack(spacing: 8) {
            // Label en haut (statut)
            Text(reading.status.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(reading.status.color)
                .frame(height: 24)
                .padding(.top, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Barre VMC
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    // Ligne zéro
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 1)
                        .offset(y: 0)
                    
                    // Barre
                    if reading.value > 0 {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(reading.value) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: -min(abs(reading.value) * 0.4, geometry.size.height * 0.45))
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(reading.value) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: min(abs(reading.value) * 0.4, geometry.size.height * 0.45))
                    }
                }
            }
            .frame(height: 110)
            
            // Valeur au milieu avec flèche
            VStack(spacing: 4) {
                if isTurningUp {
                    Text("▲") // TODO: Traduire avec clé appropriée
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(t("assistant"))
                        .font(.caption)
                }
                Text(String(format: "%.1f", reading.value))
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
            
            // Label en bas (timeframe)
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
    
    // MARK: - Gradient VMC
    
    static func vmcGradient(_ value: Double) -> LinearGradient {
        let normalized = max(-100, min(100, value))
        
        if normalized >= 50 {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.27, blue: 0.0),
                    Color(red: 0.55, green: 0.0, blue: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= 20 {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.55, blue: 0.0),
                    Color(red: 1.0, green: 0.27, blue: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= 0 {
            return LinearGradient(
                colors: [
                    Color(red: 0.54, green: 0.17, blue: 0.89),
                    Color(red: 1.0, green: 0.55, blue: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= -20 {
            return LinearGradient(
                colors: [
                    Color(red: 0.29, green: 0.0, blue: 0.51),
                    Color(red: 0.54, green: 0.17, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= -50 {
            return LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.0, blue: 0.55),
                    Color(red: 0.29, green: 0.0, blue: 0.51)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.24, blue: 0.55),
                    Color(red: 0.55, green: 0.0, blue: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Legend
    
    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: .green, text: "Achat")
            legendItem(color: Color.yellow.opacity(0.7), text: "Baissier")
            legendItem(color: .gray, text: "Neutre")
            legendItem(color: .orange, text: "Haussier")
            legendItem(color: .red, text: "Vente")
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
    
    // MARK: - Full Screen Components
    
    private var fullScreenStatsView: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Timeframes Actifs",
                value: "\(snapshot.readings.count)",
                color: .blue
            )
            StatCard(
                title: "Signal",
                value: snapshot.globalSignal.displayName,
                color: snapshot.globalSignal.color
            )
            StatCard(
                title: "Tendance",
                value: snapshot.isTurningUp ? "▲ Hausse" : snapshot.isTurningDown ? "▼ Baisse" : "→ Stable",
                color: snapshot.isTurningUp ? .green : snapshot.isTurningDown ? .red : .gray
            )
        }
    }
    
    private struct StatCard: View {
        let title: String
        let value: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
            )
        }
    }
    
    private var fullScreenTickerColumn: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 8) {
                let parts = symbol.replacingOccurrences(of: "USDT", with: "").components(separatedBy: "USDT")
                let ticker = parts.first ?? symbol
                Text(ticker)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text(t("mexc"))
                    .font(.subheadline)
                    .foregroundColor(.orange.opacity(0.7))
            }
            .frame(height: 80)
            .padding(.vertical, 12)
            
            Spacer()
        }
        .frame(width: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    private var fullScreenGlobalColumn: some View {
        let gradient = Self.vmcGradient(snapshot.globalScore)
        let isTurningUp = snapshot.isTurningUp
        
        return VStack(spacing: 8) {
            Text(snapshot.globalSignal.rawValue)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(snapshot.globalSignal.color)
                .frame(height: 24)
                .padding(.top, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                        .offset(y: 0)
                    
                    if snapshot.globalScore > 0 {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(snapshot.globalScore) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: -min(abs(snapshot.globalScore) * 0.4, geometry.size.height * 0.45))
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(snapshot.globalScore) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: min(abs(snapshot.globalScore) * 0.4, geometry.size.height * 0.45))
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
                Text(String(format: "%.1f", snapshot.globalScore))
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
            
            Text(t("global"))
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
    private func fullScreenTimeframeColumn(reading: VMCReading, timeframe: VMCTimeframe) -> some View {
        let gradient = Self.vmcGradient(reading.value)
        let isTurningUp = reading.value > 0
        
        return VStack(spacing: 8) {
            Text(reading.status.rawValue)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(reading.status.color)
                .frame(height: 24)
                .padding(.top, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                        .offset(y: 0)
                    
                    if reading.value > 0 {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(reading.value) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: -min(abs(reading.value) * 0.4, geometry.size.height * 0.45))
                    } else {
                        Rectangle()
                            .fill(gradient)
                            .frame(
                                width: geometry.size.width - 4,
                                height: min(abs(reading.value) * 0.8, geometry.size.height * 0.9)
                            )
                            .offset(y: min(abs(reading.value) * 0.4, geometry.size.height * 0.45))
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
                Text(String(format: "%.1f", reading.value))
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
            
            Text(timeframe.displayName)
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
    
    // Supprimé fullScreenDetailsView - pas nécessaire en mode plein écran compact
    
    private var fullScreenLegendView: some View {
        HStack(spacing: 16) {
            legendItemCompact(color: .green, text: "Achat")
            legendItemCompact(color: Color.yellow.opacity(0.7), text: "Baissier")
            legendItemCompact(color: .gray, text: "Neutre")
            legendItemCompact(color: .orange, text: "Haussier")
            legendItemCompact(color: .red, text: "Vente")
        }
        .font(.caption)
        .padding(.vertical, 4)
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
