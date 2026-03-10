//
//  NetworkSession.swift
//  Journal de trading 2025
//
//  URLSession partagée optimisée pour toutes les requêtes marché
//

import Foundation

enum NetworkSession {
    /// Session optimisée : timeout réduit, cache HTTP activé
    static let market: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 10  // 10s (défaut 60s)
        config.timeoutIntervalForResource = 20
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 4 * 1024 * 1024,   // 4MB RAM
            diskCapacity:   16 * 1024 * 1024    // 16MB disque
        )
        return URLSession(configuration: config)
    }()
}
