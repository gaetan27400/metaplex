//
//  IndicatorShareService.swift
//  Journal de trading 2025
//

import SwiftUI
import UIKit

// MARK: - Share Sheet

struct IndicatorShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let caption: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let watermarked = addWatermark(to: image)
        let vc = UIActivityViewController(activityItems: [watermarked, caption], applicationActivities: nil)
        vc.excludedActivityTypes = [.addToReadingList, .openInIBooks, .markupAsPDF]
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    private func addWatermark(to image: UIImage) -> UIImage {
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        image.draw(at: .zero)
        let h: CGFloat = 36
        UIColor.black.withAlphaComponent(0.8).setFill()
        UIRectFill(CGRect(x: 0, y: size.height - h, width: size.width, height: h))
        let yc = size.height - h + (h - 14) / 2
        ("TradeMindset" as NSString).draw(at: CGPoint(x: 12, y: yc),
            withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                             .foregroundColor: UIColor.white.withAlphaComponent(0.9)])
        let fmt = DateFormatter(); fmt.dateFormat = "dd MMM yyyy HH:mm"
        let d = fmt.string(from: Date())
        let ds = (d as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
        (d as NSString).draw(at: CGPoint(x: size.width - ds.width - 12, y: yc),
            withAttributes: [.font: UIFont.systemFont(ofSize: 11),
                             .foregroundColor: UIColor.white.withAlphaComponent(0.65)])
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// MARK: - Orientation helper

@MainActor
private func forceOrientation(_ mask: UIInterfaceOrientationMask) {
    AppDelegate.orientationLock = mask
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
    if #available(iOS 16.0, *) {
        let pref: UIWindowScene.GeometryPreferences.iOS
        switch mask {
        case .landscapeLeft, .landscapeRight, .landscape:
            pref = .init(interfaceOrientations: .landscape)
        default:
            pref = .init(interfaceOrientations: .portrait)
        }
        scene.requestGeometryUpdate(pref)
    } else {
        let val = (mask == .landscapeLeft || mask == .landscape)
            ? UIInterfaceOrientation.landscapeRight.rawValue
            : UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(val, forKey: "orientation")
    }
}

// MARK: - Full Window Screenshot

@MainActor
func captureFullWindow() -> UIImage? {
    guard let window = UIApplication.shared
        .connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })
    else { return nil }

    let scale = window.screen.scale
    let renderer = UIGraphicsImageRenderer(size: window.bounds.size, format: {
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = scale; f.opaque = true; return f
    }())
    return renderer.image { ctx in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
}

// MARK: - FullscreenShareModifier

struct FullscreenShareModifier: ViewModifier {
    @Binding var trigger: Bool
    @Binding var showFullScreen: Bool
    let caption: String
    let forceLandscape: Bool   // true pour MTF

    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var isCapturing = false

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, fired in
                guard fired, !isCapturing else { trigger = false; return }
                isCapturing = true
                captureSequence()
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { shareImage = nil }) {
                if let img = shareImage {
                    IndicatorShareSheet(image: img, caption: caption)
                }
            }
    }

    private func captureSequence() {
        // Étape 1 : forcer paysage si nécessaire
        if forceLandscape {
            forceOrientation(.landscapeLeft)
        }

        // Étape 2 : ouvrir le plein écran après rotation
        let openDelay: Double = forceLandscape ? 0.4 : 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + openDelay) {
            showFullScreen = true

            // Étape 3 : attendre rendu complet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Étape 4 : screenshot
                shareImage = captureFullWindow()

                // Étape 5 : fermer plein écran + rétablir portrait
                showFullScreen = false
                if forceLandscape {
                    forceOrientation(.portrait)
                }

                // Étape 6 : ouvrir share sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showShareSheet = shareImage != nil
                    isCapturing = false
                    trigger = false
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Partage via screenshot du plein écran (portrait).
    func fullscreenShareable(
        trigger: Binding<Bool>,
        showFullScreen: Binding<Bool>,
        caption: String
    ) -> some View {
        modifier(FullscreenShareModifier(
            trigger: trigger,
            showFullScreen: showFullScreen,
            caption: caption,
            forceLandscape: false
        ))
    }

    /// Partage via screenshot du plein écran forcé en paysage (MTF).
    func fullscreenShareableLandscape(
        trigger: Binding<Bool>,
        showFullScreen: Binding<Bool>,
        caption: String
    ) -> some View {
        modifier(FullscreenShareModifier(
            trigger: trigger,
            showFullScreen: showFullScreen,
            caption: caption,
            forceLandscape: true
        ))
    }
}
