# Configuration Share Extension - TradeMindSet

## Vue d'ensemble

La Share Extension permet aux utilisateurs de partager des images depuis TradingView (ou toute autre app) directement vers TradeMindSet pour une analyse automatique.

## Fichiers créés

1. ✅ `Services/Share/SharedImageService.swift` - Service de partage d'images via App Groups
2. ✅ `ShareExtension/ShareViewController.swift` - ViewController de l'extension
3. ✅ `ShareExtension/Info.plist` - Configuration de l'extension
4. ✅ `ShareExtension/README.md` - Instructions détaillées

## Fichiers modifiés

1. ✅ `Services/Notifications/DeepLinkRouter.swift` - Ajout du support `trademindset://photo-analysis`
2. ✅ `Views/AI/PhotoAnalysisView.swift` - Chargement automatique de l'image partagée
3. ✅ `Models.swift` (TradingJournalApp) - Navigation automatique vers l'onglet Photo
4. ✅ `Views/AI/AIAssistantView.swift` - Support de l'onglet initial

## Configuration Xcode (À FAIRE MANUELLEMENT)

### Étape 1 : Créer le Target Share Extension

1. Ouvrez Xcode
2. **File > New > Target...**
3. Sélectionnez **Share Extension** (sous iOS)
4. Cliquez sur **Next**
5. Configurez :
   - **Product Name** : `TradeMindSetShareExtension`
   - **Bundle Identifier** : `FOUGERAY.Journal-de-trading-2025.ShareExtension`
   - **Language** : Swift
6. Cliquez sur **Finish**

### Étape 2 : Supprimer les fichiers générés automatiquement

Xcode crée automatiquement un fichier `ShareViewController.swift` et un `Info.plist`. 

1. Supprimez le fichier `ShareViewController.swift` généré par Xcode
2. Supprimez le fichier `Info.plist` généré par Xcode (s'il existe)

### Étape 3 : Ajouter les fichiers existants au target

1. Dans le Project Navigator, sélectionnez `ShareExtension/ShareViewController.swift`
2. Dans le File Inspector (panneau de droite), cochez le target **TradeMindSetShareExtension**
3. Répétez pour `ShareExtension/Info.plist`
4. **Important** : Ajoutez aussi `Services/Share/SharedImageService.swift` au target Share Extension

### Étape 4 : Configurer App Groups

#### Pour l'app principale :

1. Sélectionnez le target **Journal de trading 2025** (app principale)
2. Allez dans l'onglet **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Recherchez et ajoutez **App Groups**
5. Cliquez sur **+** et créez : `group.FOUGERAY.Journal-de-trading-2025`
   - Si le groupe existe déjà, sélectionnez-le

#### Pour l'extension :

1. Sélectionnez le target **TradeMindSetShareExtension**
2. Allez dans l'onglet **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Recherchez et ajoutez **App Groups**
5. Sélectionnez le même groupe : `group.FOUGERAY.Journal-de-trading-2025`

### Étape 5 : Configurer URL Scheme

1. Sélectionnez le target **Journal de trading 2025**
2. Allez dans l'onglet **Info**
3. Développez **URL Types**
4. Cliquez sur **+** pour ajouter un nouveau type
5. Configurez :
   - **Identifier** : `trademindset`
   - **URL Schemes** : `trademindset`
   - **Role** : Editor

**Alternative** : Si vous utilisez un `Info.plist` explicite, ajoutez :

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>trademindset</string>
        </array>
    </dict>
</array>
```

### Étape 6 : Vérifier la configuration de l'extension

1. Sélectionnez le target **TradeMindSetShareExtension**
2. Allez dans l'onglet **Info**
3. Vérifiez que `NSExtension` contient :
   - `NSExtensionPointIdentifier` : `com.apple.share-services`
   - `NSExtensionPrincipalClass` : `$(PRODUCT_MODULE_NAME).ShareViewController`
   - `NSExtensionActivationSupportsImageWithMaxCount` : `1`

Le fichier `ShareExtension/Info.plist` devrait déjà contenir ces valeurs.

### Étape 7 : Build et Test

1. Sélectionnez le schéma **Journal de trading 2025** dans Xcode
2. Build le projet (⌘B)
3. Lancez l'app sur un appareil ou simulateur
4. Depuis TradingView (ou Photos), partagez une image
5. Sélectionnez **TradeMindSet** dans le menu de partage
6. L'app devrait s'ouvrir automatiquement avec l'image chargée dans l'onglet Photo
7. L'analyse devrait se lancer automatiquement

## Flux de données

```
TradingView (ou autre app)
    ↓ [Share Sheet iOS]
ShareViewController (Extension)
    ↓ [Sauvegarde dans App Group UserDefaults]
    ↓ [Ouvre trademindset://photo-analysis]
App Principale
    ↓ [DeepLinkRouter route vers .photoAnalysis]
TradingJournalApp
    ↓ [Vérifie SharedImageService.hasPendingSharedImage()]
    ↓ [Navigue vers onglet IA (index 3)]
AIAssistantView
    ↓ [Ouvre onglet .photo]
PhotoAnalysisView
    ↓ [Charge l'image depuis SharedImageService]
    ↓ [Lance l'analyse automatiquement]
```

## Dépannage

### L'extension n'apparaît pas dans le menu de partage

- Vérifiez que l'extension est bien buildée
- Vérifiez que `NSExtensionActivationSupportsImageWithMaxCount` est configuré
- Redémarrez l'app qui partage l'image

### L'image n'est pas chargée

- Vérifiez que les App Groups sont configurés correctement
- Vérifiez que `SharedImageService` est ajouté au target de l'extension
- Vérifiez les logs console pour les erreurs

### L'app ne s'ouvre pas

- Vérifiez que le URL scheme est configuré dans Info.plist
- Vérifiez que `DeepLinkRouter` gère bien `trademindset://photo-analysis`

## Notes importantes

- Les extensions ont des limites mémoire strictes (optimiser le traitement d'image)
- L'extension doit terminer rapidement (max 30 secondes)
- L'image partagée expire après 5 minutes
- L'image est automatiquement nettoyée après récupération
