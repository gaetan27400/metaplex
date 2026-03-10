//
//  OrientationHelper.swift
//  Journal de trading 2025
//
//  Helper pour forcer l'orientation de l'écran
//

import SwiftUI
import UIKit

struct OrientationLockModifier: ViewModifier {
    let orientation: UIInterfaceOrientationMask
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Verrouiller l'orientation uniquement pour cette vue
                AppDelegate.orientationLock = orientation
                // Forcer la rotation en paysage si nécessaire
                let isLandscape = orientation.contains(.landscapeLeft) || orientation.contains(.landscapeRight)
                if isLandscape {
                    DispatchQueue.main.async {
                        if #available(iOS 16.0, *) {
                            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
                        } else {
                            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                        }
                    }
                }
            }
            .onDisappear {
                // Restaurer toutes les orientations autorisées (pas seulement portrait)
                AppDelegate.orientationLock = .all
                // Ne pas forcer le retour en portrait - laisser l'utilisateur choisir
                // L'app reviendra naturellement à l'orientation configurée dans Info.plist
            }
    }
}

extension View {
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) -> some View {
        modifier(OrientationLockModifier(orientation: orientation))
    }
}
