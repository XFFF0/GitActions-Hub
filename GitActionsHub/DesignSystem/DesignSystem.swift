import SwiftUI

// MARK: - Design System

struct AppColors {
    static let background = Color(hex: "#0A0A0F")
    static let surface = Color(hex: "#12121A")
    static let surfaceElevated = Color(hex: "#1A1A25")
    static let accent = Color(hex: "#6C63FF")
    static let accentSecondary = Color(hex: "#FF6B6B")
    static let accentTertiary = Color(hex: "#6BCB77")
    static let text = Color(hex: "#F0F0F5")
    static let textSecondary = Color(hex: "#8888A0")
    static let border = Color(hex: "#2A2A3A")
    static let glassOverlay = Color.white.opacity(0.05)
}

// MARK: - Liquid Glass Effect

struct LiquidGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var intensity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base blur
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08 * intensity),
                            Color.white.opacity(0.02 * intensity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Noise overlay for glass texture
                    Rectangle()
                        .fill(Color.white.opacity(0.03 * intensity))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2 * intensity),
                                Color.white.opacity(0.05 * intensity),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppColors.surface)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),
                                    Color.white.opacity(0.01)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(AppColors.border, lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20, intensity: Double = 1.0) -> some View {
        modifier(LiquidGlassBackground(cornerRadius: cornerRadius, intensity: intensity))
    }
    
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glow Effect

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
            .shadow(color: color.opacity(0.1), radius: radius * 2)
    }
}

extension View {
    func glow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animationPhase: Double = 0
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            // Ambient orbs
            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(
                    x: -100 + CGFloat(sin(animationPhase) * 30),
                    y: -200 + CGFloat(cos(animationPhase * 0.7) * 20)
                )
            
            Circle()
                .fill(AppColors.accentSecondary.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(
                    x: 120 + CGFloat(cos(animationPhase * 0.8) * 25),
                    y: 300 + CGFloat(sin(animationPhase * 0.5) * 30)
                )
            
            Circle()
                .fill(Color(hex: "#00D4AA").opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(
                    x: CGFloat(sin(animationPhase * 0.6) * 40),
                    y: 100 + CGFloat(cos(animationPhase * 0.9) * 25)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animationPhase = .pi * 2
            }
        }
    }
}

// MARK: - Tab Item Data

enum AppTab: Int, CaseIterable {
    case actions
    case repos
    case files
    case profile
    
    var title: String {
        switch self {
        case .actions: return "Actions"
        case .repos: return "Repos"
        case .files: return "Files"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .actions: return "bolt.circle.fill"
        case .repos: return "square.stack.3d.up.fill"
        case .files: return "folder.fill"
        case .profile: return "person.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .actions: return Color(hex: "#6C63FF")
        case .repos: return Color(hex: "#FF6B6B")
        case .files: return Color(hex: "#FFD93D")
        case .profile: return Color(hex: "#6BCB77")
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                TabBarItem(tab: tab, isSelected: selectedTab == tab)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 28)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tab.color.opacity(0.2))
                        .frame(width: 50, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(tab.color.opacity(0.4), lineWidth: 1)
                        )
                }
                
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? tab.color : AppColors.textSecondary)
                    .glow(color: isSelected ? tab.color : .clear, radius: 6)
            }
            .frame(width: 50, height: 34)
            
            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? tab.color : AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    let conclusion: String?
    
    var color: Color {
        switch status {
        case "completed":
            switch conclusion {
            case "success": return .green
            case "failure": return Color(hex: "#FF6B6B")
            case "cancelled": return .orange
            default: return .gray
            }
        case "in_progress": return Color(hex: "#6C63FF")
        case "queued": return Color(hex: "#FFD93D")
        default: return .gray
        }
    }
    
    var label: String {
        switch status {
        case "completed":
            switch conclusion {
            case "success": return "نجاح"
            case "failure": return "فشل"
            case "cancelled": return "ملغى"
            default: return conclusion ?? "مكتمل"
            }
        case "in_progress": return "جارٍ"
        case "queued": return "انتظار"
        default: return status
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if status == "in_progress" {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    )
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String = "عرض الكل"
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.text)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            if let action = action {
                Button(actionLabel, action: action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }
        }
    }
}
