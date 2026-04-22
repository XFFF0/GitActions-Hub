import SwiftUI

struct ContentView: View {
    @StateObject private var gitHubService = GitHubService()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ActionsView()
                .environmentObject(gitHubService)
                .tabItem {
                    Label("الأكشنز", systemImage: "bolt.fill")
                }
                .tag(0)
            
            ReposView()
                .environmentObject(gitHubService)
                .tabItem {
                    Label("المستودعات", systemImage: "repo")
                }
                .tag(1)
            
            FilesView()
                .tabItem {
                    Label("الملفات", systemImage: "folder.fill")
                }
                .tag(2)
            
            ProfileView()
                .environmentObject(gitHubService)
                .tabItem {
                    Label("الملف", systemImage: "person.fill")
                }
                .tag(3)
        }
        .onAppear {
            gitHubService.loadSavedToken()
        }
    }
}