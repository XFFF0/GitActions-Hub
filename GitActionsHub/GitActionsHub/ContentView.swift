import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedTab: AppTab = .repos

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .actions: ActionsView()
                case .repos:   ReposView()
                case .profile: SimpleProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            CustomTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct SimpleProfileView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            ZStack { AnimatedGradientBackground()
                VStack(spacing: 0) {
                    HStack { Text("Profile").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text); Spacer() }
                    .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if let u = gitHubService.currentUser {
                                HStack(spacing: 16) {
                                    AsyncImage(url: URL(string: u.avatarUrl)) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: { Image(systemName: "person.circle.fill").font(.system(size: 40)).foregroundColor(AppColors.accent) }.frame(width: 64, height: 64).clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 4) { if let n = u.name { Text(n).font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text) }; Text("@\(u.login)").font(.system(size: 14, design: .monospaced)).foregroundColor(AppColors.textSecondary) }
                                    Spacer()
                                }.padding(16).glassCard().padding(.horizontal)
                                
                                HStack(spacing: 10) { StatCard(value: "\(u.publicRepos)", label: "Repos", color: AppColors.accent, icon: "square.stack.3d.up.fill"); StatCard(value: "\(u.followers)", label: "Followers", color: Color(hex: "#FF6B6B"), icon: "person.2.fill"); StatCard(value: "\(u.following)", label: "Following", color: Color(hex: "#6BCB77"), icon: "person.fill.checkmark") }.padding(.horizontal)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Label("About", systemImage: "info.circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                                infoRow("Version", "1.0.0"); infoRow("Stack", "SwiftUI + GitHub API"); infoRow("Developer", "@XFFF0")
                            }.padding(16).glassCard().padding(.horizontal)
                            
                            Button { showLogoutAlert = true } label: {
                                HStack { Image(systemName: "arrow.right.square.fill"); Text("Sign Out").font(.system(size: 15, weight: .semibold)) }
                                .foregroundColor(Color(hex: "#FF6B6B")).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color(hex: "#FF6B6B").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                            }.padding(.horizontal)
                        }.padding(.vertical)
                    }
                }
            }.navigationBarHidden(true)
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Sign Out", role: .destructive) { gitHubService.logout() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Sign out from GitHub?") }
    }
    
    func infoRow(_ k: String, _ v: String) -> some View { HStack { Text(k).font(.system(size: 13)).foregroundColor(AppColors.textSecondary); Spacer(); Text(v).font(.system(size: 13, weight: .medium)).foregroundColor(AppColors.text) } }
}

struct RootView: View {
    @StateObject private var gitHubService = GitHubService()

    var body: some View {
        Group {
            if gitHubService.isAuthenticated {
                ContentView().environmentObject(gitHubService)
            } else {
                LoginView().environmentObject(gitHubService)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeInOut(duration: 0.4), value: gitHubService.isAuthenticated)
        .onAppear { gitHubService.loadSavedToken() }
    }
}

@main
struct GitActionsHubApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
