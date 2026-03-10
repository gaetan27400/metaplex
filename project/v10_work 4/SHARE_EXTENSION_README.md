# Share Extension Configuration

## Configuration Xcode

Pour que la Share Extension fonctionne, vous devez :

### 1. Créer le Target Share Extension

1. Dans Xcode, allez dans **File > New > Target**
2. Sélectionnez **Share Extension**
3. Nom : `TradeMindSetShareExtension`
4. Bundle Identifier : `FOUGERAY.Journal-de-trading-2025.ShareExtension`
5. Language : Swift

### 2. Configurer App Groups

1. Sélectionnez le target de l'app principale
2. Allez dans **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Ajoutez **App Groups**
5. Créez ou sélectionnez : `group.FOUGERAY.Journal-de-trading-2025`

6. Répétez pour le target Share Extension avec le même App Group

### 3. Configurer URL Scheme

1. Sélectionnez le target de l'app principale
2. Allez dans **Info** (ou créez/modifiez `Info.plist`)
3. Ajoutez la clé `CFBundleURLTypes` :

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

### 4. Ajouter les fichiers à l'extension

1. Ajoutez `ShareViewController.swift` au target Share Extension
2. Ajoutez `Info.plist` au target Share Extension
3. **Important** : Ajoutez `SharedImageService.swift` au target Share Extension (ou créez un framework partagé)

### 5. Configuration Info.plist de l'extension

Le fichier `Info.plist` de l'extension doit contenir :

- `NSExtensionPointIdentifier` : `com.apple.share-services`
- `NSExtensionPrincipalClass` : `$(PRODUCT_MODULE_NAME).ShareViewController`
- `NSExtensionActivationSupportsImageWithMaxCount` : `1`

## Résolution des erreurs de build

Si vous voyez des erreurs "Multiple commands produce" pour `Info.plist` ou `README.md` :

1. **Dans Xcode**, sélectionnez le fichier `ShareExtension/Info.plist`
2. Dans le **File Inspector** (panneau de droite), onglet **Target Membership**
3. **Décochez** le target principal "TradeMindSet" (ou "Journal de trading 2025")
4. **Cochez uniquement** le target "TradeMindSetShareExtension"

5. Répétez pour `ShareViewController.swift` si nécessaire

## Test

1. Build l'app avec l'extension
2. Depuis TradingView (ou Photos), partager une image
3. Sélectionner "TradeMindSet" dans le menu de partage
4. L'app devrait s'ouvrir automatiquement avec l'image chargée dans l'onglet Photo
5. L'analyse devrait se lancer automatiquement

## Notes

- L'extension utilise App Groups pour partager l'image entre l'extension et l'app
- L'URL scheme `trademindset://photo-analysis` est utilisé pour ouvrir l'app
- L'image est automatiquement nettoyée après récupération (max 5 minutes de validité)
