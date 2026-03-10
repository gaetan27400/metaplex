import SwiftUI

struct ShareSnapshotButton<Content: View, Label: View>: View {
    let snapshotWidth: CGFloat
    let backgroundColor: Color
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label
    
    @State private var shareImage: UIImage?
    @State private var isSharing = false
    
    init(
        snapshotWidth: CGFloat,
        backgroundColor: Color = AppColors.background,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label = {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.cardBackground.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                        )
                )
        }
    ) {
        self.snapshotWidth = snapshotWidth
        self.backgroundColor = backgroundColor
        self.content = content
        self.label = label
    }
    
    var body: some View {
        Button {
            HapticFeedback.selection()
            Task { @MainActor in
                shareImage = renderSnapshot(width: snapshotWidth, backgroundColor: backgroundColor, content: content)
                isSharing = shareImage != nil
            }
        } label: {
            label()
        }
        .accessibilityLabel("Partager")
        .sheet(isPresented: $isSharing) {
            if let shareImage {
                ActivityView(activityItems: [shareImage])
            }
        }
    }
}

@MainActor
func renderSnapshot<Content: View>(
    width: CGFloat,
    backgroundColor: Color,
    @ViewBuilder content: () -> Content
) -> UIImage? {
    let view = content()
        .frame(width: width)
        .background(backgroundColor)
    let renderer = ImageRenderer(content: view)
    renderer.scale = UIScreen.main.scale
    return renderer.uiImage
}

