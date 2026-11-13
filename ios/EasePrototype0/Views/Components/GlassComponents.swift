// GlassComponents.swift
import SwiftUI

// MARK: - Glassmorphic Color Palette
extension Color {
    static let easeBackground = Color(red: 0.04, green: 0.06, blue: 0.09)
    static let easeSurfaceGlass = Color(red: 0.09, green: 0.13, blue: 0.20).opacity(0.65)
    static let easeCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    static let easeEmerald = Color(red: 0.0, green: 0.90, blue: 0.46)
    static let easeAmber = Color(red: 1.0, green: 0.70, blue: 0.0)
    static let easeRuby = Color(red: 1.0, green: 0.28, blue: 0.36)
    static let easePurple = Color(red: 0.65, green: 0.40, blue: 1.0)
}

// MARK: - Glassmorphic Card View Modifier
struct GlassmorphicModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var glowColor: Color = .clear
    var glowRadius: CGFloat = 0
    var strokeOpacity: Double = 0.3

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Color.easeSurfaceGlass
                            .cornerRadius(cornerRadius)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(strokeOpacity),
                                .white.opacity(0.08),
                                .white.opacity(0.02),
                                .white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: glowColor.opacity(glowRadius > 0 ? 0.35 : 0), radius: glowRadius, x: 0, y: glowRadius / 2)
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, glowColor: Color = .clear, glowRadius: CGFloat = 0, strokeOpacity: Double = 0.25) -> some View {
        self.modifier(GlassmorphicModifier(cornerRadius: cornerRadius, glowColor: glowColor, glowRadius: glowRadius, strokeOpacity: strokeOpacity))
    }
}

// MARK: - Glass Status Pill
struct GlassStatusPill: View {
    let title: String
    let icon: String?
    let color: Color
    var pulse: Bool = false

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing && pulse ? 1.4 : 1.0)
                .opacity(isPulsing && pulse ? 0.6 : 1.0)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.35), lineWidth: 0.8)
                )
        )
        .onAppear {
            if pulse {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}

// MARK: - Interactive Glass Button
struct GlassActionButton: View {
    let title: String
    let icon: String?
    var color: Color = .easeCyan
    var action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundColor(color)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(color.opacity(0.4), lineWidth: 1)
                    )
            )
            .shadow(color: color.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
