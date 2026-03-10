import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

class AppState: ObservableObject {
    // ✅ Lazy singleton pour garantir que Firebase est configuré avant
    // AppState.shared ne sera créé qu'au premier accès, après que Firebase soit configuré dans @main init()
    static let shared: AppState = {
        print("🔧 [AppState] Création de AppState.shared...")
        // Vérifier que Firebase est configuré
        if FirebaseAvailability.isConfigured {
            print("✅ [AppState] Firebase est configuré - utilisation des stores Firestore")
        } else {
            print("⚠️ [AppState] Firebase non configuré - utilisation du stockage local")
        }
        return AppState()
    }()
    
    @Published var apiManager = APIManager()
    @Published var authManager = AuthManager()
    @Published var trades: [Trade] = [] {
        didSet {
            debouncedRefreshAnalytics()
        }
    }
    @Published var moodEntries: [MoodEntry] = [] {
        didSet { debouncedRefreshAnalytics() }
    }
    @Published var exchanges: [Exchange] = []
    @Published var systems: [TradingSystem] = []
    @Published var alerts: [Alert] = []
    @Published var storageMode: StorageMode = .local
    
    // Flag pour empêcher le rechargement pendant l'ajout de trades
    var isAddingTrade = false
    var isLoadingData = false
    
    // Debouncer pour optimiser les recalculs d'analytics
    @MainActor private let analyticsDebouncer = MainActorDebouncer(delay: 0.8) // 0.8s — évite recalculs en cascade sur batch imports
    @Published var coachIAState: CoachIAState = .initial
    @Published var emotionPerformanceAnalysis: EmotionPerformanceAnalysis = .empty
    @Published var assistantReport: AssistantAIReport = .placeholder
    @Published var trendRecommendation: String = ""
    @Published var marketConfluence: String = ""
    @Published var fundingRate: Double = 0
    @Published var technicalSummary: String = ""
    @Published var riskScore: Int = 50
    @Published var emotionScore: Int = 50
    @Published var aiRecommendations: [String] = []
    @Published var indicatorSnapshots: [AssistantAIIndicatorSnapshot] = []
    
    // MARK: - Emotional load (0..100) — cached for low-latency visuals
    @Published var emotionalLoadByDay: [Date: Double] = [:]
    /// Incrémenté à chaque mise à jour de `emotionalLoadByDay` (même si le nombre de jours ne change pas).
    /// Sert de clé légère pour déclencher les rebuilds de caches UI (Dashboard) sans faire de hash coûteux.
    @Published var emotionalLoadVersion: Int = 0
    @Published var isPremiumUser: Bool = false {
        didSet {
            // Sauvegarder le statut localement
            SubscriptionStore.shared.savePremiumStatus(isPremiumUser)

            // ✅ Sync Firestore: rendre visible proActive dans `users/{uid}`
            if oldValue != isPremiumUser {
                Task { await syncProStatusToFirestore(force: true) }
            }
        }
    }

    // 🔎 Debug/visibilité: valeur lue depuis Firestore (users/{uid}.proActive)
    @Published var firestoreIsPro: Bool? = nil
    @Published var firestoreProUpdatedAt: Date? = nil
    @Published var firestoreProSource: String? = nil

    #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
    private var userDocListener: ListenerRegistration?
    #endif
    
    
    // Subscription Manager
    let subscriptionManager = SubscriptionManager.shared
    
    // Store protocols
    var tradeStore: TradeStore
    var exchangeStore: ExchangeStore
    var systemStore: SystemStore
    var apiStore: APIStore
    var alertStore: AlertStore
    var moodStore: any MoodStore
    var prestigeStore: PrestigeStore?
    var challengeStore: ChallengeStore?
    
    // Services
    let coachIAService = CoachIAService()
    let emotionPerformanceService = EmotionPerformanceService()
    let assistantAIService = AssistantAIService()
    let emotionalLoadService = EmotionalLoadService()
    let pushService = PushService.shared
    let deepLinkRouter = DeepLinkRouter.shared
    let webhookVerifier = WebhookVerifier()
    let prestigeEngine: PrestigeEngine
    let challengeEngine: ChallengeEngine
    let badgeService: BadgeService
    
    private var cancellables = Set<AnyCancellable>()
    private var moodStoreCancellable: AnyCancellable?
    
    // Migration
    @Published var isMigrating = false
    @Published var migrationProgress: Double = 0
    @Published var migrationStatus: String = ""
    
    init() {
        Logger.appState.info("Création d'une nouvelle instance d'AppState")
        
        // Initialize default data
        exchanges = [
            // Références des frais (ordre de grandeur) d'après les sources fournies
            // Binance ~0.10% / 0.10%
            Exchange(name: "Binance", makerFeeRate: 0.0010, takerFeeRate: 0.0010, isDefault: true),
            // Bybit ~0.20% / 0.15%
            Exchange(name: "Bybit", makerFeeRate: 0.0020, takerFeeRate: 0.0015, isDefault: false),
            // OKX ~0.08% / 0.10% (référence actuelle du projet)
            Exchange(name: "OKX", makerFeeRate: 0.0008, takerFeeRate: 0.0010, isDefault: false),
            // Kraken ~0.25% / 0.40%
            Exchange(name: "Kraken", makerFeeRate: 0.0025, takerFeeRate: 0.0040, isDefault: false),
            // KuCoin ~0.10% / 0.10%
            Exchange(name: "KuCoin", makerFeeRate: 0.0010, takerFeeRate: 0.0010, isDefault: false),
            // Coinbase (spot) ~0.50% / 0.50% (plafond indiqué)
            Exchange(name: "Coinbase", makerFeeRate: 0.0050, takerFeeRate: 0.0050, isDefault: false),
            // Gate.io ~0.15% / 0.15%
            Exchange(name: "Gate.io", makerFeeRate: 0.0015, takerFeeRate: 0.0015, isDefault: false),
            // Bitget (valeurs existantes conservées)
            Exchange(name: "Bitget", makerFeeRate: 0.0002, takerFeeRate: 0.0006, isDefault: false),
            // MEXC (valeurs projet existantes)
            Exchange(name: "MEXC", makerFeeRate: 0.0000, takerFeeRate: 0.0001, isDefault: false),
            // Cryptomus: maker jusqu'à 0.04%, taker jusqu'à 0.70%
            Exchange(name: "Cryptomus", makerFeeRate: 0.0004, takerFeeRate: 0.0070, isDefault: false)
        ]
        
        systems = [
            TradingSystem(name: "VMC", color: "#00D9FF"),
            TradingSystem(name: "Breakout", color: "#FF6B6B"),
            TradingSystem(name: "Scalping", color: "#4ECDC4"),
            TradingSystem(name: "Swing", color: "#FFE66D")
        ]
        
        // Load storage mode from settings without referencing self before stores init
        let savedMode = StorageMode(rawValue: UserDefaults.standard.string(forKey: "storageMode") ?? "local") ?? .local
        storageMode = savedMode
        
        // Initialize stores based on the saved mode
        (tradeStore, exchangeStore, systemStore, apiStore, alertStore, prestigeStore, challengeStore) = Self.createStores(for: savedMode)
        moodStore = AppState.createMoodStore(for: savedMode)
        
        // Initialize engines
        prestigeEngine = PrestigeEngine(store: prestigeStore)
        challengeEngine = ChallengeEngine(store: challengeStore)
        badgeService = BadgeService(store: prestigeStore)
        
        // Initialize services
        pushService.setupNotificationCategories()
        
        // Load data from stores
        loadDataFromStores()
        
        // Bind mood store updates
        bindMoodStore()
        
        // Générer les analyses initiales
        refreshAnalytics()
        
        // Initialiser la synchronisation automatique si activée
        setupAutoSync()
        
        // Charger le statut premium depuis le stockage local
        isPremiumUser = SubscriptionStore.shared.loadPremiumStatus()
        
        // Écouter les changements d'abonnement
        setupSubscriptionObserver()
        
        // Réagir aux changements d'auth (utile en mode Firebase)
        setupAuthObserver()
        
        // Vérifier le statut d'abonnement si nécessaire
        if SubscriptionStore.shared.shouldCheckAgain() {
            Task {
                await subscriptionManager.checkSubscriptionStatus()
                await MainActor.run {
                    isPremiumUser = subscriptionManager.isPremiumActive
                }
            }
        }
        
        // ✅ Les clés API sont désormais gérées par Firebase Cloud Functions
        // Plus aucune clé hardcodée côté iOS
        
        print("✅ AppState.init() - Initialisation terminée avec \(trades.count) trades et \(systems.count) systèmes")
    }
    
    // MARK: - Twelve Data API (géré par Firebase Cloud Functions)
    // Les clés API sont stockées côté serveur — plus rien à initialiser ici.
    
    // MARK: - Finnhub API (géré par Firebase Cloud Functions)
    
    /// Configure l'observateur des changements d'abonnement
    private func setupSubscriptionObserver() {
        subscriptionManager.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                let wasPremium = self.isPremiumUser
                self.isPremiumUser = (status == .subscribed)
                
                if wasPremium != self.isPremiumUser {
                    print("🔄 [AppState] Statut premium changé: \(wasPremium) → \(self.isPremiumUser)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAuthObserver() {
        authManager.$isAuthenticated
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }
                
                if isAuthenticated {
                    print("🔐 [AppState] Utilisateur authentifié")

                    // Sync PRO + listener Firestore user doc pour vérification
                    Task {
                        await self.syncProStatusToFirestore(force: true)
                        self.startUserEntitlementsListener()
                    }
                    
                    // Si Firebase est configuré et que l'utilisateur n'est pas en mode Firebase
                    if FirebaseAvailability.isConfigured && self.storageMode == .local {
                        // Migrer automatiquement les données locales vers Firestore
                        print("🔄 [AppState] Migration automatique vers Firestore...")
                        Task {
                            // Vérifier s'il y a des données à migrer
                            let hasLocalData = !self.trades.isEmpty || !self.exchanges.isEmpty || !self.systems.isEmpty
                            
                            if hasLocalData {
                                await self.switchStorageMode(to: .firebase)
                            } else {
                                // Pas de données à migrer, juste changer de mode
                                await MainActor.run {
                                    self.storageMode = .firebase
                                    // Recréer les stores Firebase
                                    let (newTradeStore, newExchangeStore, newSystemStore, newAPIStore, newAlertStore, newPrestigeStore, newChallengeStore) = Self.createFirebaseStores()
                                    self.tradeStore = newTradeStore
                                    self.exchangeStore = newExchangeStore
                                    self.systemStore = newSystemStore
                                    self.apiStore = newAPIStore
                                    self.alertStore = newAlertStore
                                    self.prestigeStore = newPrestigeStore
                                    self.challengeStore = newChallengeStore
                                    UserDefaults.standard.set(StorageMode.firebase.rawValue, forKey: "storageMode")
                                    self.loadDataFromStores()
                                }
                            }
                        }
                    } else if self.storageMode == .firebase {
                        print("🔐 [AppState] Auth OK (Firebase mode) → rechargement Firestore")
                        self.loadDataFromStores()
                    }
                } else {
                    print("🔐 [AppState] Utilisateur déconnecté")
                    self.stopUserEntitlementsListener()
                    self.firestoreIsPro = nil
                    self.firestoreProUpdatedAt = nil
                    if self.storageMode == .firebase {
                        // En mode Firebase, nettoyer les données quand l'utilisateur se déconnecte
                        print("🔐 [AppState] Déconnexion (Firebase mode) → purge trades/alertes en mémoire")
                        self.trades = []
                        self.alerts = []
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Firestore: PRO sync (users/{uid})
    private func syncProStatusToFirestore(force: Bool) async {
        guard FirebaseAvailability.isConfigured else { return }
        guard authManager.isAuthenticated else { return }

        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        let now = Date()
        let lastCheck = SubscriptionStore.shared.lastCheckDate() ?? now

        // 1) Lire la source actuelle pour ne PAS écraser un accès manuel (vip/admin)
        do {
            let snap = try await userRef.getDocument()
            let existingSource = snap.data()?["proSource"] as? String

            // ✅ StoreKit2 ne peut mettre à jour QUE si proSource == "storekit2" ou inexistant
            if let s = existingSource, s != "storekit2" {
                // vip/admin (ou toute autre source manuelle) -> NE RIEN MODIFIER
                print("🛑 [AppState] Firestore: proSource=\(s) → skip StoreKit sync (uid=\(uid))")
                return
            }
        } catch {
            // Si on ne peut pas lire, on évite d'écraser: fail-closed
            print("❌ [AppState] Firestore: impossible de lire users/\(uid) avant sync proActive: \(error) → skip")
            return
        }

        // 2) Écriture StoreKit2 (merge) — n'écrase pas les autres champs
        // ⚠️ Écriture client-side: pour une sécurité forte, valider côté serveur (Cloud Functions + receipt/App Store Server API).
        var data: [String: Any] = [
            "email": Auth.auth().currentUser?.email as Any,
            "proActive": isPremiumUser,
            "proSource": "storekit2",
            "proUpdatedAt": Timestamp(date: now),
            // subscriptionLastCheckAt : storekit2 uniquement
            "subscriptionLastCheckAt": Timestamp(date: lastCheck)
        ]

        // proExpiresAt: seulement storekit2 (et seulement si on a une date)
        if let exp = subscriptionManager.activeExpirationDate {
            data["proExpiresAt"] = Timestamp(date: exp)
        }

        // Nettoyage legacy: supprimer l'ancien champ `isPro` (merge=true n'efface pas automatiquement)
        data["isPro"] = FieldValue.delete()

        do {
            try await userRef.setData(data, merge: true)
            print("✅ [AppState] Firestore: users/\(uid) mis à jour (proActive=\(isPremiumUser))")
        } catch {
            print("❌ [AppState] Firestore sync proActive error: \(error)")
        }
        #else
        _ = force
        #endif
    }

    private func startUserEntitlementsListener() {
        guard FirebaseAvailability.isConfigured else { return }
        guard authManager.isAuthenticated else { return }

        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        userDocListener?.remove()
        userDocListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    print("❌ [AppState] Firestore user doc listener error: \(err)")
                    return
                }
                guard let data = snap?.data() else { return }
                // Nouveau champ: proActive. Fallback: isPro (anciens documents).
                let isPro = (data["proActive"] as? Bool) ?? (data["isPro"] as? Bool)
                let ts = (data["proUpdatedAt"] as? Timestamp)?.dateValue()
                let src = data["proSource"] as? String
                DispatchQueue.main.async {
                    self.firestoreIsPro = isPro
                    self.firestoreProUpdatedAt = ts
                    self.firestoreProSource = src
                }
            }
        #endif
    }

    private func stopUserEntitlementsListener() {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        userDocListener?.remove()
        userDocListener = nil
        #endif
    }
    
    @MainActor
    func regenerateAIReports() {
        refreshAnalytics()
    }
    
    // MARK: - Badge Management
    
    /// Vérifie et débloque les badges automatiquement
    @MainActor
    func checkBadges() async {
        guard let prestigeStore = prestigeStore else { return }
        
        do {
            let progression = try await prestigeEngine.getProgression()
            let xpEvents = try await prestigeStore.getXPEvents(limit: 1000)
            let challenges = try await challengeEngine.getDailyChallenges() + (try await challengeEngine.getWeeklyChallenges())
            
            let newlyUnlocked = try await badgeService.checkAndUnlockBadges(
                trades: trades,
                moodEntries: moodEntries,
                progression: progression,
                xpEvents: xpEvents,
                challenges: challenges,
                appState: self
            )
            
            if !newlyUnlocked.isEmpty {
                print("🎉 [Badges] \(newlyUnlocked.count) nouveau(x) badge(s) débloqué(s): \(newlyUnlocked.map { $0.name }.joined(separator: ", "))")
                // TODO: Afficher une notification pour les nouveaux badges
            }
        } catch {
            print("❌ [Badges] Erreur lors de la vérification des badges: \(error)")
        }
    }

    var defaultExchangeId: UUID? {
        exchanges.first(where: { $0.isDefault })?.id ?? exchanges.first?.id
    }
    
    var defaultSystemId: UUID? {
        systems.first?.id
    }
    
    // MARK: - Synchronisation automatique
    
    private func setupAutoSync() {
        // Vérifier si la synchronisation automatique est activée
        let autoSyncEnabled = UserDefaults.standard.bool(forKey: "autoSyncEnabled")
        let syncInterval = UserDefaults.standard.integer(forKey: "syncInterval")
        
        if autoSyncEnabled && syncInterval > 0 {
            apiManager.startPeriodicSync(intervalMinutes: syncInterval)
        }
    }
    
    /// Active/désactive la synchronisation automatique
    func toggleAutoSync(enabled: Bool, intervalMinutes: Int = 30) {
        if enabled {
            apiManager.startPeriodicSync(intervalMinutes: intervalMinutes)
        }
        // Note: Pour désactiver complètement, il faudrait implémenter un système de timers plus sophistiqué
    }
    
    private func bindMoodStore() {
        moodStoreCancellable?.cancel()
        moodEntries = moodStore.moods
        moodStoreCancellable = moodStore.moodsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] moods in
                self?.moodEntries = moods
            }
    }
    
    /// Debounce le rafraîchissement des analytics pour éviter les recalculs trop fréquents
    @MainActor func debouncedRefreshAnalytics() {
        analyticsDebouncer.debounce { [weak self] in
            Task { @MainActor in
                self?.refreshAnalytics()
            }
        }
    }
    
    func refreshAnalytics() {
        Logger.appState.debug("Début du rafraîchissement avec \(trades.count) trades")
        let previousState = coachIAState.history.isEmpty ? nil : coachIAState
        let evaluatedState = coachIAService.evaluate(
            trades: trades,
            moods: moodEntries,
            previousState: previousState,
            language: LanguageManager.shared.currentLanguage
        )
        
        if evaluatedState != coachIAState {
            coachIAState = evaluatedState
        }
        
        let analysis = emotionPerformanceService.analyze(trades: trades, moods: moodEntries)
        if analysis != emotionPerformanceAnalysis {
            emotionPerformanceAnalysis = analysis
        }
        
        let assistant = assistantAIService.makeDailyReport(
            trades: trades,
            moods: moodEntries,
            coachState: coachIAState,
            emotionAnalysis: emotionPerformanceAnalysis,
            language: LanguageManager.shared.currentLanguage
        )
        if assistant != assistantReport {
            assistantReport = assistant
        }
        trendRecommendation = assistant.trendRecommendation
        marketConfluence = assistant.marketConfluence
        fundingRate = assistant.fundingRate
        technicalSummary = assistant.technicalSummary
        riskScore = assistant.riskScore
        emotionScore = assistant.emotionScore
        aiRecommendations = assistant.recommendations
        indicatorSnapshots = assistant.indicatorSnapshots

        // ✅ Async compute: charge émotionnelle 0..100 (principalement afterTrade)
        // - Pas de recalcul dans les body des vues
        // - Ne bloque pas l'UI lors d'un tap/scroll
        Task.detached(priority: .utility) { [trades, moodEntries, emotionalLoadService] in
            let cal = Calendar.current
            let loads = await emotionalLoadService.dailyLoadByDay(trades: trades, moods: moodEntries, calendar: cal)
            await MainActor.run {
                // micro-optim: n'écraser que si ça change (évite des refresh UI inutiles)
                if loads != self.emotionalLoadByDay {
                    self.emotionalLoadByDay = loads
                    self.emotionalLoadVersion &+= 1
                }
            }
        }
    }
    
    // MARK: - Store Management
    
    /// Creates stores based on storage mode
    static func createStores(for mode: StorageMode) -> (TradeStore, ExchangeStore, SystemStore, APIStore, AlertStore, PrestigeStore?, ChallengeStore?) {
        switch mode {
        case .firebase:
            if FirebaseAvailability.isConfigured {
                print("✅ [AppState] Mode Firebase actif (Firebase configuré)")
                return createFirebaseStores()
            } else {
                print("⚠️ [AppState] Mode Firebase sélectionné mais Firebase n'est pas configuré. Fallback vers stockage local.")
                return createLocalStores()
            }
        case .local:
            return createLocalStores()
        }
    }
    
    static func createMoodStore(for mode: StorageMode) -> any MoodStore {
        switch mode {
        case .firebase:
            #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
            return FirestoreMoodStore()
            #else
            return LocalMoodStore(database: LocalDatabase.shared)
            #endif
        case .local:
            return LocalMoodStore(database: LocalDatabase.shared)
        }
    }
    
    static func createLocalStores() -> (TradeStore, ExchangeStore, SystemStore, APIStore, AlertStore, PrestigeStore?, ChallengeStore?) {
        print("✅ [AppState] Utilisation du stockage local (SQLite)")
        
        // Vérifier que la base de données est accessible
        let database = LocalDatabase.shared
        print("🔍 [AppState] Vérification de la base de données...")
        
        // Test simple pour vérifier que la base fonctionne
        let testQuery = database.executeQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='trades'", parameters: [])
        print("🔍 [AppState] Test de la base de données: \(testQuery.count) table(s) 'trades' trouvée(s)")
        
        let tradeStore = LocalTradeStore()
        let alertStore = LocalAlertStore()
        let prestigeStore = LocalPrestigeStore(database: database)
        let challengeStore = LocalChallengeStore(database: database)
        // TODO: Créer LocalExchangeStore et LocalSystemStore pour persister aussi les exchanges et systèmes
        return (tradeStore, MockExchangeStore(), MockSystemStore(), MockAPIStore(), alertStore, prestigeStore, challengeStore)
    }
    
    static func createFirebaseStores() -> (TradeStore, ExchangeStore, SystemStore, APIStore, AlertStore, PrestigeStore?, ChallengeStore?) {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        print("✅ [AppState] Utilisation de Firebase (Firestore + Auth)")
        let tradeStore: TradeStore = FirestoreTradeStore()
        let exchangeStore: ExchangeStore = FirestoreExchangeStore()
        let systemStore: SystemStore = FirestoreSystemStore()
        let alertStore: AlertStore = FirestoreAlertStore()
        // TODO: Firestore stores for API/Prestige/Challenges
        return (tradeStore, exchangeStore, systemStore, MockAPIStore(), alertStore, nil, nil)
        #else
        print("⚠️ [AppState] SDK Firebase absent à la compilation. Fallback vers stockage local.")
        return createLocalStores()
        #endif
    }
    
    /// Switch storage mode and migrate data
    func switchStorageMode(to newMode: StorageMode) async {
        guard newMode != storageMode else { return }
        
        await MainActor.run {
            isMigrating = true
            migrationProgress = 0
            migrationStatus = "Préparation de la migration..."
        }
        
        do {
            // Create new stores
            let (newTradeStore, newExchangeStore, newSystemStore, newAPIStore, newAlertStore, newPrestigeStore, newChallengeStore) = Self.createStores(for: newMode)
            
            // Migrate data
            try await migrateData(
                from: (tradeStore, exchangeStore, systemStore, apiStore, alertStore),
                to: (newTradeStore, newExchangeStore, newSystemStore, newAPIStore, newAlertStore)
            )
            
            // Update stores
            self.tradeStore = newTradeStore
            self.exchangeStore = newExchangeStore
            self.systemStore = newSystemStore
            self.apiStore = newAPIStore
            self.alertStore = newAlertStore
            self.moodStore = AppState.createMoodStore(for: newMode)
            self.prestigeStore = newPrestigeStore
            self.challengeStore = newChallengeStore
            self.storageMode = newMode
            bindMoodStore()
            refreshAnalytics()
            
            // Reinitialize engines with new stores
            // Note: engines sont let, donc on ne peut pas les réassigner directement
            // Il faudrait refactoriser pour les rendre var si nécessaire
            
            // Save storage mode
            UserDefaults.standard.set(newMode.rawValue, forKey: "storageMode")
            
            await MainActor.run {
                migrationStatus = "Migration terminée avec succès"
                migrationProgress = 1.0
                isMigrating = false
            }
            
        } catch {
            await MainActor.run {
                migrationStatus = "Erreur lors de la migration: \(error.localizedDescription)"
                isMigrating = false
            }
        }
    }
    
    /// Migrate data between stores
    private func migrateData(
        from oldStores: (TradeStore, ExchangeStore, SystemStore, APIStore, AlertStore),
        to newStores: (TradeStore, ExchangeStore, SystemStore, APIStore, AlertStore)
    ) async throws {
        let (oldTradeStore, oldExchangeStore, oldSystemStore, oldAPIStore, oldAlertStore) = oldStores
        let (newTradeStore, newExchangeStore, newSystemStore, newAPIStore, newAlertStore) = newStores
        
        do {
            // Migrate exchanges
            await MainActor.run {
                migrationStatus = "Migration des exchanges..."
                migrationProgress = 0.1
            }
            
            let exchanges = try await oldExchangeStore.fetchAll()
            for exchange in exchanges {
                _ = try await newExchangeStore.create(exchange)
            }
            
            // Migrate systems
            await MainActor.run {
                migrationStatus = "Migration des systèmes..."
                migrationProgress = 0.3
            }
            
            let systems = try await oldSystemStore.fetchAll()
            for system in systems {
                _ = try await newSystemStore.create(system)
            }
            
            // Migrate trades
            await MainActor.run {
                migrationStatus = "Migration des trades..."
                migrationProgress = 0.5
            }
            
            let trades = try await oldTradeStore.fetchAll()
            for (index, trade) in trades.enumerated() {
                _ = try await newTradeStore.create(trade)
                
                await MainActor.run {
                    migrationProgress = 0.5 + (Double(index) / Double(trades.count)) * 0.3
                }
            }
            
            // Migrate API credentials
            await MainActor.run {
                migrationStatus = "Migration des clés API..."
                migrationProgress = 0.8
            }
            
            let credentials = try await oldAPIStore.fetchAllAPICredentials()
            for credential in credentials {
                try await newAPIStore.saveAPICredentials(credential)
            }
            
            // Migrate alerts
            await MainActor.run {
                migrationStatus = "Migration des alertes..."
                migrationProgress = 0.9
            }
            
            let alerts = try await oldAlertStore.fetchAll()
            for alert in alerts {
                _ = try await newAlertStore.create(alert)
            }
            
        } catch {
            throw error
        }
    }
    
    /// Load data from current stores
    func loadDataFromStores() {
        // Ne pas recharger si on est en train d'ajouter un trade
        guard !isAddingTrade else {
            print("⚠️ [AppState] loadDataFromStores() ignoré car un trade est en cours d'ajout")
            return
        }
        
        // Éviter les rechargements multiples simultanés
        guard !isLoadingData else {
            print("⚠️ [AppState] loadDataFromStores() déjà en cours, ignoré")
            return
        }
        
        isLoadingData = true
        print("📂 loadDataFromStores() - Chargement des données depuis les stores")
        Task {
            defer {
                Task { @MainActor in
                    self.isLoadingData = false
                }
            }
            
            do {
                var loadedExchanges = try await exchangeStore.fetchAll()
                var loadedSystems = try await systemStore.fetchAll()
                let loadedTrades = try await tradeStore.fetchAll()
                let loadedAlerts = try await alertStore.fetchAll()
                
                // Dédupliquer les systèmes par id (prévient les doublons Firestore)
                var seenSystemIds = Set<UUID>()
                loadedSystems = loadedSystems.filter { seenSystemIds.insert($0.id).inserted }
                
                print("📂 Données chargées: \(loadedExchanges.count) exchanges, \(loadedSystems.count) systèmes, \(loadedTrades.count) trades")
                
                // Seed default exchanges/systems into the store on first launch ONLY
                // Guard against race condition: only seed if store is truly empty after dedup
                if loadedExchanges.isEmpty && !self.exchanges.isEmpty {
                    print("📂 Création des exchanges par défaut dans le store")
                    for ex in self.exchanges { _ = try await exchangeStore.create(ex) }
                    loadedExchanges = self.exchanges
                }
                if loadedSystems.isEmpty && !self.systems.isEmpty {
                    // Seed only the 4 default systems, never re-seed if already present
                    let defaultSystems = self.systems.filter { sys in
                        ["VMC", "Breakout", "Scalping", "Swing"].contains(sys.name)
                    }
                    print("📂 Création des systèmes par défaut dans le store (\(defaultSystems.count) systèmes)")
                    for sys in defaultSystems { _ = try await systemStore.create(sys) }
                    loadedSystems = defaultSystems
                }
                
                await MainActor.run {
                    // Ne pas écraser si on est en train d'ajouter un trade
                    guard !self.isAddingTrade else {
                        print("⚠️ [AppState] Chargement ignoré car un trade est en cours d'ajout")
                        return
                    }
                    
                    print("📂 Mise à jour des données dans AppState")
                    self.exchanges = loadedExchanges
                    self.systems = loadedSystems
                    
                    // Fusion intelligente des trades : garder les trades en mémoire qui ne sont pas encore dans SQLite
                    let loadedTradeIds = Set(loadedTrades.map { $0.id })
                    let inMemoryTrades = self.trades.filter { !loadedTradeIds.contains($0.id) }
                    let mergedTrades = (loadedTrades + inMemoryTrades).sorted { $0.date > $1.date }
                    
                    print("📂 [loadDataFromStores] Avant fusion: \(self.trades.count) trades en mémoire, \(loadedTrades.count) depuis SQLite, \(inMemoryTrades.count) à préserver")
                    print("📂 [loadDataFromStores] IDs en mémoire: \(self.trades.map { $0.id.uuidString.prefix(8) })")
                    print("📂 [loadDataFromStores] IDs depuis SQLite: \(loadedTrades.map { $0.id.uuidString.prefix(8) })")
                    
                    self.trades = mergedTrades
                    self.alerts = loadedAlerts
                    print("📂 [loadDataFromStores] Après fusion: \(self.trades.count) trades (\(loadedTrades.count) depuis SQLite + \(inMemoryTrades.count) en mémoire), \(self.systems.count) systèmes")
                    
                    // Forcer la mise à jour de l'UI
                    self.objectWillChange.send()
                    
                    // DÉSACTIVÉ: Chargement des trades ouverts (fonctionnalité non supportée)
                    // Tous les trades sont maintenant fermés (.closed)
                    
                    // Load test data after systems are loaded (LOCAL ONLY)
                    if self.storageMode == .local && self.trades.isEmpty && !self.systems.isEmpty {
                        print("📂 Génération des trades de test après chargement des systèmes")
                        self.loadTestData()
                    }
                }
            } catch {
                print("❌ [AppState] Error loading data from stores: \(error)")
            }
        }
    }
    
    // MARK: - Alert Management
    
    func createAlert(_ alert: Alert) async {
        do {
            let createdAlert = try await alertStore.create(alert)
            await MainActor.run {
                alerts.append(createdAlert)
            }
        } catch {
            print("❌ [AppState] Error creating alert: \(error)")
        }
    }
    
    func markAlertAsRead(_ alert: Alert) async {
        do {
            try await alertStore.markAsRead(alert)
            await MainActor.run {
                if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
                    var updatedAlert = alert
                    updatedAlert = Alert(
                        id: alert.id,
                        createdAt: alert.createdAt,
                        symbol: alert.symbol,
                        exchange: alert.exchange,
                        price: alert.price,
                        message: alert.message,
                        severity: alert.severity,
                        tags: alert.tags,
                        payloadJSON: alert.payloadJSON,
                        isRead: true,
                        source: alert.source,
                        linkedTradeId: alert.linkedTradeId
                    )
                    alerts[index] = updatedAlert
                }
            }
        } catch {
            print("❌ [AppState] Error marking alert as read: \(error)")
        }
    }
    
    func deleteAlert(_ alert: Alert) async {
        do {
            try await alertStore.delete(alert)
            await MainActor.run {
                alerts.removeAll { $0.id == alert.id }
            }
        } catch {
            print("❌ [AppState] Error deleting alert: \(error)")
        }
    }
    
    func exchange(for id: UUID) -> Exchange? {
        exchanges.first(where: { $0.id == id })
    }
    
    func system(for id: UUID) -> TradingSystem? {
        systems.first(where: { $0.id == id })
    }
    
    func netPnL(for trade: Trade) -> Double? {
        // Priorité au flashPnL si disponible
        if let flashPnL = trade.flashPnLNet {
            return flashPnL
        }
        
        // Sinon, calculer à partir des prix d'entrée/sortie
        guard
            let entry = trade.entryPrice,
            let exit = trade.exitPrice,
            let qty = trade.quantity
        else {
            // Si aucun PnL n'est disponible, retourner 0 pour ne pas exclure le trade des statistiques
            // Cela permet d'inclure tous les trades dans les comptages même s'ils n'ont pas de PnL calculable
            return 0.0
        }
        
        // Récupérer l'exchange ou utiliser des valeurs par défaut
        let ex: Exchange
        if let tradeExchange = exchange(for: trade.exchangeId) {
            ex = tradeExchange
        } else if let defaultEx = exchanges.first(where: { $0.isDefault }) {
            ex = defaultEx
        } else if let firstEx = exchanges.first {
            ex = firstEx
        } else {
            // Si aucun exchange n'est disponible, utiliser des frais par défaut (0.1%)
            return PnLCalculator.netPnL(
                entryPrice: entry,
                exitPrice: exit,
                quantity: qty,
                type: trade.type,
                leverage: trade.leverage,
                makerRate: 0.1,
                takerRate: 0.1,
                role: trade.orderRole
            )
        }
        
        return PnLCalculator.netPnL(
            entryPrice: entry,
            exitPrice: exit,
            quantity: qty,
            type: trade.type,
            leverage: trade.leverage,
            makerRate: ex.makerFeeRate,
            takerRate: ex.takerFeeRate,
            role: trade.orderRole
        )
    }
    
    // MARK: - Sauvegarde automatique
    
    /// Sauvegarde tous les trades en attente dans le store
    /// Appelé automatiquement quand l'app passe en arrière-plan ou se ferme
    func savePendingTrades() async {
        print("💾 [AppState] Sauvegarde des trades en attente...")
        print("💾 [AppState] Nombre de trades à vérifier: \(trades.count)")
        let tradesToSave = trades
        
        var savedCount = 0
        var updatedCount = 0
        var errorCount = 0
        var alreadySavedCount = 0
        
        for trade in tradesToSave {
            do {
                // Vérifier si le trade existe déjà dans le store
                let existing = try await tradeStore.fetch(by: trade.id)
                if existing == nil {
                    // Le trade n'existe pas, le sauvegarder
                    _ = try await tradeStore.create(trade)
                    savedCount += 1
                    print("💾 [AppState] Trade sauvegardé: \(trade.symbol)")
                } else {
                    // Le trade existe déjà, vérifier s'il doit être mis à jour
                    if existing != trade {
                        _ = try await tradeStore.update(trade)
                        updatedCount += 1
                        print("💾 [AppState] Trade mis à jour: \(trade.symbol)")
                    } else {
                        alreadySavedCount += 1
                    }
                }
            } catch {
                errorCount += 1
                print("❌ [AppState] Erreur lors de la sauvegarde du trade \(trade.symbol): \(error)")
            }
        }
        
        print("✅ [AppState] Sauvegarde terminée: \(savedCount) nouveaux, \(updatedCount) mis à jour, \(alreadySavedCount) déjà sauvegardés, \(errorCount) erreurs")
    }
}
