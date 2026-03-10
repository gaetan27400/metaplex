import Foundation
import SwiftUI
import Combine

extension AppState {
    func fees(for trade: Trade) -> Double {
        guard let entry = trade.entryPrice,
            let exit = trade.exitPrice,
              let qty = trade.quantity else {
            // Si les prix ne sont pas disponibles, retourner 0 (cohérent avec netPnL qui retourne 0.0)
            return 0
        }
        
        // Récupérer l'exchange du trade ou utiliser l'exchange par défaut
        let ex: Exchange
        if let tradeExchange = exchange(for: trade.exchangeId) {
            ex = tradeExchange
        } else if let defaultEx = exchanges.first(where: { $0.isDefault }) {
            ex = defaultEx
        } else if let firstEx = exchanges.first {
            ex = firstEx
        } else {
            // Si aucun exchange n'est disponible, utiliser des frais par défaut (0.1%) pour cohérence avec netPnL
            let defaultMakerRate = 0.001 // 0.1%
            let defaultTakerRate = 0.001 // 0.1%
            let feeTuple = PnLCalculator.fees(
                entryPrice: entry,
                exitPrice: exit,
                quantity: qty,
                makerRate: defaultMakerRate,
                takerRate: defaultTakerRate,
                role: trade.orderRole
            )
            return feeTuple.total
        }
        
        let feeTuple = PnLCalculator.fees(
            entryPrice: entry,
            exitPrice: exit,
            quantity: qty,
            makerRate: ex.makerFeeRate,
            takerRate: ex.takerFeeRate,
            role: trade.orderRole
        )
        return feeTuple.total
    }
    
    @MainActor
    func addTrade(_ trade: Trade) {
        print("📝 [AppState] Ajout d'un trade: \(trade.symbol) avec status: \(trade.status.rawValue)")
        print("📊 [AppState] Nombre de trades avant ajout: \(trades.count)")
        print("🔍 [AppState] Thread actuel: \(Thread.isMainThread ? "Main" : "Background")")
        
        // S'assurer qu'on est sur le MainActor
        guard Thread.isMainThread else {
            print("⚠️ [AppState] addTrade appelé depuis un thread de fond, dispatch vers Main")
            Task { @MainActor in
                self.addTrade(trade)
            }
            return
        }
        
        // Empêcher le rechargement pendant l'ajout
        isAddingTrade = true
        print("🔒 [AppState] isAddingTrade = true (protection activée)")
        
        // Forcer le status à .closed (désactivation des trades ouverts)
        var tradeToAdd = trade
        if tradeToAdd.status == .open {
            print("⚠️ [AppState] Trade ouvert détecté, conversion en trade fermé")
            tradeToAdd = Trade(
                id: trade.id,
                date: trade.date,
                symbol: trade.symbol,
                type: trade.type,
                entryPrice: trade.entryPrice,
                exitPrice: trade.exitPrice ?? trade.entryPrice, // Utiliser entryPrice si exitPrice est nil
                quantity: trade.quantity,
                leverage: trade.leverage,
                exchangeId: trade.exchangeId,
                orderRole: trade.orderRole,
                systemId: trade.systemId,
                session: trade.session,
                flashPnLNet: trade.flashPnLNet,
                notes: trade.notes,
                tags: trade.tags,
                status: .closed,
                currentPrice: nil,
                lastPriceUpdate: nil,
                closedAt: trade.closedAt ?? Date()
            )
        }
        
        // Ajouter le trade à la liste (cela déclenchera le didSet et refreshAnalytics)
        // Utiliser une assignation directe pour forcer la mise à jour SwiftUI
        var updatedTrades = trades
        updatedTrades.append(tradeToAdd)
        trades = updatedTrades
        
        print("📊 [AppState] Nombre de trades après ajout: \(trades.count)")
        print("📊 [AppState] Dernier trade ajouté: \(tradeToAdd.symbol) - PnL: \(netPnL(for: tradeToAdd) ?? 0)")
        
        // Forcer la mise à jour de l'UI en publiant le changement
        objectWillChange.send()
        print("📊 [AppState] objectWillChange.send() appelé pour forcer la mise à jour de l'UI")
        
        // Sauvegarder automatiquement dans le store (immédiatement pour garantir la persistance)
        let store = tradeStore
        let tradeId = tradeToAdd.id
        let tradeSymbol = tradeToAdd.symbol
        
        // Créer une Task qui sauvegarde immédiatement
        Task { @MainActor in
            do {
                print("💾 [AppState] Début de la sauvegarde dans SQLite: \(tradeSymbol)")
                let savedTrade = try await store.create(tradeToAdd)
                print("✅ [AppState] Trade sauvegardé automatiquement dans SQLite: \(savedTrade.symbol) avec status: \(savedTrade.status.rawValue)")
                
                // Vérifier que le trade est bien dans la base
                let verification = try await store.fetch(by: savedTrade.id)
                if verification != nil {
                    print("✅ [AppState] Vérification: Trade confirmé dans la base de données")
                    // S'assurer que le trade est bien dans la liste (au cas où il aurait été retiré)
                    if !trades.contains(where: { $0.id == savedTrade.id }) {
                        print("⚠️ [AppState] Trade non trouvé dans appState.trades, réajout...")
                        var updatedTrades = trades
                        updatedTrades.append(savedTrade)
                        trades = updatedTrades.sorted { $0.date > $1.date }
                        objectWillChange.send()
                    }
                    
                    // Maintenant que le trade est sauvegardé, on peut réactiver le rechargement
                    isAddingTrade = false
                    print("🔓 [AppState] isAddingTrade = false (protection désactivée après sauvegarde réussie)")
                } else {
                    print("⚠️ [AppState] Vérification: Trade non trouvé dans la base de données après sauvegarde")
                    // Ne pas désactiver isAddingTrade si la vérification échoue
                    // Attendre un peu plus et réessayer
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconde
                    let retryVerification = try await store.fetch(by: savedTrade.id)
                    if retryVerification != nil {
                        isAddingTrade = false
                        print("🔓 [AppState] isAddingTrade = false (protection désactivée après vérification de retry)")
                    } else {
                        print("❌ [AppState] Trade toujours non trouvé après retry, garder isAddingTrade = true")
                    }
                }
            } catch {
                print("❌ [AppState] Erreur lors de la sauvegarde automatique du trade \(tradeSymbol): \(error)")
                print("❌ [AppState] Détails de l'erreur: \(error.localizedDescription)")
                // En cas d'erreur, retirer le trade de la liste pour éviter une incohérence
                trades.removeAll { $0.id == tradeId }
                objectWillChange.send()
                print("⚠️ [AppState] Trade \(tradeSymbol) retiré de la liste suite à l'erreur de sauvegarde")
                // Réactiver le rechargement même en cas d'erreur
                isAddingTrade = false
            }
        }
        
        // Vérifier les badges après l'ajout d'un trade
        Task {
            await checkBadges()
        }
    }
    
    func updateTrade(_ trade: Trade) {
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            let oldStatus = trades[index].status
            trades[index] = trade
            
            // Sauvegarder automatiquement dans le store
            Task {
                do {
                    _ = try await tradeStore.update(trade)
                    print("✅ [AppState] Trade mis à jour automatiquement: \(trade.symbol) (status: \(trade.status.rawValue), était: \(oldStatus.rawValue))")
                } catch {
                    print("❌ [AppState] Erreur lors de la mise à jour automatique du trade: \(error)")
                }
            }
            
            // Le didSet de trades va automatiquement recharger les trades ouverts
        }
    }
    
    /// Met à jour le prix d'un trade ouvert sans changer son statut
    func updateOpenTradePrice(_ tradeId: UUID, newPrice: Double) async {
        guard let index = trades.firstIndex(where: { $0.id == tradeId }),
              trades[index].status == .open else {
            return
        }
        
        let updatedTrade = trades[index].withUpdatedPrice(newPrice)
        
        // Sauvegarder dans le store AVANT de mettre à jour l'état local
        do {
            _ = try await tradeStore.update(updatedTrade)
            
            // Mettre à jour l'état local seulement après la sauvegarde réussie
            await MainActor.run {
                trades[index] = updatedTrade
                print("✅ [AppState] Prix du trade ouvert mis à jour: \(updatedTrade.symbol) = \(newPrice) (status: \(updatedTrade.status.rawValue))")
            }
        } catch {
            print("❌ [AppState] Erreur lors de la mise à jour du prix: \(error)")
            // Ne pas mettre à jour l'état local si la sauvegarde échoue
        }
    }
    
    func deleteTrade(_ trade: Trade) {
        trades.removeAll { $0.id == trade.id }
        
        // Supprimer automatiquement du store
        Task {
            do {
                try await tradeStore.delete(trade)
                print("✅ [AppState] Trade supprimé automatiquement: \(trade.symbol)")
            } catch {
                print("❌ [AppState] Erreur lors de la suppression automatique du trade: \(error)")
            }
        }
    }
    
    func addExchange(_ exchange: Exchange) {
        exchanges.append(exchange)
        
        // Sauvegarder automatiquement dans le store
        Task {
            do {
                _ = try await exchangeStore.create(exchange)
                print("✅ [AppState] Exchange sauvegardé automatiquement: \(exchange.name)")
            } catch {
                print("❌ [AppState] Erreur lors de la sauvegarde automatique de l'exchange: \(error)")
            }
        }
    }
    
    func updateExchange(_ exchange: Exchange) {
        if let index = exchanges.firstIndex(where: { $0.id == exchange.id }) {
            exchanges[index] = exchange
            
            // Sauvegarder automatiquement dans le store
            Task {
                do {
                    _ = try await exchangeStore.update(exchange)
                    print("✅ [AppState] Exchange mis à jour automatiquement: \(exchange.name)")
                } catch {
                    print("❌ [AppState] Erreur lors de la mise à jour automatique de l'exchange: \(error)")
                }
            }
        }
    }
    
    func deleteExchange(_ exchange: Exchange) {
        if let firstEx = exchanges.first(where: { $0.id != exchange.id }) {
            trades = trades.map { trade in
                var updated = trade
                if updated.exchangeId == exchange.id {
                    updated.exchangeId = firstEx.id
                }
                return updated
            }
        }
        exchanges.removeAll { $0.id == exchange.id }
        
        // Supprimer automatiquement du store
        Task {
            do {
                try await exchangeStore.delete(exchange)
                print("✅ [AppState] Exchange supprimé automatiquement: \(exchange.name)")
            } catch {
                print("❌ [AppState] Erreur lors de la suppression automatique de l'exchange: \(error)")
            }
        }
    }
    
    func setDefaultExchange(_ exchange: Exchange) {
        exchanges = exchanges.map { ex in
            var updated = ex
            updated.isDefault = (ex.id == exchange.id)
            return updated
        }
    }
    
    func addSystem(_ system: TradingSystem) {
        print("🔧 AppState.addSystem() - Ajout du système: \(system.name)")
        print("🔧 Avant ajout: \(systems.count) systèmes")
        systems.append(system)
        print("🔧 Après ajout: \(systems.count) systèmes")
        print("🔧 Systèmes actuels: \(systems.map { $0.name })")
        
        // Sauvegarder dans le store
        Task {
            do {
                _ = try await systemStore.create(system)
                print("🔧 Système sauvegardé dans le store: \(system.name)")
                
                // Vérifier que le système est bien dans le store
                let allSystems = try await systemStore.fetchAll()
                print("🔧 Vérification store - Systèmes dans le store: \(allSystems.map { $0.name })")
            } catch {
                print("❌ Erreur lors de la sauvegarde du système: \(error)")
            }
        }
    }
    
    func updateSystem(_ system: TradingSystem) async throws {
        // Vérifier que le système existe
        guard systems.contains(where: { $0.id == system.id }) else {
            throw SystemUpdateError.systemNotFound
        }
        
        // Vérifier qu'un autre système n'a pas le même nom (case-insensitive)
        if systems.contains(where: { $0.id != system.id && $0.name.lowercased() == system.name.lowercased() }) {
            throw SystemUpdateError.duplicateName
        }
        
        // Mettre à jour via le store
        let updatedSystem = try await systemStore.update(system)
        
        // Mettre à jour la liste locale
        if let index = systems.firstIndex(where: { $0.id == system.id }) {
            systems[index] = updatedSystem
        }
    }
    
    enum SystemUpdateError: LocalizedError {
        case systemNotFound
        case duplicateName
        
        var errorDescription: String? {
            switch self {
            case .systemNotFound:
                return "Le système à modifier n'a pas été trouvé."
            case .duplicateName:
                return "Un système avec ce nom existe déjà."
            }
        }
    }
    
    func deleteSystem(_ system: TradingSystem) async throws {
        // Ne pas permettre la suppression du dernier système
        guard systems.count > 1 else {
            throw SystemDeletionError.cannotDeleteLastSystem
        }
        
        // Trouver un autre système pour réassigner les trades
        guard let alternativeSystem = systems.first(where: { $0.id != system.id }) else {
            throw SystemDeletionError.noAlternativeSystem
        }
        
        // Identifier les trades à réassigner avant la modification
        let tradesToReassign = trades.filter { $0.systemId == system.id }
        
        // Réassigner les trades à un autre système (mise à jour directe dans la liste)
        trades = trades.map { trade in
            if trade.systemId == system.id {
                var updatedTrade = trade
                updatedTrade.systemId = alternativeSystem.id
                return updatedTrade
            }
            return trade
        }
        
        // Sauvegarder les trades réassignés via le store
        for trade in tradesToReassign {
            var updatedTrade = trade
            updatedTrade.systemId = alternativeSystem.id
            do {
                _ = try await tradeStore.update(updatedTrade)
            } catch {
                print("⚠️ Erreur lors de la mise à jour du trade \(trade.id): \(error)")
            }
        }
        
        // Supprimer le système via le store
        try await systemStore.delete(system)
        
        // Mettre à jour la liste locale
        systems.removeAll { $0.id == system.id }
    }
    
    enum SystemDeletionError: LocalizedError {
        case cannotDeleteLastSystem
        case noAlternativeSystem
        
        var errorDescription: String? {
            switch self {
            case .cannotDeleteLastSystem:
                return "Impossible de supprimer le dernier système. Créez d'abord un autre système."
            case .noAlternativeSystem:
                return "Aucun système alternatif disponible pour réassigner les trades."
            }
        }
    }
    
    func loadTestData() {
        // S'assurer que les systèmes existent
        guard !systems.isEmpty else {
            print("⚠️ Aucun système disponible pour générer les trades de test")
            return
        }
        
        let symbols = ["BTC", "ETH", "SOL", "AVAX", "MATIC", "LINK", "UNI", "AAVE"]
        let calendar = Calendar.current
        let today = Date()
        
        guard let defaultExId = defaultExchangeId else {
            print("⚠️ Aucun exchange par défaut disponible")
            return
        }
        
        print("🔄 Génération de 150 trades de test avec \(systems.count) systèmes disponibles")
        
        var generatedTrades: [Trade] = []
        var flashPnLTrades = 0
        var priceTrades = 0
        
        for _ in 0..<150 {
            let daysAgo = Int.random(in: 0...60)
            guard let tradeDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            
            let symbol = symbols.randomElement()!
            let type: TradeType = Bool.random() ? .long : .short
            let system = systems.randomElement()! // Chaque trade est associé à un système
            let session = Session.allCases.randomElement()!
            let orderRole: OrderRole = Bool.random() ? .maker : .taker
            
            let isWin = Double.random(in: 0...1) < 0.7
            
            if Double.random(in: 0...1) < 0.3 {
                let flashPnL: Double
                if isWin {
                    flashPnL = Double.random(in: 50...500)
                } else {
                    flashPnL = -Double.random(in: 30...300)
                }
                
                let trade = Trade(
                    date: tradeDate,
                    symbol: symbol,
                    type: type,
                    leverage: 1.0,
                    exchangeId: defaultExId,
                    orderRole: orderRole,
                    systemId: system.id, // Système associé
                    session: session,
                    flashPnLNet: flashPnL,
                    status: .closed, // Tous les trades sont fermés
                    closedAt: tradeDate
                )
                generatedTrades.append(trade)
                flashPnLTrades += 1
            } else {
                let basePrice = Double.random(in: 100...50000)
                let quantity = Double.random(in: 0.1...2.0)
                let leverage = [1.0, 2.0, 3.0, 5.0].randomElement()!
                
                let entryPrice = basePrice
                let priceChangePercent: Double
                
                if isWin {
                    priceChangePercent = Double.random(in: 0.5...5.0) / 100.0
                } else {
                    priceChangePercent = -Double.random(in: 0.3...3.0) / 100.0
                }
                
                let exitPrice: Double
                if type == .long {
                    exitPrice = entryPrice * (1 + priceChangePercent)
                } else {
                    exitPrice = entryPrice * (1 - priceChangePercent)
                }
                
                let trade = Trade(
                    date: tradeDate,
                    symbol: symbol,
                    type: type,
                    entryPrice: entryPrice,
                    exitPrice: exitPrice,
                    quantity: quantity,
                    leverage: leverage,
                    exchangeId: defaultExId,
                    orderRole: orderRole,
                    systemId: system.id, // Système associé
                    session: session,
                    status: .closed, // Tous les trades sont fermés
                    closedAt: tradeDate
                )
                generatedTrades.append(trade)
                priceTrades += 1
            }
        }
        
        // Trier par date
        generatedTrades.sort { $0.date > $1.date }
        
        // Sauvegarder dans le store et mettre à jour l'état
        Task { @MainActor in
            do {
                print("🔄 [loadTestData] Début de la sauvegarde de \(generatedTrades.count) trades")
                print("🔄 [loadTestData] Vérification de la base de données...")
                
                // Vérifier que la base de données est accessible
                let testTrades = try await tradeStore.fetchAll()
                print("🔄 [loadTestData] Base de données accessible: \(testTrades.count) trades existants")
                
                // Supprimer les anciens trades
                print("🔄 [loadTestData] Suppression de \(testTrades.count) trades existants")
                var deletedCount = 0
                for trade in testTrades {
                    do {
                    try await tradeStore.delete(trade)
                        deletedCount += 1
                    } catch {
                        print("❌ [loadTestData] Erreur lors de la suppression du trade \(trade.symbol): \(error)")
                    }
                }
                print("✅ [loadTestData] \(deletedCount)/\(testTrades.count) trades supprimés")
                
                // Vider appState.trades immédiatement après la suppression
                trades = []
                objectWillChange.send()
                print("🔄 [loadTestData] appState.trades vidé et UI notifiée")
                
                // Créer les nouveaux trades dans le store et les ajouter un par un
                print("🔄 [loadTestData] Création de \(generatedTrades.count) nouveaux trades dans SQLite")
                var createdCount = 0
                var errorCount = 0
                
                for (index, trade) in generatedTrades.enumerated() {
                    do {
                        let savedTrade = try await tradeStore.create(trade)
                        // Ajouter immédiatement à appState.trades (comme addTrade le fait)
                        trades.append(savedTrade)
                        createdCount += 1
                        
                        if createdCount % 50 == 0 {
                            print("📊 [loadTestData] Progression: \(createdCount)/\(generatedTrades.count) trades créés et ajoutés")
                            objectWillChange.send()
                            // Rafraîchir les analytics périodiquement
                        refreshAnalytics()
                        }
                    } catch {
                        errorCount += 1
                        print("❌ [loadTestData] Erreur lors de la création du trade \(index + 1)/\(generatedTrades.count) (\(trade.symbol)): \(error)")
                        if errorCount > 10 {
                            print("❌ [loadTestData] Trop d'erreurs (\(errorCount)), arrêt de la génération")
                            break
                        }
                    }
                }
                
                // Trier par date après tous les ajouts
                trades.sort { $0.date > $1.date }
                
                print("✅ [loadTestData] \(createdCount) trades créés dans SQLite et ajoutés à appState.trades")
                if errorCount > 0 {
                    print("⚠️ [loadTestData] \(errorCount) erreurs rencontrées lors de la création")
                }
                print("📊 [loadTestData] Détail: \(flashPnLTrades) trades avec flashPnL, \(priceTrades) trades avec prix")
                
                // Forcer le rafraîchissement final des analytics
                objectWillChange.send()
                refreshAnalytics()
                print("📊 [loadTestData] Analytics rafraîchis avec \(trades.count) trades")
                        
                        // Vérifier que les trades sont bien dans l'état
                print("🔍 [loadTestData] Vérification finale: \(trades.count) trades dans appState.trades")
                        let sampleTrades = trades.prefix(3)
                print("🔍 [loadTestData] Échantillon de trades: \(sampleTrades.map { "\($0.symbol) - PnL: \(netPnL(for: $0) ?? 0)" }.joined(separator: ", "))")
                
                // Recharger depuis SQLite pour vérification (optionnel, pour s'assurer de la synchronisation)
                do {
                    let reloadedTrades = try await tradeStore.fetchAll()
                    print("🔍 [loadTestData] Vérification SQLite: \(reloadedTrades.count) trades dans la base")
                    if reloadedTrades.count != trades.count {
                        print("⚠️ [loadTestData] Incohérence détectée: \(trades.count) dans appState vs \(reloadedTrades.count) dans SQLite")
                        print("🔄 [loadTestData] Resynchronisation depuis SQLite...")
                        // Resynchroniser depuis SQLite
                        trades = reloadedTrades.sorted { $0.date > $1.date }
                        objectWillChange.send()
                        refreshAnalytics()
                        print("✅ [loadTestData] Resynchronisation terminée: \(trades.count) trades dans appState")
                    } else {
                        print("✅ [loadTestData] Synchronisation OK: \(trades.count) trades dans appState et SQLite")
                    }
                } catch {
                    print("⚠️ [loadTestData] Erreur lors de la vérification SQLite: \(error)")
                }
            } catch {
                print("❌ [loadTestData] Erreur lors de la sauvegarde des trades: \(error)")
            }
        }
    }
    
    func clearAllTrades() {
        trades.removeAll()
        // Sauvegarder dans le store
        Task {
            do {
                let allTrades = try await tradeStore.fetchAll()
                for trade in allTrades {
                    try await tradeStore.delete(trade)
                }
                print("✅ Tous les trades ont été supprimés")
            } catch {
                print("❌ Erreur lors de la suppression des trades: \(error)")
            }
        }
    }
    
    func clearAllData() {
        // Supprimer tous les trades
        trades.removeAll()
        
        // Supprimer tous les systèmes (sauf le premier si nécessaire)
        if systems.count > 1 {
            let systemsToDelete = Array(systems.dropFirst())
            for system in systemsToDelete {
                Task {
                    do {
                        try await deleteSystem(system)
                    } catch {
                        print("⚠️ Erreur lors de la suppression du système \(system.name): \(error)")
                    }
                }
            }
        }
        
        // Supprimer tous les exchanges (sauf le premier si nécessaire)
        if exchanges.count > 1 {
            let exchangesToDelete = Array(exchanges.dropFirst())
            for exchange in exchangesToDelete {
                Task {
                    do {
                        try await exchangeStore.delete(exchange)
                    } catch {
                        print("⚠️ Erreur lors de la suppression de l'exchange \(exchange.name): \(error)")
                    }
                }
            }
        }
        
        // Supprimer tous les trades du store
        Task {
            do {
                let allTrades = try await tradeStore.fetchAll()
                for trade in allTrades {
                    try await tradeStore.delete(trade)
                }
                print("✅ Toutes les données ont été supprimées")
            } catch {
                print("❌ Erreur lors de la suppression des données: \(error)")
            }
        }
    }
    
    func generateTestSystems() {
        let systemNames = [
            "Scalping BTC",
            "Swing Trading ETH",
            "Breakout Strategy",
            "Mean Reversion",
            "Trend Following",
            "Momentum Trading",
            "Grid Trading",
            "DCA Strategy",
            "Arbitrage Bot",
            "Market Making"
        ]
        
        let systemColors: [String] = [
            "#0A85FF", "#22C759", "#FF9500", "#FF3B30", "#BF5AF2",
            "#5AC8FA", "#FF2D55", "#34C759", "#FF9500", "#007AFF"
        ]
        
        // Créer les systèmes s'ils n'existent pas déjà
        for (index, name) in systemNames.enumerated() {
            if !systems.contains(where: { $0.name == name }) {
                let system = TradingSystem(
                    name: name,
                    color: systemColors[index % systemColors.count]
                )
                addSystem(system)
            }
        }
        
        print("✅ \(systemNames.count) systèmes de test créés")
    }
    
    func generateMassiveTestDataAsync(count: Int) async {
        // S'assurer qu'on a des systèmes
        if systems.isEmpty {
            generateTestSystems()
        }
        
        // S'assurer qu'on a un exchange
        if exchanges.isEmpty {
            let defaultExchange = Exchange(
                name: "Binance",
                makerFeeRate: 0.1,
                takerFeeRate: 0.1,
                isDefault: true
            )
            addExchange(defaultExchange)
        }
        
        guard let defaultExId = defaultExchangeId else {
            print("⚠️ Aucun exchange disponible")
            return
        }
        
        let symbols = ["BTC", "ETH", "SOL", "AVAX", "MATIC", "LINK", "UNI", "AAVE", "DOT", "ADA", "XRP", "DOGE", "BNB", "ATOM", "ALGO"]
        let calendar = Calendar.current
        let today = Date()
        
        print("🔄 Génération de \(count) trades de test...")
        
        let batchSize = 500
        var totalGenerated = 0
        
        // Générer par lots pour éviter de bloquer l'UI
        for batch in stride(from: 0, to: count, by: batchSize) {
            let currentBatchSize = min(batchSize, count - batch)
            var batchTrades: [Trade] = []
            
            for _ in 0..<currentBatchSize {
                let daysAgo = Int.random(in: 0...365) // Sur une année
                guard let tradeDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
                
                let symbol = symbols.randomElement()!
                let type: TradeType = Bool.random() ? .long : .short
                let system = systems.randomElement()!
                let session = Session.allCases.randomElement()!
                let orderRole: OrderRole = Bool.random() ? .maker : .taker
                let isWin = Double.random(in: 0...1) < 0.65 // 65% de win rate
                
                let basePrice = Double.random(in: 100...50000)
                let quantity = Double.random(in: 0.01...5.0)
                let leverage = [1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0].randomElement()!
                
                let entryPrice = basePrice
                let priceChangePercent: Double
                
                if isWin {
                    priceChangePercent = Double.random(in: 0.3...8.0) / 100.0
                } else {
                    priceChangePercent = -Double.random(in: 0.2...5.0) / 100.0
                }
                
                let exitPrice: Double
                if type == .long {
                    exitPrice = entryPrice * (1 + priceChangePercent)
                } else {
                    exitPrice = entryPrice * (1 - priceChangePercent)
                }
                
                let trade = Trade(
                    date: tradeDate,
                    symbol: symbol,
                    type: type,
                    entryPrice: entryPrice,
                    exitPrice: exitPrice,
                    quantity: quantity,
                    leverage: leverage,
                    exchangeId: defaultExId,
                    orderRole: orderRole,
                    systemId: system.id,
                    session: session,
                    status: .closed, // Tous les trades sont fermés
                    closedAt: tradeDate
                )
                
                batchTrades.append(trade)
            }
            
            // Sauvegarder le lot dans le store
            do {
                for trade in batchTrades {
                    _ = try await tradeStore.create(trade)
                }
                
                // Ajouter au tableau local
                await MainActor.run {
                    trades.append(contentsOf: batchTrades)
                    totalGenerated += batchTrades.count
                    print("📊 Progression: \(totalGenerated)/\(count) trades générés")
                    print("📊 État actuel: \(trades.count) trades dans appState.trades")
                    // Rafraîchir les analytics après chaque lot pour que les données soient à jour
                    refreshAnalytics()
                }
            } catch {
                print("⚠️ Erreur lors de la sauvegarde du lot: \(error)")
            }
            
            // Petit délai pour ne pas surcharger
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Recharger tous les trades depuis le store pour s'assurer qu'ils sont bien synchronisés
        do {
            let allTrades = try await tradeStore.fetchAll()
            print("🔍 [generateMassiveTestDataAsync] Trades récupérés du store: \(allTrades.count)")
            
            await MainActor.run {
                let previousCount = trades.count
                // Assigner directement pour déclencher didSet
                self.trades = allTrades.sorted { $0.date > $1.date }
                print("✅ Génération terminée: \(trades.count) trades créés (était \(previousCount))")
                print("🔍 Vérification finale: \(trades.count) trades dans appState.trades")
                
                // Vérifier que les trades ont un PnL calculable
                let tradesWithPnL = trades.compactMap { trade -> (Trade, Double)? in
                    guard let pnl = netPnL(for: trade) else { return nil }
                    return (trade, pnl)
                }
                print("🔍 Trades avec PnL calculable: \(tradesWithPnL.count)/\(trades.count)")
                
                // Calculer les stats pour vérifier
                let testStats = Statistics.calculate(trades: trades, appState: self)
                print("🔍 Stats calculées: Win Rate=\(testStats.winRate)%, Total PnL=$\(testStats.totalPnL), Total Trades=\(testStats.totalTrades)")
                
                // Le didSet de trades devrait déjà appeler refreshAnalytics(), mais on le force aussi
                refreshAnalytics()
                print("✅ Analytics rafraîchis après génération massive")
            }
        } catch {
            print("❌ Erreur lors du rechargement final des trades: \(error)")
            // Fallback: utiliser les trades déjà dans l'état
            await MainActor.run {
                trades.sort { $0.date > $1.date }
                refreshAnalytics()
            }
        }
    }
    
    func generateTestMoodData(count: Int = 200, highPressureBias: Double = 0.35) async {
        guard !trades.isEmpty else {
            print("⚠️ Aucun trade disponible pour générer des données émotionnelles")
            return
        }
        
        let emotionalStates: [EmotionalState] = [
            .confident, .stressed, .impatient, .fearful, .greedy,
            .calm, .excited, .frustrated, .focused, .distracted
        ]
        let highPressureStates: [EmotionalState] = [
            .frustrated, .impatient, .fearful, .stressed, .greedy
        ]
        
        let contexts: [MoodContext] = [
            .beforeTrade, .afterTrade, .duringMarket, .afterLoss, .afterWin, .endOfDay
        ]
        let highPressureContexts: [MoodContext] = [
            .afterTrade, .afterLoss, .duringMarket
        ]
        let highPressureTriggers: [MoodTrigger] = [.revenge, .fomo, .loss, .fatigue, .externalStress]
        
        let notes = [
            "Bonne analyse technique",
            "Marché volatile",
            "Stop loss touché",
            "Take profit atteint",
            "Sentiment positif",
            "Hésitation avant l'entrée",
            "Confiance dans la stratégie",
            "Stress lié à la volatilité",
            "Satisfaction du résultat",
            "Déception après la perte"
        ]
        
        let maxDays = 365
        let clampedCount = min(count, maxDays)
        let clampedBias = max(0.0, min(1.0, highPressureBias))
        print("🔄 Génération de \(clampedCount) entrées émotionnelles (1 / jour) — highPressure: \(clampedBias)...")
        
        var generatedMoods: [MoodEntry] = []
        let calendar = Calendar.current
        let today = Date()

        // ✅ 1 émotion / jour : on échantillonne des jours uniques sur les 12 derniers mois
        var candidateDays: [Date] = (0..<maxDays).compactMap { daysAgo in
            calendar.date(byAdding: .day, value: -daysAgo, to: today).map { calendar.startOfDay(for: $0) }
        }
        candidateDays.shuffle()
        let selectedDays = Array(candidateDays.prefix(clampedCount))
        
        for day in selectedDays {
            // Timestamp : même jour, heure "réaliste" (9h–22h)
            let hour = Int.random(in: 9...22)
            let minute = Int.random(in: 0...59)
            let moodDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            
            // Associer à un trade du même jour dans 70% des cas (sinon nil)
            let tradeId: UUID? = {
                guard Double.random(in: 0...1) < 0.7 else { return nil }
                let dayTrades = trades.filter { calendar.startOfDay(for: $0.date) == day }
                return (dayTrades.randomElement() ?? trades.randomElement())?.id
            }()

            // ✅ Pousser une partie des jours vers "danger" (sans calcul métier)
            let highPressure = Double.random(in: 0...1) < clampedBias
            let emotionalState = (highPressure ? highPressureStates : emotionalStates).randomElement()!
            let context = (highPressure ? highPressureContexts : contexts).randomElement()!
            let intensity = highPressure ? Int.random(in: 8...10) : Int.random(in: 4...7)
            let trigger = highPressure ? highPressureTriggers.randomElement() : nil
            let controlLevel = highPressure ? Int.random(in: 0...3) : Int.random(in: 5...9)
            let isExceptional = highPressure && Double.random(in: 0...1) < 0.5
            let note = notes.randomElement()!
            
            // Créer l'entrée avec un timestamp personnalisé
            let mood = MoodEntry(
                id: UUID(),
                tradeId: tradeId,
                emotionalState: emotionalState,
                intensity: intensity,
                notes: note,
                timestamp: moodDate,
                context: context,
                trigger: trigger,
                controlLevel: controlLevel,
                isExceptional: isExceptional,
                source: .manual
            )
            
            generatedMoods.append(mood)
        }
        
        // Sauvegarder dans le store
        do {
            for mood in generatedMoods {
                try await moodStore.addMood(mood)
            }
            
            // Mettre à jour l'état local (on laisse le store / publisher être la source de vérité)
            await MainActor.run {
                moodEntries = moodStore.moods
                refreshAnalytics() // Rafraîchir les analytics
                print("✅ Génération terminée: \(generatedMoods.count) entrées émotionnelles créées (1 / jour)")
            }
        } catch {
            print("❌ Erreur lors de la sauvegarde des données émotionnelles: \(error)")
        }
    }
    
    func reassignTradesToSystems() {
        guard !systems.isEmpty else {
            print("⚠️ Aucun système disponible pour réassigner les trades")
            return
        }
        
        print("🔄 Réassignation des \(trades.count) trades aux \(systems.count) systèmes")
        
        var reassignedCount = 0
        trades = trades.map { trade in
            var updated = trade
            if system(for: trade.systemId) == nil {
                if let randomSystem = systems.randomElement() {
                    updated.systemId = randomSystem.id
                    reassignedCount += 1
                }
            }
            return updated
        }
        
        print("✅ \(reassignedCount) trades réassignés aux systèmes")
    }
}

// MARK: - Period Filter
enum PeriodFilter: String, CaseIterable, Identifiable {
    case all = "All time"
    case currentWeek = "This week"
    case lastWeek = "Last week"
    case last2Weeks = "Last 2 weeks"
    case lastMonth = "Last month"
    case last3Months = "Last 3 months"
    case last6Months = "Last 6 months"
    case lastYear = "Last year"
    
    var id: String { rawValue }
}

// MARK: - Analytics Tab Type
enum AnalyticsTab: String, CaseIterable {
    case analytics = "Analytics"
    case timeMetrics = "Time metrics"
    case calendar = "Calendar"
    
    func localizedName(language: Localizable.Language) -> String {
        switch self {
        case .analytics:   return Localizable.text("tabAnalytics", language: language)
        case .timeMetrics: return Localizable.text("tabMetrics", language: language)
        case .calendar:    return Localizable.text("tabCalendar", language: language)
        }
    }
    
    var displayName: String {
        switch self {
        case .analytics: return "Analytics"
        case .timeMetrics: return "Métriques"
        case .calendar: return "Calendrier"
        }
    }
    
    var icon: String {
        switch self {
        case .analytics: return "chart.bar.fill"
        case .timeMetrics: return "clock.fill"
        case .calendar: return "calendar"
        }
    }
}
