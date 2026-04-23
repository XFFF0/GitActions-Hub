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
                case .profile: ProfileView()
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
