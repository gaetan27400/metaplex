//
//  PushService.swift
//  Journal de trading 2025
//

import Foundation
import UserNotifications
import UIKit
import Combine
import SwiftUI

class PushService: NSObject, ObservableObject {
    static let shared = PushService()
    
    @Published var isAuthorized = false
    @Published var pushToken: String?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Push Registration
    
    func registerForPushNotifications() async {
        do {
            // Request authorization using modern presentation options
            var options: UNAuthorizationOptions = [.badge, .sound]
            if #available(iOS 14.0, *) {
                options.insert(.alert) // allowed; presentation uses banner/list later
            } else {
                options.insert(.alert)
            }
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("❌ [PushService] Error requesting notification authorization: \(error)")
        }
    }
    
    private func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func updatePushToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        pushToken = tokenString
        print("📱 [PushService] Push token updated: \(tokenString)")
        
        // TODO: Send token to server for FCM registration
        sendTokenToServer(tokenString)
    }
    
    private func sendTokenToServer(_ token: String) {
        // TODO: Implement server registration
        print("📤 [PushService] Sending token to server: \(token)")
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String,
        userInfo: [String: Any] = [:],
        trigger: UNNotificationTrigger? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ [PushService] Error scheduling notification: \(error)")
            } else {
                print("✅ [PushService] Local notification scheduled: \(identifier)")
            }
        }
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    // MARK: - Wave Trend Signal Notifications
    
    @MainActor
    func sendWTSignalNotification(
        symbol: String,
        signal: WTSignal,
        timeframe: String,
        bias: MarketBias
    ) {
        let title: String
        let body: String
        
        switch signal {
        case .bullishReversal, .bullishSmartReversal:
            title = "🟢 Signal d'achat Wave Trend"
            body = "\(symbol) - \(timeframe): Revers haussier détecté. Biais: \(bias.displayName)"
        case .bearishReversal, .bearishSmartReversal:
            title = "🔴 Signal de vente Wave Trend"
            body = "\(symbol) - \(timeframe): Revers baissier détecté. Biais: \(bias.displayName)"
        case .neutral:
            return // Ne pas notifier pour neutral
        }
        
        scheduleLocalNotification(
            title: title,
            body: body,
            identifier: "wt_signal_\(symbol)_\(timeframe)_\(UUID().uuidString)",
            userInfo: [
                "type": "wt_signal",
                "symbol": symbol,
                "timeframe": timeframe,
                "signal": signal.rawValue,
                "bias": bias.rawValue
            ]
        )
        
        // Haptic feedback
        HapticFeedback.success()
        
        Logger.default.info("📱 [PushService] WT Signal notification sent: \(signal.displayName) for \(symbol) on \(timeframe)")
    }
    
    // MARK: - Liquidation Alert
    
    @MainActor
    func sendLiquidationAlert(symbol: String, pnl: Double, tradeId: UUID) async {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        let pnlString = formatter.string(from: NSNumber(value: pnl)) ?? "$0.00"
        
        let title = "⚠️ Liquidation imminente"
        let body = "\(symbol): P&L = \(pnlString). Risque de liquidation élevé !"
        
        scheduleLocalNotification(
            title: title,
            body: body,
            identifier: "liquidation_\(tradeId.uuidString)",
            userInfo: [
                "type": "liquidation",
                "tradeId": tradeId.uuidString,
                "symbol": symbol,
                "pnl": pnl
            ]
        )
        
        // Haptic feedback pour alerter l'utilisateur
        HapticFeedback.error()
    }
    
    // MARK: - Deep Link Handling
    
    func handle(deepLink: URL) {
        print("🔗 [PushService] Handling deep link: \(deepLink)")
        
        guard deepLink.scheme == "app" else {
            print("❌ [PushService] Invalid scheme: \(deepLink.scheme ?? "nil")")
            return
        }
        
        switch deepLink.host {
        case "alert":
            handleAlertDeepLink(deepLink)
        case "alerts":
            handleAlertsDeepLink(deepLink)
        default:
            print("❌ [PushService] Unknown deep link host: \(deepLink.host ?? "nil")")
        }
    }
    
    private func handleAlertDeepLink(_ url: URL) {
        let pathComponents = url.pathComponents
        
        if pathComponents.count >= 2 {
            let alertId = pathComponents[1]
            print("📱 [PushService] Opening alert: \(alertId)")
            
            // TODO: Navigate to specific alert
            DeepLinkRouter.shared.routeToAlert(alertId: alertId)
        }
    }
    
    private func handleAlertsDeepLink(_ url: URL) {
        print("📱 [PushService] Opening alerts list")
        
        // TODO: Navigate to alerts list
        DeepLinkRouter.shared.routeToAlerts()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 [PushService] Will present notification: \(notification.request.identifier)")
        
        // Show notification even when app is in foreground (use modern banner/list options)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("📱 [PushService] Did receive notification response: \(response.actionIdentifier)")
        
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "MARK_READ_ACTION":
            handleMarkReadAction(userInfo: userInfo)
        case "OPEN_ACTION", UNNotificationDefaultActionIdentifier:
            handleOpenAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleMarkReadAction(userInfo: [AnyHashable: Any]) {
        // TODO: Mark alert as read
        print("📱 [PushService] Mark read action")
    }
    
    private func handleOpenAction(userInfo: [AnyHashable: Any]) {
        // TODO: Open alert or navigate to alerts
        if let alertId = userInfo["alertId"] as? String {
            DeepLinkRouter.shared.routeToAlert(alertId: alertId)
        } else {
            DeepLinkRouter.shared.routeToAlerts()
        }
    }
}

// MARK: - Notification Categories

extension PushService {
    func setupNotificationCategories() {
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Marquer comme lu",
            options: []
        )
        
        let openAction = UNNotificationAction(
            identifier: "OPEN_ACTION",
            title: "Ouvrir",
            options: [.foreground]
        )
        
        let alertCategory = UNNotificationCategory(
            identifier: "ALERT_CATEGORY",
            actions: [markReadAction, openAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([alertCategory])
    }
}
