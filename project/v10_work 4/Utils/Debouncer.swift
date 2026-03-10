//
//  Debouncer.swift
//  Journal de trading 2025
//
//  Debouncer pour retarder l'exécution de fonctions coûteuses
//

import Foundation

/// Debouncer pour retarder l'exécution jusqu'à ce qu'une période de silence soit détectée
actor Debouncer {
    private let delay: TimeInterval
    private var task: Task<Void, Never>?
    
    /// Crée un debouncer avec un délai
    /// - Parameter delay: Délai en secondes (défaut: 0.5)
    init(delay: TimeInterval = 0.5) {
        self.delay = delay
    }
    
    /// Debounce une action
    /// - Parameter action: Action à exécuter après le délai
    func debounce(action: @escaping @Sendable () async -> Void) {
        // Annuler la tâche précédente si elle existe
        task?.cancel()
        
        // Créer une nouvelle tâche
        task = Task { [delay] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Vérifier que la tâche n'a pas été annulée
            guard !Task.isCancelled else { return }
            
            await action()
        }
    }
    
    /// Debounce une action synchrone
    /// - Parameter action: Action à exécuter après le délai
    func debounce(action: @escaping @Sendable () -> Void) {
        debounce {
            await MainActor.run {
                action()
            }
        }
    }
    
    /// Annule toute action en attente
    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// Debouncer pour le thread principal (synchronisation MainActor)
@MainActor
class MainActorDebouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    /// Crée un debouncer pour MainActor
    /// - Parameter delay: Délai en secondes (défaut: 0.5)
    init(delay: TimeInterval = 0.5) {
        self.delay = delay
    }
    
    /// Debounce une action
    /// - Parameter action: Action à exécuter après le délai
    func debounce(action: @escaping @MainActor () -> Void) {
        // Annuler le work item précédent
        workItem?.cancel()
        
        // Créer un nouveau work item
        let newWorkItem = DispatchWorkItem(block: action)
        workItem = newWorkItem
        
        // Planifier l'exécution
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            newWorkItem.perform()
        }
    }
    
    /// Annule toute action en attente
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
