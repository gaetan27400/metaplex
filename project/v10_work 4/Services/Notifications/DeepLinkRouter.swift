//
//  DeepLinkRouter.swift
//  Journal de trading 2025
//

import Foundation
import SwiftUI
import Combine

class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    @Published var navigationPath: [DeepLinkDestination] = []
    
    private init() {}
    
    // MARK: - Routing Methods
    
    func routeToAlert(alertId: String) {
        DispatchQueue.main.async {
            self.navigationPath.append(.alertDetail(alertId: alertId))
        }
    }
    
    func routeToAlerts() {
        DispatchQueue.main.async {
            self.navigationPath.append(.alertsList)
        }
    }
    
    func routeToTrade(tradeId: String) {
        DispatchQueue.main.async {
            self.navigationPath.append(.tradeDetail(tradeId: tradeId))
        }
    }
    
    func routeToDashboard() {
        DispatchQueue.main.async {
            self.navigationPath.append(.dashboard)
        }
    }
    
    func routeToSettings() {
        DispatchQueue.main.async {
            self.navigationPath.append(.settings)
        }
    }
    
    func routeToPhotoAnalysis() {
        DispatchQueue.main.async {
            self.navigationPath.append(.photoAnalysis)
        }
    }
    
    func clearNavigation() {
        DispatchQueue.main.async {
            self.navigationPath.removeAll()
        }
    }
    
    // MARK: - URL Handling
    
    func handleURL(_ url: URL) {
        print("🔗 [DeepLinkRouter] Handling URL: \(url)")
        
        // Accepter à la fois "app://" et "trademindset://"
        guard url.scheme == "app" || url.scheme == "trademindset" else {
            print("❌ [DeepLinkRouter] Invalid scheme: \(url.scheme ?? "nil")")
            return
        }
        
        switch url.host {
        case "alert":
            handleAlertURL(url)
        case "alerts":
            routeToAlerts()
        case "trade":
            handleTradeURL(url)
        case "dashboard":
            routeToDashboard()
        case "settings":
            routeToSettings()
        case "photo-analysis":
            routeToPhotoAnalysis()
        default:
            print("❌ [DeepLinkRouter] Unknown host: \(url.host ?? "nil")")
        }
    }
    
    private func handleAlertURL(_ url: URL) {
        let pathComponents = url.pathComponents
        
        if pathComponents.count >= 2 {
            let alertId = pathComponents[1]
            routeToAlert(alertId: alertId)
        } else {
            routeToAlerts()
        }
    }
    
    private func handleTradeURL(_ url: URL) {
        let pathComponents = url.pathComponents
        
        if pathComponents.count >= 2 {
            let tradeId = pathComponents[1]
            routeToTrade(tradeId: tradeId)
        }
    }
}

// MARK: - Deep Link Destinations

enum DeepLinkDestination: Hashable, Identifiable {
    case alertDetail(alertId: String)
    case alertsList
    case tradeDetail(tradeId: String)
    case dashboard
    case settings
    case photoAnalysis
    
    var id: String {
        switch self {
        case .alertDetail(let alertId):
            return "alert_\(alertId)"
        case .alertsList:
            return "alerts_list"
        case .tradeDetail(let tradeId):
            return "trade_\(tradeId)"
        case .dashboard:
            return "dashboard"
        case .settings:
            return "settings"
        case .photoAnalysis:
            return "photo_analysis"
        }
    }
}

// MARK: - Deep Link Manager

class DeepLinkManager: ObservableObject {
    @Published var pendingURL: URL?
    
    func handleIncomingURL(_ url: URL) {
        pendingURL = url
        DeepLinkRouter.shared.handleURL(url)
    }
    
    func clearPendingURL() {
        pendingURL = nil
    }
}











