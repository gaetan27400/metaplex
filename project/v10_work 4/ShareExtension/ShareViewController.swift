//
//  ShareViewController.swift
//  TradeMindSetShareExtension
//
//  Share Extension pour recevoir des images depuis TradingView ou autres apps
//

import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    private let appGroupIdentifier = "group.FOUGERAY.Journal-de-trading-2025"
    private let urlScheme = "trademindset://photo-analysis"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configurer le titre de l'extension
        title = "TradeMindSet"
        placeholder = "Analyser le graphique"
        
        // Désactiver le champ de texte (on ne veut que l'image)
        textView.isEditable = false
        textView.isSelectable = false
    }
    
    override func isContentValid() -> Bool {
        // Vérifier qu'une image est présente
        return hasImage()
    }
    
    override func didSelectPost() {
        // Cette méthode est appelée quand l'utilisateur appuie sur "Post"
        processSharedImage()
    }
    
    override func configurationItems() -> [Any]! {
        // Pas d'options de configuration supplémentaires
        return []
    }
    
    // MARK: - Image Processing
    
    private func hasImage() -> Bool {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return false
        }
        
        for item in extensionItems {
            if let attachments = item.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func processSharedImage() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }
        
        // Trouver la première image
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("❌ [ShareExtension] Error loading image: \(error.localizedDescription)")
                            self.completeRequest()
                            return
                        }
                        
                        // Convertir l'item en UIImage
                        var image: UIImage?
                        
                        if let url = item as? URL {
                            if let imageData = try? Data(contentsOf: url),
                               let loadedImage = UIImage(data: imageData) {
                                image = loadedImage
                            }
                        } else if let uiImage = item as? UIImage {
                            image = uiImage
                        } else if let imageData = item as? Data {
                            image = UIImage(data: imageData)
                        }
                        
                        guard let finalImage = image else {
                            print("❌ [ShareExtension] Could not convert item to UIImage")
                            self.completeRequest()
                            return
                        }
                        
                        // Convertir en JPEG Data
                        guard let imageData = finalImage.jpegData(compressionQuality: 0.8) else {
                            print("❌ [ShareExtension] Could not convert image to JPEG")
                            self.completeRequest()
                            return
                        }
                        
                        // Sauvegarder dans App Group
                        self.saveImageToAppGroup(imageData)
                        
                        // Ouvrir l'app principale
                        self.openMainApp()
                        
                        // Terminer l'extension
                        DispatchQueue.main.async {
                            self.completeRequest()
                        }
                    }
                    return // On ne traite que la première image
                }
            }
        }
        
        // Si aucune image trouvée
        completeRequest()
    }
    
    private func saveImageToAppGroup(_ imageData: Data) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ [ShareExtension] Failed to access App Group UserDefaults")
            return
        }
        
        defaults.set(imageData, forKey: "sharedImageData")
        defaults.set(Date().timeIntervalSince1970, forKey: "sharedImageTimestamp")
        defaults.synchronize()
        
        print("✅ [ShareExtension] Image saved to App Group (\(imageData.count) bytes)")
    }
    
    private func openMainApp() {
        guard let url = URL(string: urlScheme) else {
            print("❌ [ShareExtension] Invalid URL scheme: \(urlScheme)")
            return
        }
        
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, completionHandler: { success in
                    if success {
                        print("✅ [ShareExtension] Opened main app with URL: \(url)")
                    } else {
                        print("❌ [ShareExtension] Failed to open main app")
                    }
                })
                return
            }
            responder = responder?.next
        }
        
        // Fallback: utiliser extensionContext
        extensionContext?.open(url, completionHandler: { success in
            if success {
                print("✅ [ShareExtension] Opened main app via extensionContext")
            } else {
                print("❌ [ShareExtension] Failed to open main app via extensionContext")
            }
        })
    }
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
