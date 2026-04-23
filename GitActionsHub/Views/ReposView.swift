import SwiftUI

struct ReposView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @StateObject private var fileManager = LocalFileManager()
    @State private var searchText = ""
    @State private var selectedRepo: GitHubRepo?
    @State private var showRepoDetail = false
    @State private var sortOption: SortOption = .updated
    @State private var repoToDelete: GitHubRepo?
    @State private var showDeleteAlert = false
    @State private var repoToRename: GitHubRepo?
    @State private var showRenameDialog = false
    @State private var newRepoName = ""
    @State private var selectedRepoForMenu: GitHubRepo?
    @State private var showContextMenu = false
    @State private var showFileEditor = false
    @State private var mode: ViewMode = .repos
    
    enum ViewMode {
        case repos
        case files
    }
    
    enum SortOption: String, CaseIterable {
        case updated = "Updated"
        case name    = "Name"
        case stars   = "Stars"
    }

    var filteredRepos: [GitHubRepo] {
        var repos = gitHubService.repositories
        if !searchText.isEmpty {
            repos = repos.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        switch sortOption {
        case .name:  return repos.sorted { $0.name < $1.name }
        case .stars: return repos.sorted { $0.stargazersCount > $1.stargazersCount }
        default:     return repos
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                VStack(spacing: 0) {
                    if mode == .repos {
                        reposHeader
                        reposList
                    } else {
                        filesHeader
                        filesList
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRepoDetail) {
            if let repo = selectedRepo { RepoDetailView(repo: repo) }
        }
        .sheet(isPresented: $showContextMenu) {
            ContextMenuSheet(repo: selectedRepoForMenu, onDelete: { repo in
                repoToDelete = repo
                showDeleteAlert = true
            }, onRename: { repo in
                repoToRename = repo
                newRepoName = repo.name
                showRenameDialog = true
            }, onImport: { repo in
                importRepoToFiles(repo: repo)
            }, onOpenFiles: {
                mode = .files
            }, onDismiss: {
                selectedRepoForMenu = nil
            })
            .environmentObject(gitHubService)
        }
        .sheet(isPresented: $showFileEditor) {
            if let f = fileManager.selectedFile { 
                FileEditorView(file: f, content: fileManager.fileContent) { newContent in
                    fileManager.writeFile(f, content: newContent)
                }
            }
        }
        .alert("Delete Repository", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let repo = repoToDelete { Task { await gitHubService.deleteRepository(repo: repo) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(repoToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .alert("Rename Repository", isPresented: $showRenameDialog) {
            TextField("New name", text: $newRepoName)
            Button("Save", role: .destructive) { }
            Button("Cancel", role: .cancel) { newRepoName = "" }
        } message: {
            Text("Rename to: \(newRepoName)")
        }
        .onAppear {
            if gitHubService.repositories.isEmpty { Task { await gitHubService.fetchRepositories() } }
        }
    }
    
    // MARK: - Repos View
    
    private var reposHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Repos")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColors.text)
                if let user = gitHubService.currentUser {
                    Text("@\(user.login)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            Button { Task { await gitHubService.fetchRepositories() } } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
            }
            Button { selectedRepoForMenu = nil; showContextMenu = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22)).foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
    }
    
    private var reposList: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary)
                TextField("Search repositories...", text: $searchText)
                    .foregroundColor(AppColors.text).autocorrectionDisabled()
            }
            .padding(12).background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(searchText.isEmpty ? AppColors.border : AppColors.accent.opacity(0.5), lineWidth: 1))

            HStack {
                Text("\(filteredRepos.count) repos")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                Spacer()
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 210)
            }
        }
        .padding(.horizontal).padding(.bottom, 8)
        
        if gitHubService.isLoading {
            LoadingCard(); Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredRepos) { repo in
                        RepoCard(repo: repo) {
                            selectedRepo = repo; showRepoDetail = true
                        }
                        .padding(.horizontal)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    selectedRepoForMenu = repo
                                    showContextMenu = true
                                }
                        )
                    }
                }
                .padding(.vertical)
            }
            .refreshable { await gitHubService.fetchRepositories() }
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 16) {
            if selectedRepoForMenu != nil {
                Text("Imported: \(fileManager.rootFiles.count) files")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#6BCB77"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "#6BCB77").opacity(0.15))
                    .clipShape(Capsule())
            }
            Spacer()
            Button { openImportedFiles() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                    Text("Open Files")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(hex: "#FFD93D"))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(AppColors.surface.opacity(0.9))
    }
    
    // MARK: - Files View
    
    private var filesHeader: some View {
        HStack {
            Button { mode = .repos } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Files")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColors.text)
                Text(fileManager.currentPathDisplay)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Button { selectedRepoForMenu = nil; showContextMenu = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22)).foregroundColor(AppColors.accent)
            }
}
        .padding(.horizontal).padding(.bottom, 8)
    
    private var filesList: some View {
        VStack(spacing: 0) {
            if fileManager.isLoading {
                LoadingCard()
            } else if fileManager.rootFiles.isEmpty {
                EmptyStateView(icon: "folder.badge.plus", title: "Empty folder", subtitle: "Long press a repo > Import to Files")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(fileManager.rootFiles.enumerated()), id: \.element.id) { i, file in
                            FileRowView(
                                file: file, depth: 0, isEditMode: false,
                                canMoveUp: i > 0, canMoveDown: i < fileManager.rootFiles.count - 1,
                                onTap: { handleFileTap($0) },
                                onDelete: { fileToDelete = $0 },
                                onRename: { fileToRename = $0 },
                                onMoveUp: { },
                                onMoveDown: { }
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
    
    @State private var fileToDelete: GitFile?
    @State private var fileToRename: GitFile?
    @State private var showDeleteFileAlert = false
    @State private var showRenameFileDialog = false
    @State private var newFileName = ""
    
    private func handleFileTap(_ file: GitFile) {
        if file.isDirectory { 
            fileManager.loadFiles(at: URL(fileURLWithPath: file.path)) 
        } else { 
            fileManager.readFile(file)
            showFileEditor = true
        }
    }
    
    private func importRepoToFiles(repo: GitHubRepo) {
        guard let user = gitHubService.currentUser else { return }
        
        Task {
            do {
                let files = try await gitHubService.fetchRepoTree(owner: user.login, repo: repo.name, branch: repo.defaultBranch)
                let repoFolder = LocalFileManager.appDocumentsURL.appendingPathComponent(repo.name, isDirectory: true)
                try? FileManager.default.createDirectory(at: repoFolder, withIntermediateDirectories: true)
                
                for file in files {
                    let filePath = repoFolder.appendingPathComponent(file.path)
                    try? FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? file.content.write(to: filePath, atomically: true, encoding: .utf8)
                }
                
                await MainActor.run {
                    fileManager.loadFiles(at: LocalFileManager.appDocumentsURL)
                    selectedRepoForMenu = repo
                    mode = .files
                }
            } catch {
                await MainActor.run {
                    gitHubService.error = error.localizedDescription
                }
            }
        }
    }
    
    private func openImportedFiles() {
        mode = .files
    }
}

struct RepoCard: View {
    let repo: GitHubRepo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                        .font(.system(size: 13))
                        .foregroundColor(repo.isPrivate ? Color(hex: "#FFD93D") : AppColors.textSecondary)
                    Text(repo.name)
                        .font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                    if repo.isPrivate {
                        Text("Private").font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(hex: "#FFD93D"))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(hex: "#FFD93D").opacity(0.15)).clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                }
                if let desc = repo.description, !desc.isEmpty {
                    Text(desc).font(.system(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
                }
                HStack(spacing: 16) {
                    if let lang = repo.language {
                        HStack(spacing: 4) {
                            Circle().fill(languageColor(lang)).frame(width: 8, height: 8)
                            Text(lang).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    if repo.stargazersCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(Color(hex: "#FFD93D"))
                            Text("\(repo.stargazersCount)").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.branch").font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                        Text(repo.defaultBranch).font(.system(size: 12, design: .monospaced)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Text(shortDate(repo.updatedAt)).font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(16).glassCard()
        }
        .buttonStyle(.plain)
    }

    func languageColor(_ lang: String) -> Color {
        switch lang.lowercased() {
        case "swift": return Color(hex: "#F05138")
        case "python": return Color(hex: "#3572A5")
        case "javascript": return Color(hex: "#F1E05A")
        case "typescript": return Color(hex: "#2B7489")
        case "kotlin": return Color(hex: "#A97BFF")
        case "objective-c": return Color(hex: "#438EFF")
        case "c++": return Color(hex: "#F34B7D")
        default: return Color(hex: "#8888A0")
        }
    }

    func shortDate(_ s: String) -> String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: s) else { return s }
        let i = Date().timeIntervalSince(d)
        if i < 86400 { return "Today" }
        if i < 604800 { return "\(Int(i/86400))d" }
        if i < 2592000 { return "\(Int(i/604800))w" }
        return "\(Int(i/2592000))mo"
    }
}

struct RepoDetailView: View {
    let repo: GitHubRepo
    @EnvironmentObject var gitHubService: GitHubService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Text(repo.name).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                    Spacer()
                    Link(destination: URL(string: repo.htmlUrl)!) {
                        Image(systemName: "safari.fill").font(.system(size: 20)).foregroundColor(AppColors.accent)
                    }
                }
                .padding()
                Divider().background(AppColors.border)
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Clone URL", systemImage: "link")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            HStack {
                                Text(repo.cloneUrl)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppColors.text).lineLimit(1)
                                Spacer()
                                Button { UIPasteboard.general.string = repo.cloneUrl } label: {
                                    Image(systemName: "doc.on.doc.fill").font(.system(size: 16)).foregroundColor(AppColors.accent)
                                }
                            }
                            .padding(12).background(AppColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Label("How to clone on iPhone", systemImage: "iphone")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.text)
                            ForEach(Array([
                                "Copy the Clone URL above",
                                "Open Files app on iPhone",
                                "Go to: On My iPhone > GitActionsHub > Projects",
                                "Place your files there",
                                "Return to app and use Commit & Push"
                            ].enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle().fill(AppColors.accent.opacity(0.2)).frame(width: 22, height: 22)
                                        Text("\(i+1)").font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.accent)
                                    }
                                    Text(step).font(.system(size: 13)).foregroundColor(AppColors.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16).glassCard()
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Keep ProfileView here too
struct ProfileView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                VStack(spacing: 0) {
                    HStack {
                        Text("Profile").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                        Spacer()
                    }
                    .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)

                    ScrollView {
                        VStack(spacing: 20) {
                            if let user = gitHubService.currentUser {
                                // User card
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle().fill(AppColors.accent.opacity(0.2)).frame(width: 70, height: 70)
                                        AsyncImage(url: URL(string: user.avatarUrl)) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Image(systemName: "person.circle.fill").font(.system(size: 40)).foregroundColor(AppColors.accent)
                                        }
                                        .frame(width: 64, height: 64).clipShape(Circle())
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let name = user.name {
                                            Text(name).font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text)
                                        }
                                        Text("@\(user.login)").font(.system(size: 14, design: .monospaced)).foregroundColor(AppColors.textSecondary)
                                        HStack(spacing: 4) {
                                            Circle().fill(Color(hex: "#6BCB77")).frame(width: 6, height: 6)
                                            Text("Connected").font(.system(size: 12)).foregroundColor(Color(hex: "#6BCB77"))
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(16).glassCard().padding(.horizontal)

                                // Stats
                                HStack(spacing: 10) {
                                    StatCard(value: "\(user.publicRepos)", label: "Repos",     color: AppColors.accent,           icon: "square.stack.3d.up.fill")
                                    StatCard(value: "\(user.followers)",   label: "Followers", color: Color(hex: "#FF6B6B"),       icon: "person.2.fill")
                                    StatCard(value: "\(user.following)",   label: "Following", color: Color(hex: "#6BCB77"),       icon: "person.fill.checkmark")
                                }
                                .padding(.horizontal)
                            }

                            // About
                            VStack(alignment: .leading, spacing: 14) {
                                Label("About", systemImage: "info.circle.fill")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                                infoRow("Version",   "1.0.0")
                                infoRow("Stack",     "SwiftUI + GitHub API")
                                infoRow("Developer", "Ali Farhan")
                                infoRow("GitHub",    "@XFFF0")
                            }
                            .padding(16).glassCard().padding(.horizontal)

                            // Features
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Features", systemImage: "star.fill")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                                FeatureRow(icon: "bolt.circle.fill",           color: AppColors.accent,         text: "Live Actions monitoring")
                                FeatureRow(icon: "exclamationmark.triangle.fill", color: Color(hex: "#FFD93D"), text: "Auto error detection with line numbers")
                                FeatureRow(icon: "doc.text.fill",               color: Color(hex: "#6BCB77"),   text: "Colorized build logs")
                                FeatureRow(icon: "folder.fill",                 color: Color(hex: "#FFD93D"),   text: "File manager")
                                FeatureRow(icon: "arrow.up.circle.fill",        color: Color(hex: "#FF6B6B"),   text: "Direct Commit & Push")
                                FeatureRow(icon: "sparkles",                    color: Color(hex: "#C77DFF"),   text: "Liquid Glass design")
                                FeatureRow(icon: "hand.tap.fill",               color: Color(hex: "#FFD93D"),   text: "Long press to delete repos")
                            }
                            .padding(16).glassCard().padding(.horizontal)

                            // Logout
                            Button { showLogoutAlert = true } label: {
                                HStack {
                                    Image(systemName: "arrow.right.square.fill")
                                    Text("Sign Out").font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#FF6B6B")).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color(hex: "#FF6B6B").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1))
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Sign Out", isPresented: $showLogoutAlert) {
            Button("Sign Out", role: .destructive) { gitHubService.logout() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Sign out from GitHub?") }
    }

    func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(AppColors.text)
        }
    }
}

struct ContextMenuSheet: View {
    @EnvironmentObject var gitHubService: GitHubService
    let repo: GitHubRepo?
    let onDelete: (GitHubRepo) -> Void
    let onRename: (GitHubRepo) -> Void
    let onImport: (GitHubRepo) -> Void
    let onOpenFiles: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Text(repo?.name ?? "Options")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.text)
                    Spacer()
                    Spacer().frame(width: 22)
                }
                .padding()
                Divider().background(AppColors.border)
                
                VStack(spacing: 12) {
                    if let repo = repo {
                        menuButton(icon: "arrow.down.circle.fill", color: Color(hex: "#6BCB77"), label: "Import to Files") {
                            onImport(repo)
                            dismiss()
                        }
                        
                        menuButton(icon: "folder.fill", color: Color(hex: "#FFD93D"), label: "Open Imported Files") {
                            onOpenFiles()
                            dismiss()
                        }
                        
                        menuButton(icon: "safari.fill", color: AppColors.accent, label: "Open in Browser") {
                            if let url = URL(string: repo.htmlUrl) {
                                UIApplication.shared.open(url)
                            }
                            dismiss()
                        }
                        
                        menuButton(icon: "pencil.circle.fill", color: Color(hex: "#C77DFF"), label: "Rename") {
                            onRename(repo)
                            dismiss()
                        }
                        
                        menuButton(icon: "trash.circle.fill", color: Color(hex: "#FF6B6B"), label: "Delete") {
                            onDelete(repo)
                            dismiss()
                        }
                    } else {
                        menuButton(icon: "plus.circle.fill", color: AppColors.accent, label: "Create New Repository") {
                            // TODO: Create new repo
                        }
                        
                        menuButton(icon: "link.circle.fill", color: Color(hex: "#6BCB77"), label: "Clone from URL") {
                            // TODO: Clone from URL
                        }
                    }
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func menuButton(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
