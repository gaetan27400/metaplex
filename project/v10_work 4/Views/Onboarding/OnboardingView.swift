import Foundation
import SwiftUI
import Combine

// MARK: - Onboarding View
struct OnboardingView: View {
    @Binding var selectedGoal: TradingGoal?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: 0.33)
                    .tint(.cyan)
                    .padding()
                
                ScrollView {
                    VStack(spacing: 40) {
                        Text("What's your main\ntrading goal?")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                        
                        VStack(spacing: 20) {
                            ForEach(TradingGoal.allCases) { goal in
                                GoalOptionButton(
                                    goal: goal,
                                    isSelected: selectedGoal == goal
                                ) {
                                    selectedGoal = goal
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Goal Option Button
struct GoalOptionButton: View {
    let goal: TradingGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(goal.icon)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.rawValue)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text(goal.subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.surface2)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Subscription Feature Model
enum FeatureValue {
    case boolean(basic: Bool, pro: Bool)
    case text(basic: String, pro: String)
}

struct SubscriptionFeature: Identifiable {
    let id = UUID()
    let name: String
    let value: FeatureValue
}

// MARK: - Subscription Tier View
struct SubscriptionTierView: View {
    @Environment(\.dismiss) var dismiss
    
    let features: [SubscriptionFeature] = [
        SubscriptionFeature(name: "Importing trades", value: .boolean(basic: false, pro: true)),
        SubscriptionFeature(name: "Trade summaries", value: .text(basic: "30", pro: "âˆž")),
        SubscriptionFeature(name: "Advanced metrics", value: .boolean(basic: false, pro: true)),
        SubscriptionFeature(name: "Strategy performance", value: .boolean(basic: false, pro: true)),
        SubscriptionFeature(name: "Data sync across devices", value: .boolean(basic: false, pro: true))
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("You'll unlock")
                        .font(.title2.bold())
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    HStack(spacing: 40) {
                        Text("Basic")
                            .font(.headline)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Pro")
                            .font(.headline)
                            .foregroundColor(AppColors.success)
                    }
                }
                .padding()
                .background(Color.surface2)
                
                List {
                    ForEach(features) { feature in
                        HStack {
                            Text(feature.name)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            switch feature.value {
                            case .text(let basic, let pro):
                                Text(basic)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(width: 60)
                                Text(pro)
                                    .foregroundColor(AppColors.success)
                                    .frame(width: 60)
                            case .boolean(let basic, let pro):
                                Image(systemName: basic ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(basic ? .green : .gray)
                                    .frame(width: 60)
                                Image(systemName: pro ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(pro ? .green : .gray)
                                    .frame(width: 60)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black)
                
                Button {
                    dismiss()
                } label: {
                    Text("Continuer avec Basic")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Quick Access Card
struct QuickAccessCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        // ✅ Plus compact (évite de monopoliser le haut de l’écran)
        .frame(height: 72)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 2)
        .cornerRadius(12)
    }
}

// MARK: - Dashboard Time Ranges (Hour Ranges + Sessions)
struct DashboardTimeRange: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var startHour: Int
    var endHour: Int
    
    /// Label lisible (ex: "06h-09h").
    var label: String {
        String(format: "%02dh-%02dh", startHour, endHour)
    }
    
    /// Plage sur 24h (supporte le wrap: ex 22→02).
    /// Interprétation **semi-ouverte**: [startHour, endHour) pour éviter les overlaps sur les bornes.
    func contains(hour: Int) -> Bool {
        let h = max(0, min(23, hour))
        // Plage "vide" si start == end (on la considère invalide au moment de la validation).
        if startHour == endHour { return false }
        
        if startHour < endHour {
            return (startHour..<endHour).contains(h)
        }
        
        // Wrap midnight (ex: 22 → 02)
        return h >= startHour || h < endHour
    }
    
    static let defaultHourRanges: [DashboardTimeRange] = [
        .init(name: "Matin", startHour: 6, endHour: 9),
        .init(name: "Milieu", startHour: 9, endHour: 12),
        .init(name: "Après-midi", startHour: 12, endHour: 15),
        .init(name: "Fin journée", startHour: 15, endHour: 18)
    ]
    
    static let defaultSessionRanges: [DashboardTimeRange] = [
        .init(name: "Asie", startHour: 0, endHour: 8),
        .init(name: "Londres", startHour: 8, endHour: 16),
        .init(name: "New York", startHour: 13, endHour: 21)
    ]
}

