//
//  FirebaseAppDelegate.swift
//  Journal de trading 2025
//

import UIKit

#if canImport(Firebase)
import Firebase
#endif

@objc public class AppDelegate: NSObject, UIApplicationDelegate {
    // Support pour le verrouillage d'orientation
    static var orientationLock = UIInterfaceOrientationMask.all
    
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // ⚠️ Ne configure PAS Firebase ici. FirebaseApp.configure() est fait dans le @main init().
        print("🚀 AppDelegate reconnu par Firebase")
        return true
    }
    
    // Contrôle de l'orientation
    public func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}


