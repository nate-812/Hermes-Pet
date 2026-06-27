import SwiftUI

// MARK: - Liquid Glass Modifier

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: Double
    var shadowRadius: CGFloat
    var material: Material

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                    .opacity(opacity)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.6),
                                .white.opacity(0.1),
                                .white.opacity(0.1),
                                .white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.15), radius: shadowRadius, x: 0, y: shadowRadius / 2)
    }
}

extension View {
    /// Applies a "Liquid Glass" effect to the view.
    /// - Parameters:
    ///   - cornerRadius: The radius of the rounded corners.
    ///   - opacity: Opacity of the frosted glass material.
    ///   - shadowRadius: Radius of the drop shadow.
    func liquidGlass(cornerRadius: CGFloat = 24, opacity: Double = 1.0, shadowRadius: CGFloat = 10, material: Material = .ultraThinMaterial) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius, opacity: opacity, shadowRadius: shadowRadius, material: material))
    }
}

// MARK: - Animated Blob Background

struct LiquidBackgroundView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            // Blob 1
            Circle()
                .fill(Color.purple.opacity(0.4))
                .blur(radius: 80)
                .frame(width: 400, height: 400)
                .offset(x: animate ? 100 : -100, y: animate ? -100 : 100)
            
            // Blob 2
            Circle()
                .fill(Color.indigo.opacity(0.4))
                .blur(radius: 100)
                .frame(width: 350, height: 350)
                .offset(x: animate ? -150 : 150, y: animate ? 150 : -150)

            // Blob 3
            Circle()
                .fill(Color.blue.opacity(0.3))
                .blur(radius: 90)
                .frame(width: 300, height: 300)
                .offset(x: animate ? -50 : 50, y: animate ? -200 : 200)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
