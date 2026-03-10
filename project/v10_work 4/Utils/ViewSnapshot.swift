//
//  ViewSnapshot.swift
//  Journal de trading 2025
//
//  Utilitaires pour capturer des vues SwiftUI en images et les partager

import SwiftUI
import UIKit

// MARK: - Extension View pour snapshot
extension View {
    /// Capture la vue en UIImage
    func snapshot(width: CGFloat? = nil, height: CGFloat? = nil) -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let targetSize = CGSize(
            width: width ?? UIScreen.main.bounds.width,
            height: height ?? UIScreen.main.bounds.height
        )
        
        controller.view.frame = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .clear
        
        // Forcer le layout
        controller.view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

