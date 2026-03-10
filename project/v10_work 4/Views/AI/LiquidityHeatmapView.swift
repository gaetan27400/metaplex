//
//  LiquidityHeatmapView.swift
//  Journal de trading 2025
//
//  Heatmap de liquidation BTC style Coinglass
//  - Fond violet/magenta
//  - Bandes cyan/vert = zones de liquidation
//  - Jaune = concentration maximale
//  - Bougies OHLC superposées
//  - Sélecteur de période (12h → 1 mois)
//  - Canvas SwiftUI pour performance 60fps
//

import SwiftUI

struct LiquidityHeatmapView: View {
    @StateObject private var viewModel: LiquidityHeatmapViewModel
    @State private var showFullScreen = false
    @State private var shareTrigger = false
    @State private var tapPoint: CGPoint?
    @State private var tapInfo: TapInfo?
    
    struct TapInfo {
        let price: Double
        let volume: Double
        let timestamp: Date
        let point: CGPoint
    }
    
    init(symbol: String = "BTCUSDT") {
        _viewModel = StateObject(wrappedValue: LiquidityHeatmapViewModel(symbol: symbol))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            periodSelector
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.heatmapData.snapshots.isEmpty {
                emptyView
            } else {
                heatmapCanvas
            }
            
            legendBar
        }
        .background(Color(red: 0.05, green: 0.02, blue: 0.12)) // fond sombre violet
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .onAppear { Task { await viewModel.load() } }
        .fullscreenShareable(
            trigger: $shareTrigger,
            showFullScreen: $showFullScreen,
            caption: "Liquidation Heatmap — \(viewModel.symbol) \(viewModel.selectedPeriod.displayName) | TradeMindset"
        )
        .fullScreenCover(isPresented: $showFullScreen) {
            fullScreenView
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text("Liquidation Heatmap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(viewModel.symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            if viewModel.currentPrice > 0 {
                Text(formatPrice(viewModel.currentPrice))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Button { showFullScreen = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Button {
                HapticFeedback.medium()
                shareTrigger = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(LiqHeatmapPeriod.allCases) { period in
                    Button {
                        viewModel.changePeriod(period)
                    } label: {
                        Text(period.displayName)
                            .font(.system(size: 10, weight: viewModel.selectedPeriod == period ? .bold : .medium))
                            .foregroundColor(viewModel.selectedPeriod == period ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.selectedPeriod == period
                                ? Color.purple.opacity(0.5)
                                : Color.white.opacity(0.05)
                            )
                            .cornerRadius(5)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
    }
    
    // MARK: - Heatmap Canvas
    
    private var heatmapCanvas: some View {
        GeometryReader { geo in
            let axisWidth: CGFloat = 42
            let chartWidth = geo.size.width - axisWidth
            let h = geo.size.height
            let data = viewModel.heatmapData
            
            HStack(spacing: 0) {
                // Chart zone
                ZStack {
                    Canvas { context, size in
                        drawHeatmap(context: &context, size: size, data: data)
                        drawCandles(context: &context, size: size, data: data)
                    }
                    
                    if viewModel.currentPrice > 0 && data.priceMax > data.priceMin {
                        let ratio = (viewModel.currentPrice - data.priceMin) / (data.priceMax - data.priceMin)
                        let y = h * (1 - ratio)
                        if y > 0 && y < h {
                            priceOverlay(y: y, width: chartWidth)
                        }
                    }
                    
                    if let info = tapInfo {
                        crosshairOverlay(info: info, width: chartWidth, height: h)
                    }
                    if let info = tapInfo {
                        tooltipView(info: info, canvasWidth: chartWidth, canvasHeight: h)
                    }
                }
                .frame(width: chartWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleTap(at: value.location, canvasSize: CGSize(width: chartWidth, height: h), data: data)
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeOut(duration: 0.3)) { tapInfo = nil }
                            }
                        }
                )
                
                // Axe prix à droite
                priceAxis(height: h, data: data)
                    .frame(width: axisWidth)
            }
        }
        .frame(height: 300)
    }
    
    // MARK: - Handle Tap
    
    private func handleTap(at point: CGPoint, canvasSize: CGSize, data: LiquidityHeatmapData) {
        guard !data.snapshots.isEmpty, data.priceMax > data.priceMin else { return }
        
        let w = canvasSize.width
        let h = canvasSize.height
        
        // Convertir Y → prix
        let priceRatio = 1.0 - Double(point.y / h)
        let price = data.priceMin + priceRatio * (data.priceMax - data.priceMin)
        
        // Convertir X → colonne/timestamp
        let colIdx = Int(Double(point.x / w) * Double(data.snapshots.count))
        let safeIdx = min(max(colIdx, 0), data.snapshots.count - 1)
        let snap = data.snapshots[safeIdx]
        
        // Trouver l'intensité à ce point
        let bucketIdx = Int((price - data.priceMin) / data.priceStep)
        let safeBucket = min(max(bucketIdx, 0), data.priceBucketCount - 1)
        let intensity = snap.liquidationLevels[safeBucket]
        
        // Estimer le volume en USD (approximation basée sur l'intensité)
        let estimatedVolume = intensity * (snap.candle?.volume ?? 0) * 1000
        
        withAnimation(.easeOut(duration: 0.15)) {
            tapInfo = TapInfo(
                price: price,
                volume: estimatedVolume,
                timestamp: snap.timestamp,
                point: point
            )
        }
    }
    
    // MARK: - Crosshair
    
    private func crosshairOverlay(info: TapInfo, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Ligne horizontale
            Path { p in
                p.move(to: CGPoint(x: 0, y: info.point.y))
                p.addLine(to: CGPoint(x: width, y: info.point.y))
            }
            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            
            // Ligne verticale
            Path { p in
                p.move(to: CGPoint(x: info.point.x, y: 0))
                p.addLine(to: CGPoint(x: info.point.x, y: height))
            }
            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            
            // Point blanc
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .shadow(color: .white.opacity(0.6), radius: 3)
                .position(info.point)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Tooltip
    
    private func tooltipView(info: TapInfo, canvasWidth: CGFloat, canvasHeight: CGFloat) -> some View {
        let tooltipW: CGFloat = 175
        let tooltipH: CGFloat = 72
        
        // Positionner le tooltip pour qu'il ne sorte pas de l'écran
        let tx: CGFloat
        if info.point.x > canvasWidth / 2 {
            tx = info.point.x - tooltipW - 12
        } else {
            tx = info.point.x + 12
        }
        let ty: CGFloat
        if info.point.y > canvasHeight / 2 {
            ty = info.point.y - tooltipH - 12
        } else {
            ty = info.point.y + 12
        }
        
        return VStack(alignment: .leading, spacing: 5) {
            // Date
            Text(formatTimestamp(info.timestamp))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            
            // Prix
            HStack(spacing: 4) {
                Circle().fill(Color.yellow).frame(width: 6, height: 6)
                Text("Prix")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(formatPrice(info.price))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Liquidation
            HStack(spacing: 4) {
                Circle().fill(Color.yellow).frame(width: 6, height: 6)
                Text("Liq. Leverage")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(formatVolume(info.volume))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .frame(width: tooltipW)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .position(x: tx + tooltipW / 2, y: ty + tooltipH / 2)
        .allowsHitTesting(false)
    }
    
    // MARK: - Draw Heatmap
    
    private func drawHeatmap(context: inout GraphicsContext, size: CGSize, data: LiquidityHeatmapData) {
        let snaps = data.snapshots
        guard !snaps.isEmpty, data.priceBucketCount > 0 else { return }
        
        let colWidth = size.width / CGFloat(snaps.count)
        let rowHeight = size.height / CGFloat(data.priceBucketCount)
        
        for (colIdx, snap) in snaps.enumerated() {
            let x = CGFloat(colIdx) * colWidth
            
            for (rowIdx, intensity) in snap.liquidationLevels.enumerated() {
                let y = size.height - CGFloat(rowIdx + 1) * rowHeight
                let color = coinglass(intensity: intensity)
                let rect = CGRect(x: x, y: y, width: colWidth + 0.5, height: rowHeight + 0.5)
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
    
    // MARK: - Draw Candles
    
    private func drawCandles(context: inout GraphicsContext, size: CGSize, data: LiquidityHeatmapData) {
        let snaps = data.snapshots
        guard !snaps.isEmpty, data.priceMax > data.priceMin else { return }
        
        let colWidth = size.width / CGFloat(snaps.count)
        let priceRange = data.priceMax - data.priceMin
        
        for (colIdx, snap) in snaps.enumerated() {
            guard let c = snap.candle else { continue }
            
            let centerX = CGFloat(colIdx) * colWidth + colWidth / 2
            let isBull = c.close >= c.open
            let color: Color = isBull ? Color(red: 0.0, green: 0.85, blue: 0.6) : Color(red: 0.95, green: 0.2, blue: 0.3)
            
            // Mèche (high-low)
            let highY = size.height * (1 - (c.high - data.priceMin) / priceRange)
            let lowY = size.height * (1 - (c.low - data.priceMin) / priceRange)
            
            var wickPath = Path()
            wickPath.move(to: CGPoint(x: centerX, y: highY))
            wickPath.addLine(to: CGPoint(x: centerX, y: lowY))
            context.stroke(wickPath, with: .color(color.opacity(0.7)), lineWidth: 0.8)
            
            // Corps
            let openY = size.height * (1 - (c.open - data.priceMin) / priceRange)
            let closeY = size.height * (1 - (c.close - data.priceMin) / priceRange)
            let bodyTop = min(openY, closeY)
            let bodyHeight = max(abs(closeY - openY), 1)
            let bodyWidth = max(colWidth * 0.6, 1.5)
            
            let bodyRect = CGRect(
                x: centerX - bodyWidth / 2,
                y: bodyTop,
                width: bodyWidth,
                height: bodyHeight
            )
            context.fill(Path(bodyRect), with: .color(color))
        }
    }
    
    // MARK: - Coinglass Color Palette
    
    /// Palette fidèle Coinglass : violet sombre → cyan → vert → jaune
    private func coinglass(intensity: Double) -> Color {
        let i = min(max(intensity, 0), 1)
        
        // Fond violet sombre pour les zones sans liquidation
        if i < 0.05 {
            return Color(red: 0.15, green: 0.05, blue: 0.25)
        }
        
        if i < 0.15 {
            // Violet sombre → violet moyen
            let t = (i - 0.05) / 0.10
            return Color(
                red: 0.15 + t * 0.15,
                green: 0.05 + t * 0.05,
                blue: 0.25 + t * 0.15
            )
        }
        
        if i < 0.30 {
            // Violet → bleu-cyan
            let t = (i - 0.15) / 0.15
            return Color(
                red: 0.30 - t * 0.20,
                green: 0.10 + t * 0.35,
                blue: 0.40 + t * 0.20
            )
        }
        
        if i < 0.50 {
            // Cyan → vert-cyan
            let t = (i - 0.30) / 0.20
            return Color(
                red: 0.10 - t * 0.05,
                green: 0.45 + t * 0.30,
                blue: 0.60 - t * 0.25
            )
        }
        
        if i < 0.70 {
            // Vert → vert-jaune
            let t = (i - 0.50) / 0.20
            return Color(
                red: 0.05 + t * 0.55,
                green: 0.75 + t * 0.15,
                blue: 0.35 - t * 0.25
            )
        }
        
        if i < 0.85 {
            // Jaune-vert → jaune vif
            let t = (i - 0.70) / 0.15
            return Color(
                red: 0.60 + t * 0.35,
                green: 0.90 + t * 0.10,
                blue: 0.10 - t * 0.05
            )
        }
        
        // Jaune vif → blanc chaud
        let t = (i - 0.85) / 0.15
        return Color(
            red: 0.95 + t * 0.05,
            green: 1.0,
            blue: 0.05 + t * 0.45
        )
    }
    
    // MARK: - Overlays
    
    private func priceOverlay(y: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
            
            Text(formatPrice(viewModel.currentPrice))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.cyan)
                .cornerRadius(2)
                .position(x: width - 30, y: y)
        }
    }
    
    private func priceAxis(height: CGFloat, data: LiquidityHeatmapData) -> some View {
        let steps = 6
        let priceStep = (data.priceMax - data.priceMin) / Double(steps)
        
        return VStack {
            ForEach(0...steps, id: \.self) { i in
                let price = data.priceMax - priceStep * Double(i)
                Text(formatCompact(price))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                if i < steps { Spacer() }
            }
        }
        .padding(.leading, 2)
        .padding(.vertical, 2)
        .allowsHitTesting(false)
    }
    
    // MARK: - Legend
    
    private var legendBar: some View {
        HStack(spacing: 4) {
            // Gradient palette
            HStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { i in
                    Rectangle()
                        .fill(coinglass(intensity: Double(i) / 19.0))
                        .frame(width: 8, height: 8)
                }
            }
            .cornerRadius(2)
            
            Text("Liquidation Leverage")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.35))
            
            Spacer()
            
            // Candle legend
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.0, green: 0.85, blue: 0.6))
                    .frame(width: 8, height: 8)
                Text("Bull")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.35))
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.95, green: 0.2, blue: 0.3))
                    .frame(width: 8, height: 8)
                Text("Bear")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - States
    
    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.purple)
            Text("Calcul des niveaux de liquidation...")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(height: 300)
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundColor(.purple.opacity(0.4))
            Text("Données indisponibles")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
            Button("Réessayer") {
                Task { await viewModel.load() }
            }
            .font(.system(size: 11))
            .foregroundColor(.cyan)
        }
        .frame(height: 300)
    }
    
    // MARK: - Full Screen
    
    private var fullScreenView: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.01, blue: 0.08).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Liquidation Heatmap")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(viewModel.symbol)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        if viewModel.currentPrice > 0 {
                            Text(formatPrice(viewModel.currentPrice))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    periodSelector
                    
                    // Heatmap plein écran
                    GeometryReader { geo in
                        let axisW: CGFloat = 48
                        let chartW = geo.size.width - axisW
                        let h = geo.size.height
                        let data = viewModel.heatmapData
                        
                        HStack(spacing: 0) {
                            ZStack {
                                Canvas { context, size in
                                    drawHeatmap(context: &context, size: size, data: data)
                                    drawCandles(context: &context, size: size, data: data)
                                }
                                
                                if viewModel.currentPrice > 0 && data.priceMax > data.priceMin {
                                    let ratio = (viewModel.currentPrice - data.priceMin) / (data.priceMax - data.priceMin)
                                    let y = h * (1 - ratio)
                                    if y > 0 && y < h {
                                        priceOverlay(y: y, width: chartW)
                                    }
                                }
                                
                                if let info = tapInfo {
                                    crosshairOverlay(info: info, width: chartW, height: h)
                                }
                                if let info = tapInfo {
                                    tooltipView(info: info, canvasWidth: chartW, canvasHeight: h)
                                }
                            }
                            .frame(width: chartW)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleTap(at: value.location, canvasSize: CGSize(width: chartW, height: h), data: data)
                                    }
                                    .onEnded { _ in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                            withAnimation(.easeOut(duration: 0.3)) { tapInfo = nil }
                                        }
                                    }
                            )
                            
                            priceAxis(height: h, data: data)
                                .frame(width: axisW)
                        }
                    }
                    
                    legendBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticFeedback.medium()
                        showFullScreen = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shareTrigger = true
                        }
                    } label: {
                        Label("Partager", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFullScreen = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .lockOrientation(.landscape)
    }
    
    private func formatPrice(_ p: Double) -> String {
        if p >= 1000 { return String(format: "%.2f", p) }
        else if p >= 1 { return String(format: "%.4f", p) }
        else { return String(format: "%.6f", p) }
    }
    
    private func formatCompact(_ p: Double) -> String {
        p >= 10000 ? String(format: "%.0f", p) : String(format: "%.1f", p)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: date)
    }
    
    private func formatVolume(_ vol: Double) -> String {
        if vol >= 1_000_000_000 { return String(format: "%.2fB", vol / 1_000_000_000) }
        if vol >= 1_000_000 { return String(format: "%.2fM", vol / 1_000_000) }
        if vol >= 1_000 { return String(format: "%.1fK", vol / 1_000) }
        if vol > 0 { return String(format: "%.0f", vol) }
        return "0"
    }
}

#Preview {
    LiquidityHeatmapView(symbol: "BTCUSDT")
        .padding()
        .background(Color.black)
}
