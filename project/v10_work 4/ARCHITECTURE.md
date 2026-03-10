# Architecture du Journal de Trading 2025

## Vue d'ensemble

L'application suit une architecture **MVVM (Model-View-ViewModel)** avec **SwiftUI** et utilise un système de stockage hybride (Firebase/Local) avec injection de dépendances.

## Structure des dossiers

```
Journal de trading 2025/
├── Models/
│   ├── Domain/
│   │   └── Alert.swift              # Modèle de domaine pour les alertes
│   └── Models.swift                 # Modèles principaux (Trade, Exchange, etc.)
├── Services/
│   ├── Storage/
│   │   ├── Protocols/
│   │   │   └── TradeStore.swift     # Protocoles de stockage
│   │   ├── Firestore/
│   │   │   └── FirestoreAlertStore.swift
│   │   ├── LocalDB/
│   │   │   ├── LocalDatabase.swift
│   │   │   └── LocalAlertStore.swift
│   │   └── MockStores.swift
│   ├── Notifications/
│   │   ├── PushService.swift
│   │   └── DeepLinkRouter.swift
│   └── Webhooks/
│       ├── WebhookPayload.swift
│       └── WebhookVerifier.swift
├── Views/
│   ├── Alerts/
│   │   ├── AlertsListView.swift
│   │   ├── AlertDetailView.swift
│   │   ├── AlertSettingsView.swift
│   │   └── AlertFiltersView.swift
│   └── Settings/
│       └── StorageSettingsView.swift
└── ContentView.swift
```

## Architecture des composants

### 1. Modèles de données

#### Alert (Modèle de domaine)
```swift
struct Alert: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let symbol: String
    let exchange: String?
    let price: Decimal?
    let message: String
    let severity: AlertSeverity
    let tags: [String]
    let payloadJSON: String
    var isRead: Bool
    let source: AlertSource
    let linkedTradeId: UUID?
}
```

#### Énums associés
- `AlertSeverity`: info, normal, high
- `AlertSource`: tradingView, custom, other
- `StorageMode`: firebase, local

### 2. Protocoles de stockage

Tous les stores implémentent des protocoles standardisés :

```swift
protocol AlertStore {
    func create(_ alert: Alert) async throws -> Alert
    func fetchAll() async throws -> [Alert]
    func fetch(by id: UUID) async throws -> Alert?
    func update(_ alert: Alert) async throws -> Alert
    func delete(_ alert: Alert) async throws
    func markAsRead(_ alert: Alert) async throws
    // + méthodes de requête spécialisées
    
    var alertsPublisher: AnyPublisher<[Alert], Never> { get }
    var unreadCountPublisher: AnyPublisher<Int, Never> { get }
}
```

### 3. Implémentations de stockage

#### Firestore (Cloud)
- `FirestoreAlertStore`: Stockage cloud avec synchronisation temps réel
- Authentification Firebase requise
- Règles de sécurité Firestore configurées

#### Local (SQLite)
- `LocalAlertStore`: Stockage local avec SQLite
- `LocalDatabase`: Gestionnaire de base de données SQLite
- Pas de dépendance réseau

#### Mock (Développement)
- `MockAlertStore`: Implémentation en mémoire pour les tests
- Utilisée par défaut pendant le développement

### 4. Services

#### PushService
- Gestion des notifications push
- Enregistrement des tokens FCM
- Gestion des catégories de notifications
- Support des actions personnalisées

#### DeepLinkRouter
- Routage des liens profonds (`app://alert/{id}`)
- Navigation contextuelle
- Intégration avec SwiftUI NavigationStack

#### WebhookVerifier
- Vérification HMAC des webhooks TradingView
- Protection contre les attaques de replay
- Validation des payloads

### 5. AppState (État global)

```swift
class AppState: ObservableObject {
    @Published var storageMode: StorageMode = .local
    @Published var alerts: [Alert] = []
    
    // Stores injectés
    var alertStore: AlertStore
    var tradeStore: TradeStore
    // ...
    
    // Services
    let pushService = PushService.shared
    let deepLinkRouter = DeepLinkRouter.shared
}
```

### 6. Migration des données

Le système de migration permet de basculer entre les modes de stockage :

```swift
func switchStorageMode(to newMode: StorageMode) async {
    // 1. Créer les nouveaux stores
    let newStores = createStores(for: newMode)
    
    // 2. Migrer les données
    await migrateData(from: oldStores, to: newStores)
    
    // 3. Mettre à jour les références
    self.alertStore = newAlertStore
    self.storageMode = newMode
}
```

## Flux de données

### 1. Création d'alerte
```
TradingView Webhook → Cloud Function → FCM → PushService → AlertStore → AppState → UI
```

### 2. Stockage local
```
User Action → ViewModel → AppState → AlertStore → LocalDatabase → SQLite
```

### 3. Synchronisation Firebase
```
User Action → AppState → FirestoreAlertStore → Firestore → Real-time updates → UI
```

## Sécurité

### 1. Stockage des secrets
- **API Keys**: Stockées dans Keychain uniquement
- **Webhook Secrets**: Jamais persistées en base
- **Tokens FCM**: Gérés par le système iOS

### 2. Validation des webhooks
- Signature HMAC SHA256 obligatoire
- Vérification du timestamp (replay protection)
- Validation des payloads (taille, format)

### 3. Règles Firestore
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/alerts/{alertId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## Configuration

### 1. Variables d'environnement
```swift
struct WebhookConfiguration {
    let secretKey: String = "your_webhook_secret_key"
    let allowedTimestampSkew: TimeInterval = 300 // 5 minutes
    let maxPayloadSize: Int = 1024 * 1024 // 1MB
}
```

### 2. UserDefaults
- `storageMode`: Mode de stockage actuel
- `pushNotificationsEnabled`: État des notifications
- `quietHoursEnabled`: Configuration des heures silencieuses

## Tests

### 1. Tests unitaires
- Validation HMAC des webhooks
- Conversion des modèles de données
- Logique métier des stores

### 2. Tests d'intégration
- Migration entre modes de stockage
- Synchronisation Firestore
- Notifications push

### 3. Tests UI
- Navigation des alertes
- Filtres et recherche
- Actions utilisateur

## Déploiement

### 1. Cloud Function
```javascript
exports.tvWebhook = functions.https.onRequest(async (req, res) => {
  // 1. Vérifier la signature HMAC
  // 2. Valider le payload
  // 3. Résoudre l'utilisateur
  // 4. Créer l'alerte (Firebase mode)
  // 5. Envoyer notification FCM
});
```

### 2. Configuration iOS
- Capabilities: Push Notifications, Background Modes
- URL Schemes: `app://`
- Firebase configuration: `GoogleService-Info.plist`

## Performance

### 1. Optimisations
- Pagination des alertes
- Cache local pour mode offline
- Lazy loading des images
- Debouncing des recherches

### 2. Monitoring
- Logs structurés avec emojis
- Métriques de performance
- Alertes d'erreur automatiques

## Roadmap

### Phase 1 ✅ (Actuelle)
- [x] Architecture de base
- [x] Modèles de données
- [x] Stores locaux
- [x] Interface utilisateur

### Phase 2 🔄 (En cours)
- [ ] Implémentation Firestore complète
- [ ] Cloud Functions
- [ ] Tests automatisés
- [ ] Documentation API

### Phase 3 📋 (Prévue)
- [ ] Analytics avancées
- [ ] Export/Import de données
- [ ] Synchronisation multi-appareils
- [ ] Widgets iOS

## Support

Pour toute question sur l'architecture :
1. Consultez les logs de débogage (emojis 🔍, ✅, ❌)
2. Vérifiez les erreurs dans la console Xcode
3. Testez avec les stores Mock en premier
4. Validez la configuration Firebase











