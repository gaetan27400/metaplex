# Journal de Trading 2025 📊

Application iOS de journal de trading avancé avec système d'alertes, stockage hybride et intégration TradingView.

## ✅ État actuel

### Fonctionnalités implémentées
- ✅ **Architecture complète** MVVM + SwiftUI
- ✅ **Système de stockage hybride** (Firebase/Local)
- ✅ **Stores avec protocoles** (TradeStore, AlertStore, etc.)
- ✅ **Interface utilisateur** complète pour les alertes
- ✅ **Migration de données** entre modes de stockage
- ✅ **Notifications push** configurées
- ✅ **Deep linking** (`app://alert/{id}`)
- ✅ **Webhooks TradingView** avec vérification HMAC
- ✅ **Mode local SQLite** fonctionnel
- ✅ **Dashboard de trading** avancé
- ✅ **Import MEXC** avec API

### Mode de fonctionnement actuel
🟢 **Mode Local uniquement** - L'application fonctionne entièrement en local avec SQLite

⚠️ **Firebase non installé** - Les stores Firebase utilisent des stubs pour l'instant

## 🚀 Démarrage rapide

### Prérequis
- macOS 14+ (Sonoma)
- Xcode 15+
- iOS 17+ (pour les tests)

### Installation
```bash
# 1. Cloner le projet
cd "/Users/gaetanfougeray/Desktop/Journal de trading 2/Journal de trading 2025"

# 2. Ouvrir dans Xcode
open "Journal de trading 2025.xcodeproj"

# 3. Sélectionner un simulateur iOS
# 4. Compiler et lancer (⌘+R)
```

L'application se lancera en **mode Local** par défaut.

## 📱 Fonctionnalités principales

### 1. Dashboard
- Statistiques en temps réel
- Graphiques de performance
- Win rate et P&L
- Comparaison Long vs Short

### 2. Gestion des trades
- Ajout manuel de trades
- Import depuis MEXC
- Calcul automatique des frais
- Historique complet

### 3. Système d'alertes
- Liste des alertes avec filtres
- 3 niveaux de sévérité (info, normal, high)
- Sources multiples (TradingView, custom)
- Notifications push
- Filtres avancés par symbole, date, tags

### 4. Paramètres de stockage
- Basculement Firebase ↔ Local
- Migration des données avec progression
- Déduplication automatique

## 📂 Structure du projet

```
Journal de trading 2025/
├── Models/                          # Modèles de données
│   ├── Domain/Alert.swift           # Modèle Alert complet
│   └── Models.swift                 # Autres modèles
├── Services/
│   ├── Storage/
│   │   ├── Protocols/               # Protocoles de stockage
│   │   ├── LocalDB/                 # SQLite (fonctionnel)
│   │   ├── Firestore/               # Firebase (à activer)
│   │   └── MockStores.swift         # Tests
│   ├── Notifications/               # Push & Deep linking
│   └── Webhooks/                    # TradingView webhooks
├── Views/
│   ├── Alerts/                      # Interface alertes
│   └── Settings/                    # Paramètres
├── ARCHITECTURE.md                  # Documentation architecture
├── FIREBASE_SETUP.md                # Guide installation Firebase
└── README.md                        # Ce fichier
```

## 🔧 Configuration

### Mode Local (actuel)
Aucune configuration nécessaire, fonctionne immédiatement.

### Mode Firebase (optionnel)
Suivez le guide complet : **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)**

Résumé :
1. Créer un projet Firebase
2. Installer Firebase SDK via Swift Package Manager
3. Ajouter `GoogleService-Info.plist`
4. Décommenter `FirestoreAlertStore.swift`
5. Configurer les règles Firestore
6. Déployer les Cloud Functions

## 🎯 Utilisation

### Ajouter un trade
1. Onglet **Dashboard** → bouton `+`
2. Choisir "Saisie manuelle" ou "Import depuis MEXC"
3. Remplir les informations
4. Sauvegarder

### Configurer les alertes
1. Onglet **Alertes**
2. Bouton paramètres (⚙️)
3. Configurer les notifications push
4. Définir les heures silencieuses

### Migrer vers Firebase
1. Installer Firebase (voir guide)
2. Aller dans **Menu** → "Paramètres de stockage"
3. Sélectionner "Firebase"
4. Cliquer "Appliquer les changements"
5. Suivre l'assistant de migration

### Intégrer TradingView
1. Configurer Firebase + Cloud Functions
2. Dans TradingView, créer une alerte
3. URL webhook : `https://region-projet.cloudfunctions.net/tvWebhook`
4. Payload JSON avec votre `userId`

## 🐛 Débogage

### Logs
L'application utilise des logs avec emojis :
- 🔍 Debug/Investigation
- ✅ Succès
- ❌ Erreur
- ⚠️ Avertissement
- 📱 Notifications
- 🔗 Deep links

Regardez la console Xcode pour suivre le flux.

### Erreurs communes

#### "No such module 'FirebaseFirestore'"
✅ **Résolu** - L'app utilise maintenant des stubs. Pour activer Firebase, suivez [FIREBASE_SETUP.md](FIREBASE_SETUP.md)

#### L'import MEXC ne fonctionne pas
Vérifiez :
1. Clés API configurées dans les paramètres
2. Clés valides et actives sur MEXC
3. Logs dans la console

#### Les alertes n'apparaissent pas
Mode Local : Les alertes sont stockées en SQLite
Mode Firebase : Vérifiez l'authentification et les règles Firestore

## 🔒 Sécurité

### Stockage des secrets
- ✅ API Keys → Keychain iOS
- ✅ Webhook secrets → Jamais en base
- ✅ Tokens FCM → Gérés par iOS

### Validation
- ✅ HMAC SHA256 pour webhooks
- ✅ Protection replay attacks
- ✅ Règles Firestore strictes

## 📊 Métriques

L'application calcule automatiquement :
- Win rate global et par système
- P&L net avec frais
- Payoff ratio
- Max drawdown
- Sharpe ratio
- Expectancy
- Séries de gains/pertes

## 🛠️ Développement

### Ajouter un nouveau store

1. Définir le protocole dans `Protocols/`
2. Implémenter la version Local dans `LocalDB/`
3. Implémenter la version Firestore dans `Firestore/`
4. Créer un Mock dans `MockStores.swift`
5. Ajouter dans `AppState.createStores()`

### Tests
```bash
# Tests unitaires
⌘+U dans Xcode

# Tests UI
⌘+U avec UI Testing scheme
```

## 📝 TODO

### Priorité haute
- [ ] Finaliser l'installation Firebase
- [ ] Implémenter tous les Firestore stores
- [ ] Déployer Cloud Functions
- [ ] Tests d'intégration

### Priorité moyenne
- [ ] Authentification utilisateur
- [ ] Sync multi-appareils
- [ ] Export CSV des trades
- [ ] Widgets iOS

### Priorité basse
- [ ] Thèmes personnalisés
- [ ] Analytics avancées
- [ ] Support watchOS
- [ ] Version macOS

## 📚 Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture complète du projet
- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) - Guide d'installation Firebase
- Code commenté avec documentation inline

## 🤝 Contribution

Ce projet est en développement actif. Les contributions sont les bienvenues !

## 📄 Licence

Propriétaire - Tous droits réservés

## 🎉 Remerciements

Construit avec :
- SwiftUI
- Combine
- Firebase (optionnel)
- SQLite
- TradingView Webhooks

---

**Version actuelle** : 1.0.0 (Mode Local fonctionnel)  
**Dernière mise à jour** : 2025-01-09











