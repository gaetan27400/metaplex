import SwiftUI

struct AccountView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showProfilePhotoPicker: Bool = false
    @State private var profileImage: UIImage? = nil
    @State private var showStorageSettings: Bool = false
    
    var body: some View {
        NavigationStack {
            if appState.authManager.isAuthenticated {
                // Vue pour utilisateur connecté
                authenticatedView
            } else {
                // Vue pour utilisateur non connecté
                unauthenticatedView
            }
        }
        .sheet(isPresented: $showProfilePhotoPicker) {
            ImagePicker(image: $profileImage)
        }
        .sheet(isPresented: $showStorageSettings) {
            StorageSettingsView()
                .environmentObject(appState)
        }
    }
    
    private var authenticatedView: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Button(action: { showProfilePhotoPicker = true }) {
                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(t("changerLaPhoto"))
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if let user = appState.authManager.currentUser {
                        VStack(spacing: 4) {
                            Text(user.displayName ?? "Utilisateur")
                                .font(.title2.weight(.semibold))
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: user.isEmailVerified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(user.isEmailVerified ? .green : .orange)
                                
                                Text(user.isEmailVerified ? "Email vérifié" : "Email non vérifié")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            
            Section("Compte") {
                Button(action: {
                    // TODO: Ouvrir l'édition de profil
                }) {
                    Label("Modifier le profil", systemImage: "pencil.circle")
                }
                
                Button(action: {
                    // TODO: Ouvrir le changement de mot de passe
                }) {
                    Label("Changer le mot de passe", systemImage: "lock.circle")
                }
                
                if let user = appState.authManager.currentUser, !user.isEmailVerified {
                    Button(action: {
                        Task {
                            try await appState.authManager.sendEmailVerification()
                        }
                    }) {
                        HStack {
                            Label("Vérifier l'email", systemImage: "envelope.badge")
                            Spacer()
                            Text(t("add"))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.2))
                                )
                        }
                    }
                }
            }
            
            Section("Synchronisation") {
                // Statut Firebase
                HStack {
                    Label("Serveur Firebase", systemImage: "server.rack")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(FirebaseAvailability.isConfigured ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(FirebaseAvailability.isConfigured ? "Connecté" : "Non connecté")
                            .font(.caption)
                            .foregroundColor(FirebaseAvailability.isConfigured ? .green : .red)
                    }
                }
                
                if !FirebaseAvailability.isConfigured {
                    Button(action: {
                        showStorageSettings = true
                    }) {
                        Label("Configurer le serveur", systemImage: "gear")
                    }
                }
                
                if appState.storageMode == .local {
                    Button(action: {
                        Task {
                            await appState.switchStorageMode(to: .firebase)
                        }
                    }) {
                        Label("Migrer vers Firebase", systemImage: "arrow.up.icloud")
                    }
                }
                
                // Afficher le mode de stockage actuel
                HStack {
                    Label("Mode de stockage", systemImage: "externaldrive")
                    Spacer()
                    Text(appState.storageMode == .firebase ? "Firebase" : "Local")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        await appState.authManager.signOut()
                        dismiss()
                    }
                }) {
                    Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(t("myAccount"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(t("close")) {
                    dismiss()
                }
            }
        }
    }
    
    private var unauthenticatedView: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 100))
                        .foregroundColor(.gray)
                    
                    Text(t("no"))
                        .font(.title2.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Text(t("account"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            
            Section("Connexion") {
                Button("Se connecter") {
                    // TODO: Ouvrir la vue de connexion
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
                
                Button("Créer un compte") {
                    // TODO: Ouvrir la vue d'inscription
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
            }
            
            Section("Avantages") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("saturday"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(t("vosDonnesToujoursJour"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "iphone")
                                .foregroundColor(.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("multiappareils"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(t("accsDepuisNimporteO"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.purple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("analyse"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(t("ai"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(t("account"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(t("close")) {
                    dismiss()
                }
            }
        }
    }
}

// Simple UIKit image picker wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    AccountView().environmentObject(AppState())
}

