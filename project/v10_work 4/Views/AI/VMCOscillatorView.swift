//
//  VMCOscillatorView.swift
//  Journal de trading 2025
//
//  Vue graphique du VMC Oscillator (série temporelle)
//

import SwiftUI

struct VMCOscillatorView: View {
    let snapshot: VMCOscillatorSnapshot
    let symbol: String
    let currentTimeframe: WTTimeframe
    let onTimeframeChange: (WTTimeframe) -> Void
    
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isFullScreen = false
    @State private var shareTrigger = false
    
    private var isLandscape: Bool { verticalSizeClass == .compact }
    private let accentColor = Color.orange
    private let sigColor = Color(red: 0.216, green: 0.878, blue: 1.0)
    private let signalLineColor = Color.orange
    
    init(
        snapshot: VMCOscillatorSnapshot,
        symbol: String = "BTCUSDT",
        currentTimeframe: WTTimeframe = .h1,
        onTimeframeChange: @escaping (WTTimeframe) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.symbol = symbol
        self.currentTimeframe = currentTimeframe
        self.onTimeframeChange = onTimeframeChange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            timeframeSelector.padding(.vertical, AppSpacing.xs)
            chartSection.frame(height: isLandscape ? 200 : 260).padding(.horizontal, AppSpacing.sm)
            infoSection
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(accentColor.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: accentColor.opacity(0.08), radius: 10, x: 0, y: 4)
        .fullscreenShareable(
            trigger: $shareTrigger,
            showFullScreen: $isFullScreen,
            caption: "VMC Oscillator — \(symbol) \(currentTimeframe.displayName) | TradeMindset"
        )
        .fullScreenCover(isPresented: $isFullScreen) { fullScreenView }
    }

    // MARK: - Share

    private func captureAndShareVMC() {
        HapticFeedback.medium()
        shareTrigger = true
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.title3)
                .foregroundColor(.white)
                .padding(AppSpacing.sm)
                .background(
                    LinearGradient(colors: [accentColor, accentColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("VMC Oscillator")
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                Text(symbol)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(accentColor.opacity(0.8))
            }
            
            Spacer()
            
            Text(snapshot.statusText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(snapshot.statusColor))
            
            if snapshot.ribbonBull {
                ribbonBadge("BULL", color: .green)
            } else if snapshot.ribbonBear {
                ribbonBadge("BEAR", color: .red)
            }
            
            // Bouton partage
            Button(action: { captureAndShareVMC() }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(accentColor)
                    .padding(7)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Circle())
            }
            Button(action: { isFullScreen = true }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    private func ribbonBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.2)))
    }
    
    // MARK: - Timeframe Selector
    
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(WTTimeframe.allCases, id: \.self) { tf in
                    Button(action: { onTimeframeChange(tf) }) {
                        Text(tf.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(currentTimeframe == tf ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(currentTimeframe == tf ? accentColor : AppColors.background))
                    }
                }
            }
        }
    }
    
    // MARK: - Chart
    
    private var chartSection: some View {
        GeometryReader { geo in
            let readings = snapshot.readings
            if readings.isEmpty {
                Text("Pas de données")
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let w = geo.size.width
                let h = geo.size.height
                let yMin: Double = -80
                let yMax: Double = 80
                let yRange = yMax - yMin
                
                Canvas { context, size in
                    // Overbought zone
                    let obTop = yPos(yMax, h: h, yMin: yMin, yRange: yRange)
                    let obBot = yPos(snapshot.upperThreshold, h: h, yMin: yMin, yRange: yRange)
                    context.fill(
                        Path(CGRect(x: 0, y: obTop, width: w, height: obBot - obTop)),
                        with: .color(.red.opacity(0.05))
                    )
                    
                    // Oversold zone
                    let osTop = yPos(snapshot.lowerThreshold, h: h, yMin: yMin, yRange: yRange)
                    let osBot = yPos(yMin, h: h, yMin: yMin, yRange: yRange)
                    context.fill(
                        Path(CGRect(x: 0, y: osTop, width: w, height: osBot - osTop)),
                        with: .color(.green.opacity(0.05))
                    )
                    
                    // Zero line
                    let zeroY = yPos(0, h: h, yMin: yMin, yRange: yRange)
                    var zeroPath = Path()
                    zeroPath.move(to: CGPoint(x: 0, y: zeroY))
                    zeroPath.addLine(to: CGPoint(x: w, y: zeroY))
                    context.stroke(zeroPath, with: .color(AppColors.textTertiary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    
                    // Threshold lines
                    drawDashedLine(context: context, y: yPos(snapshot.upperThreshold, h: h, yMin: yMin, yRange: yRange), width: w, color: .red.opacity(0.4))
                    drawDashedLine(context: context, y: yPos(snapshot.lowerThreshold, h: h, yMin: yMin, yRange: yRange), width: w, color: .green.opacity(0.4))
                    
                    // Momentum histogram
                    let barW = max(w / CGFloat(readings.count) - 1, 1)
                    for (index, reading) in readings.enumerated() {
                        let x = xPos(index, count: readings.count, w: w)
                        let top = reading.momentum >= 0 ? yPos(reading.momentum, h: h, yMin: yMin, yRange: yRange) : zeroY
                        let bot = reading.momentum >= 0 ? zeroY : yPos(reading.momentum, h: h, yMin: yMin, yRange: yRange)
                        let barRect = CGRect(x: x - barW / 2, y: top, width: barW, height: bot - top)
                        context.fill(Path(barRect), with: .color(reading.momentum >= 0 ? .green.opacity(0.4) : .red.opacity(0.4)))
                    }
                    
                    // Sig line (cyan)
                    var sigPath = Path()
                    for (index, reading) in readings.enumerated() {
                        let pt = CGPoint(x: xPos(index, count: readings.count, w: w), y: yPos(reading.sig, h: h, yMin: yMin, yRange: yRange))
                        if index == 0 { sigPath.move(to: pt) } else { sigPath.addLine(to: pt) }
                    }
                    context.stroke(sigPath, with: .color(sigColor), lineWidth: 2)
                    
                    // Signal line (orange)
                    var signalPath = Path()
                    for (index, reading) in readings.enumerated() {
                        let pt = CGPoint(x: xPos(index, count: readings.count, w: w), y: yPos(reading.sigSignal, h: h, yMin: yMin, yRange: yRange))
                        if index == 0 { signalPath.move(to: pt) } else { signalPath.addLine(to: pt) }
                    }
                    context.stroke(signalPath, with: .color(signalLineColor), lineWidth: 1.5)
                    
                    // Signal markers
                    for (index, reading) in readings.enumerated() {
                        if let signal = reading.signal {
                            let x = xPos(index, count: readings.count, w: w)
                            let y = yPos(reading.sig, h: h, yMin: yMin, yRange: yRange) + (signal == .buy || signal == .exitShort ? 10 : -10)
                            let markerSize: CGFloat = 6
                            let color: Color = signal.color
                            
                            if signal == .buy || signal == .exitShort {
                                // Triangle up
                                var tri = Path()
                                tri.move(to: CGPoint(x: x, y: y - markerSize))
                                tri.addLine(to: CGPoint(x: x - markerSize / 2, y: y + markerSize / 2))
                                tri.addLine(to: CGPoint(x: x + markerSize / 2, y: y + markerSize / 2))
                                tri.closeSubpath()
                                context.fill(tri, with: .color(color))
                            } else {
                                // Triangle down
                                var tri = Path()
                                tri.move(to: CGPoint(x: x, y: y + markerSize))
                                tri.addLine(to: CGPoint(x: x - markerSize / 2, y: y - markerSize / 2))
                                tri.addLine(to: CGPoint(x: x + markerSize / 2, y: y - markerSize / 2))
                                tri.closeSubpath()
                                context.fill(tri, with: .color(color))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func xPos(_ index: Int, count: Int, w: CGFloat) -> CGFloat {
        CGFloat(index) / CGFloat(max(count - 1, 1)) * w
    }
    
    private func yPos(_ value: Double, h: CGFloat, yMin: Double, yRange: Double) -> CGFloat {
        CGFloat(1.0 - (value - yMin) / yRange) * h
    }
    
    private func drawDashedLine(context: GraphicsContext, y: CGFloat, width: CGFloat, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: width, y: y))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        HStack(spacing: AppSpacing.sm) {
            valueCard(title: "VMC", value: String(format: "%.1f", snapshot.currentSig), color: sigColor)
            valueCard(title: "Signal", value: String(format: "%.1f", snapshot.currentSigSignal), color: signalLineColor)
            valueCard(title: "Mom.", value: String(format: "%.1f", snapshot.currentMomentum), color: snapshot.currentMomentum >= 0 ? .green : .red)
        }
        .padding(.top, AppSpacing.sm)
    }
    
    private func valueCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Full Screen
    
    private var fullScreenView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    chartSection.frame(height: 350).padding(.horizontal)
                    infoSection.padding(.horizontal)
                }
            }
            .background(AppColors.background)
            .navigationTitle("VMC Oscillator — \(symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { isFullScreen = false }
                }
            }
        }
    }
}
