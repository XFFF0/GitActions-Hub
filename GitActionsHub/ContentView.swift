import SwiftUI

// MARK: - Content View (Main)

struct ContentView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedTab: AppTab = .actions
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case .actions:
                    ActionsView()
                case .repos:
                    ReposView()
                case .files:
                    FilesView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Root View

struct RootView: View {
    @StateObject private var gitHubService = GitHubService()
    
    var body: some View {
        Group {
            if gitHubService.isAuthenticated {
                ContentView()
                    .environmentObject(gitHubService)
            } else {
                LoginView()
                    .environmentObject(gitHubService)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: gitHubService.isAuthenticated)
        .onAppear {
            gitHubService.loadSavedToken()
        }
    }
}

// MARK: - App Entry Point

@main
struct GitActionsHubApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
