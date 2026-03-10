import SwiftUI
import UIKit

struct ReferralView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @State private var referralCode: String = "JOURNAL-"
    @State private var referredUsers: [String] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("ai"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(t("partagezVotreCodePourInviterDesAmisEtGagnerDesRcompenses"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.surface2)
                .cornerRadius(12)
                
                HStack {
                    Text(referralCode)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    Spacer()
                    Button("Copier") {
                        UIPasteboard.general.string = referralCode
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.surface2)
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("vosFilleuls"))
                        .font(.headline)
                    if referredUsers.isEmpty {
                        Text(t("aucunFilleulPourLinstant"))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(referredUsers, id: \.self) { user in
                            HStack {
                                Image(systemName: "person.crop.circle")
                                Text(user)
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.surface2)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .background(Color.surface1.ignoresSafeArea())
            .navigationTitle(t("referral"))
        }
    }
}

#Preview {
    ReferralView()
}
