//
//  APIStore.swift
//  Journal de trading 2025
//

import Foundation

protocol APIStore {
    func saveAPICredentials(_ credentials: APICredentials) async throws
    func fetchAPICredentials(for exchange: String) async throws -> APICredentials?
    func deleteAPICredentials(for exchange: String) async throws
    func fetchAllAPICredentials() async throws -> [APICredentials]
}









