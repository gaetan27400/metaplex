# Guide d'installation de Firebase

## ⚠️ État actuel

Firebase n'est **pas encore installé** dans ce projet. L'application fonctionne actuellement en mode **Local uniquement** avec des stores stub pour Firebase.

## 📋 Étapes d'installation

### 1. Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Cliquez sur "Ajouter un projet"
3. Nommez votre projet : `Journal de trading 2025`
4. Activez Google Analytics (optionnel)
5. Créez le projet

### 2. Ajouter une application iOS

1. Dans la console Firebase, cliquez sur "Ajouter une app" → iOS
2. Entrez votre Bundle ID : `com.yourcompany.journaldetrading2025`
3. Téléchargez le fichier `GoogleService-Info.plist`
4. Glissez-déposez ce fichier dans Xcode à la racine du projet

### 3. Installer Firebase SDK via Swift Package Manager

1. Dans Xcode, allez dans **File → Add Package Dependencies**
2. Entrez l'URL : `https://github.com/firebase/firebase-ios-sdk.git`
3. Sélectionnez la version : `10.0.0` ou supérieure
4. Sélectionnez les packages à installer :
   - ✅ FirebaseAuth
   - ✅ FirebaseFirestore
   - ✅ FirebaseMessaging (pour les notifications)
   - ✅ FirebaseAnalytics (optionnel)

### 4. Activer les services Firebase

#### Firestore Database
1. Dans Firebase Console → Build → Firestore Database
2. Cliquez sur "Créer une base de données"
3. Choisissez le mode : **Production** avec les règles de sécurité suivantes :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règles pour les alertes
    match /users/{uid}/alerts/{alertId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
      allow read: if resource.data.isPublic == true;
    }
    
    // Règles pour les trades
    match /users/{uid}/trades/{tradeId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // Règles pour les exchanges
    match /users/{uid}/exchanges/{exchangeId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // Règles pour les systèmes
    match /users/{uid}/systems/{systemId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

#### Firebase Authentication
1. Dans Firebase Console → Build → Authentication
2. Activez les méthodes de connexion souhaitées :
   - Email/Password
   - Google
   - Apple (recommandé pour iOS)

#### Cloud Messaging (Notifications Push)
1. Dans Firebase Console → Build → Cloud Messaging
2. Uploadez votre certificat APNs :
   - Allez dans Apple Developer Center
   - Créez un APNs Key
   - Téléchargez et uploadez dans Firebase

### 5. Configurer le projet Xcode

#### Info.plist
Ajoutez ces permissions :
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>Nous utilisons les notifications pour vous envoyer des alertes de trading importantes.</string>
```

#### Capabilities
Activez dans Xcode → Signing & Capabilities :
- ✅ Push Notifications
- ✅ Background Modes → Remote notifications

#### Point d’entrée SwiftUI (recommandé)
Dans cette app, **Firebase est initialisé dans le `@main` SwiftUI (`Journal_de_trading_2025App`)** afin de garantir l’ordre :

- App Check (DEBUG) d’abord
- puis initialisation Firebase
- puis création de `AppState`

⚠️ **Ne configurez pas Firebase dans un AppDelegate**, et évitez d’avoir plusieurs initialisations dans le projet.

### 6. Activer FirestoreAlertStore

Une fois Firebase installé, décommentez le fichier :
```swift
// Services/Storage/Firestore/FirestoreAlertStore.swift
```

Et mettez à jour la méthode dans `Models.swift` :

```swift
static func createFirebaseStores() -> (TradeStore, ExchangeStore, SystemStore, APIStore, AlertStore) {
    print("✅ [AppState] Utilisation de Firebase")
    let alertStore = FirestoreAlertStore() // Au lieu de FirestoreAlertStoreStub()
    return (MockTradeStore(), MockExchangeStore(), MockSystemStore(), MockAPIStore(), alertStore)
}
```

### 7. Configurer Cloud Functions pour les webhooks

#### Installation
```bash
npm install -g firebase-tools
firebase login
firebase init functions
```

#### Cloud Function pour TradingView Webhooks
Créez `functions/index.js` :

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

exports.tvWebhook = functions.https.onRequest(async (req, res) => {
    // CORS
    res.set('Access-Control-Allow-Origin', '*');
    
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, X-Signature, X-Timestamp');
        return res.status(204).send('');
    }
    
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }
    
    try {
        // 1. Vérifier la signature HMAC
        const signature = req.headers['x-signature'];
        const timestamp = req.headers['x-timestamp'];
        const secret = functions.config().webhook.secret;
        
        if (!verifySignature(req.body, signature, timestamp, secret)) {
            return res.status(401).json({ error: 'Invalid signature' });
        }
        
        // 2. Parser le payload
        const payload = req.body;
        const userId = payload.userId || payload.user_id;
        
        if (!userId) {
            return res.status(400).json({ error: 'Missing userId' });
        }
        
        // 3. Créer l'alerte dans Firestore
        const alertRef = admin.firestore()
            .collection('users')
            .doc(userId)
            .collection('alerts')
            .doc();
        
        await alertRef.set({
            id: alertRef.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            symbol: payload.symbol,
            exchange: payload.exchange || null,
            price: payload.price || null,
            message: payload.message,
            severity: payload.severity || 'normal',
            tags: payload.tags || [],
            payloadJSON: JSON.stringify(payload),
            isRead: false,
            source: 'tradingView',
            linkedTradeId: null
        });
        
        // 4. Envoyer notification FCM
        const fcmToken = await getUserFCMToken(userId);
        if (fcmToken) {
            await admin.messaging().send({
                token: fcmToken,
                notification: {
                    title: `Alerte ${payload.symbol}`,
                    body: payload.message
                },
                data: {
                    alertId: alertRef.id,
                    type: 'alert'
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                            badge: 1
                        }
                    }
                }
            });
        }
        
        res.status(200).json({ 
            success: true, 
            message: 'Alert created',
            alertId: alertRef.id 
        });
        
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ 
            success: false, 
            error: error.message 
        });
    }
});

function verifySignature(payload, signature, timestamp, secret) {
    const now = Math.floor(Date.now() / 1000);
    const timeDiff = Math.abs(now - parseInt(timestamp));
    
    // Vérifier que le timestamp est récent (< 5 minutes)
    if (timeDiff > 300) {
        return false;
    }
    
    // Calculer la signature attendue
    const message = timestamp + JSON.stringify(payload);
    const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(message)
        .digest('hex');
    
    return signature === expectedSignature;
}

async function getUserFCMToken(userId) {
    const doc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
    
    return doc.data()?.fcmToken || null;
}
```

#### Déploiement
```bash
firebase deploy --only functions
```

#### Configuration du secret
```bash
firebase functions:config:set webhook.secret="votre_secret_tres_secure"
firebase deploy --only functions
```

### 8. Configuration TradingView

Dans TradingView, créez une alerte avec webhook :

**URL** : `https://your-region-your-project.cloudfunctions.net/tvWebhook`

**Payload** :
```json
{
  "userId": "{{your_firebase_uid}}",
  "symbol": "{{ticker}}",
  "price": "{{close}}",
  "message": "Prix : {{close}}, Volume : {{volume}}",
  "severity": "normal",
  "tags": ["tradingview", "auto"]
}
```

**Headers** :
- `X-Signature`: `{{calculated_hmac}}`
- `X-Timestamp`: `{{timestamp}}`
- `Content-Type`: `application/json`

### 9. Tester l'installation

1. **Tester Firestore** :
   - Lancez l'app
   - Allez dans Paramètres → Stockage
   - Sélectionnez "Firebase"
   - Créez une alerte de test

2. **Tester les notifications** :
   - Donnez les permissions de notification
   - Envoyez une alerte depuis TradingView
   - Vérifiez la réception

3. **Tester la migration** :
   - Créez des données en mode Local
   - Allez dans Paramètres → Stockage
   - Cliquez sur "Local → Firebase"
   - Vérifiez la migration

## 🔒 Sécurité

### Secrets à configurer
1. **Webhook Secret** : Pour vérifier les signatures HMAC
2. **Firebase Admin SDK** : Pour les Cloud Functions
3. **APNs Key** : Pour les notifications push

### Ne jamais committer
- `GoogleService-Info.plist` (ajoutez-le au `.gitignore`)
- Clés API dans le code source
- Secrets de webhook

## 📊 Monitoring

Une fois configuré, vous pouvez monitorer :
- **Firestore** : Lectures/écritures dans la console
- **Cloud Functions** : Logs et métriques
- **Crashlytics** : Rapports de crash (optionnel)
- **Analytics** : Comportement utilisateur (optionnel)

## ✅ Checklist finale

- [ ] Projet Firebase créé
- [ ] Application iOS ajoutée
- [ ] `GoogleService-Info.plist` téléchargé
- [ ] Firebase SDK installé via SPM
- [ ] Firestore activé avec règles de sécurité
- [ ] Authentication activée
- [ ] Cloud Messaging configuré
- [ ] Certificat APNs uploadé
- [ ] Cloud Functions déployées
- [ ] Webhook TradingView configuré
- [ ] Tests effectués
- [ ] `FirestoreAlertStore.swift` décommenté
- [ ] App compilée sans erreur

## 🚀 Prochaines étapes

Une fois Firebase configuré :
1. Implémenter les autres Firestore stores (Trade, Exchange, System)
2. Ajouter l'authentification utilisateur
3. Configurer les tests d'intégration
4. Mettre en place le monitoring
5. Optimiser les règles de sécurité











