//
//  LoadingState.swift
//  Journal de trading 2025
//
//  États de chargement pour les données asynchrones
//

import Foundation

/// État de chargement générique pour les données asynchrones
enum LoadingState<Value, Error: Swift.Error>: Equatable where Value: Equatable, Error: Equatable {
    case idle
    case loading
    case loaded(Value)
    case error(Error)
    
    static func == (lhs: LoadingState<Value, Error>, rhs: LoadingState<Value, Error>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.loaded(let lhsValue), .loaded(let rhsValue)):
            return lhsValue == rhsValue
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var value: Value? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

/// État de chargement spécialisé pour AppError
typealias AppLoadingState<Value: Equatable> = LoadingState<Value, AppError>

// MARK: - Extensions pour faciliter l'utilisation

extension LoadingState {
    /// Map la valeur chargée
    func map<NewValue>(_ transform: (Value) -> NewValue) -> LoadingState<NewValue, Error> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .error(let error):
            return .error(error)
        }
    }
    
    /// Map l'erreur
    func mapError<NewError>(_ transform: (Error) -> NewError) -> LoadingState<Value, NewError> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(value)
        case .error(let error):
            return .error(transform(error))
        }
    }
}
