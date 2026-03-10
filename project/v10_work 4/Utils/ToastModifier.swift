//
//  ToastModifier.swift
//  Journal de trading 2025
//

import SwiftUI

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

struct ToastData: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval
}

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    if let toast = toast {
                        ToastView(toast: toast)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast.id)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                                    withAnimation {
                                        self.toast = nil
                                    }
                                }
                            }
                    }
                    Spacer()
                }
                .padding(.top, 60)
            )
    }
}

struct ToastView: View {
    let toast: ToastData
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône
            Image(systemName: toast.type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(toast.type.color)
            
            // Message
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(toast.type.color.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

extension View {
    func toast(_ toast: Binding<ToastData?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}





