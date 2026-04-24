import SwiftUI

struct LoginView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var token = ""
    @State private var isLoading = false
    @State private var showTokenField = false
    @State private var pulseAnimation = false
    @State private var logoScale = 0.5
    @State private var contentOpacity = 0.0
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)
                    
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                            
                            Circle()
                                .fill(AppColors.accent.opacity(0.1))
                                .frame(width: 120, height: 120)
                                .scaleEffect(pulseAnimation ? 1.15 : 0.95)
                                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulseAnimation)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.accent, Color(hex: "#9B59B6")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "bolt.circle.fill")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("GA")
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .glow(color: AppColors.accent, radius: 15)
                        }
                        .scaleEffect(logoScale)
                        
                        VStack(spacing: 8) {
                            Text("GitActions Hub")
                                .font(.system(size: 32, weight: .black, design: .default))
                                .foregroundColor(AppColors.text)
                            
                            Text("Manage GitHub Actions from your device")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            FeatureRow(icon: "bolt.circle.fill", color: AppColors.accent, text: "Live Actions monitoring")
                            FeatureRow(icon: "exclamationmark.triangle.fill", color: Color(hex: "#FFD93D"), text: "Instant error detection")
                            FeatureRow(icon: "folder.fill", color: Color(hex: "#6BCB77"), text: "Project file management")
                            FeatureRow(icon: "arrow.triangle.2.circlepath", color: Color(hex: "#FF6B6B"), text: "Direct Commit & Push")
                        }
                        .padding(20)
                        .glassCard()
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 20)
                                
                                SecureField("GitHub Personal Access Token", text: $token)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(AppColors.text)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                
                                if !token.isEmpty {
                                    Button {
                                        token = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
                            .padding(16)
                            .background(AppColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(token.isEmpty ? AppColors.border : AppColors.accent.opacity(0.6), lineWidth: 1)
                            )
                            
                            Text("Requires: repo, workflow, read:user")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Button {
                            loginWithToken()
                        } label: {
                            HStack(spacing: 12) {
                                if gitHubService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 18))
                                }
                                Text(gitHubService.isLoading ? "Signing in..." : "Sign In")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: token.isEmpty
                                        ? [AppColors.border, AppColors.border]
                                        : [AppColors.accent, Color(hex: "#9B59B6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: token.isEmpty ? .clear : AppColors.accent.opacity(0.4), radius: 12)
                        }
                        .disabled(token.isEmpty || gitHubService.isLoading)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                            Text("Create token: Settings > Developer settings > Personal access tokens")
                                .font(.system(size: 11))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    
                    if let error = gitHubService.error {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.accentSecondary)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.accentSecondary)
                        }
                        .padding(12)
                        .background(AppColors.accentSecondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(AppColors.accentSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                logoScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
                contentOpacity = 1.0
            }
            pulseAnimation = true
        }
    }
    
    private func loginWithToken() {
        Task {
            await gitHubService.authenticateWithOAuth(token: token)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.text)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(color.opacity(0.7))
        }
    }
}
