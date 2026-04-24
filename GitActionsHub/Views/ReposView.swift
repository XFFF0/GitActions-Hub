import SwiftUI

// MARK: - Repos View

struct ReposView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @StateObject private var fileManager = LocalFileManager()

    @State private var searchText       = ""
    @State private var selectedRepo: GitHubRepo?
    @State private var showContextMenu  = false
    @State private var showDeleteAlert  = false
    @State private var showNewRepoSheet = false
    @State private var showFileEditor   = false
    @State private var isImporting      = false
    @State private var importStatus     = ""
    @State private var newRepoName      = ""
    @State private var newRepoDesc      = ""
    @State private var isCreating       = false
    // mode: 0 = repos list, 1 = file browser inside imported repo
    @State private var mode             = 0
    // track which folder we navigated into inside file browser
    @State private var fileBrowserTitle = ""

    var filteredRepos: [GitHubRepo] {
        var r = gitHubService.repositories
        if !searchText.isEmpty {
            r = r.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) }
        }
        return r.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                if mode == 0 {
                    reposHeader
                    searchBar
                    if isImporting || !importStatus.isEmpty { statusBanner }
                    reposList
                } else {
                    fileBrowserView
                }
            }

            // Glass context menu overlay
            if showContextMenu, let repo = selectedRepo {
                glassContextMenu(repo)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showContextMenu)
                    .zIndex(99)
            }
        }
        .sheet(isPresented: $showNewRepoSheet) { newRepoSheet }
        .sheet(isPresented: $showDeleteAlert)  { deleteSheet }
        .sheet(isPresented: $showFileEditor)   {
            if let f = fileManager.selectedFile {
                CodeEditorSheet(file: f, content: fileManager.fileContent) { fileManager.writeFile(f, content: $0) }
            }
        }
        .onAppear {
            if gitHubService.repositories.isEmpty { Task { await gitHubService.fetchRepositories() } }
        }
    }

    // MARK: - Repos Header
    var reposHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Repos")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColors.text)
                if let u = gitHubService.currentUser {
                    Text("@\(u.login)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            Button { Task { await gitHubService.fetchRepositories() } } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
            }
            Button { showNewRepoSheet = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22)).foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
    }

    // MARK: - Search Bar
    var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary)
                TextField("Search repositories...", text: $searchText)
                    .foregroundColor(AppColors.text).autocorrectionDisabled()
            }
            .padding(12).background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColors.border, lineWidth: 1))

            Text("\(filteredRepos.count) repos")
                .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal).padding(.bottom, 8)
    }

    // MARK: - Import Status Banner
    var statusBanner: some View {
        HStack(spacing: 10) {
            if isImporting {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent)).scaleEffect(0.8)
            } else {
                Image(systemName: importStatus.contains("imported") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(importStatus.contains("imported") ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B"))
            }
            Text(importStatus).font(.system(size: 13)).foregroundColor(AppColors.text).lineLimit(1)
            Spacer()
            if !isImporting {
                Button { importStatus = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(AppColors.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
        .padding(.horizontal).padding(.bottom, 8)
    }

    // MARK: - Repos List
    var reposList: some View {
        Group {
            if gitHubService.isLoading {
                LoadingCard(); Spacer()
            } else if filteredRepos.isEmpty {
                EmptyStateView(icon: "square.stack.3d.up", title: "No repositories", subtitle: "Pull to refresh or create a new repo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredRepos) { repo in
                            repoCard(repo)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable { await gitHubService.fetchRepositories() }
            }
        }
    }

    // MARK: - Repo Card
    func repoCard(_ repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                    .font(.system(size: 13))
                    .foregroundColor(repo.isPrivate ? Color(hex: "#FFD93D") : AppColors.textSecondary)
                Text(repo.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)
                if repo.isPrivate {
                    Text("Private").font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFD93D"))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color(hex: "#FFD93D").opacity(0.15)).clipShape(Capsule())
                }
                Spacer()
                // ··· button
                Button {
                    selectedRepo = repo
                    withAnimation { showContextMenu = true }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if let desc = repo.description, !desc.isEmpty {
                Text(desc).font(.system(size: 13)).foregroundColor(AppColors.textSecondary).lineLimit(2)
            }

            HStack(spacing: 14) {
                if let lang = repo.language {
                    HStack(spacing: 4) {
                        Circle().fill(langColor(lang)).frame(width: 8, height: 8)
                        Text(lang).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                }
                if repo.stargazersCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(Color(hex: "#FFD93D"))
                        Text("\(repo.stargazersCount)").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
                Text(shortDate(repo.updatedAt)).font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
            }

            // Quick action buttons
            HStack(spacing: 0) {
                quickBtn("Import", icon: "arrow.down.circle.fill", color: Color(hex: "#6BCB77")) {
                    importRepoFiles(repo)
                }
                Divider().frame(height: 16).background(AppColors.border)
                quickBtn("Browser", icon: "safari.fill", color: AppColors.accent) {
                    if let u = URL(string: repo.htmlUrl) { UIApplication.shared.open(u) }
                }
                Divider().frame(height: 16).background(AppColors.border)
                quickBtn("Clone", icon: "doc.on.doc.fill", color: Color(hex: "#C77DFF")) {
                    UIPasteboard.general.string = repo.cloneUrl
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .glassCard()
    }

    func quickBtn(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
                Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Glass Context Menu
    func glassContextMenu(_ repo: GitHubRepo) -> some View {
        ZStack(alignment: .bottom) {
            // Backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showContextMenu = false } }

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10).padding(.bottom, 6)

                // Repo name header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.name).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        Text(repo.isPrivate ? "Private" : "Public").font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Button { withAnimation { showContextMenu = false } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 16)

                // Menu items — scrollable so Delete is always reachable
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        glassMenuItem(icon: "arrow.down.circle.fill", color: Color(hex: "#6BCB77"), title: "Import to Files", subtitle: "Download all repo files") {
                            importRepoFiles(repo); withAnimation { showContextMenu = false }
                        }
                        glassMenuItem(icon: "safari.fill", color: AppColors.accent, title: "Open in Browser", subtitle: repo.htmlUrl) {
                            if let u = URL(string: repo.htmlUrl) { UIApplication.shared.open(u) }
                            withAnimation { showContextMenu = false }
                        }
                        glassMenuItem(icon: "doc.on.doc.fill", color: Color(hex: "#C77DFF"), title: "Copy Clone URL", subtitle: repo.cloneUrl) {
                            UIPasteboard.general.string = repo.cloneUrl
                            withAnimation { showContextMenu = false }
                        }
                        // Delete — always visible, red tint separator above
                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                        glassMenuItem(icon: "trash.fill", color: Color(hex: "#FF6B6B"), title: "Delete Repository", subtitle: "This action cannot be undone") {
                            withAnimation { showContextMenu = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showDeleteAlert = true }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 340) // cap height so sheet doesn't overflow screen

                Spacer().frame(height: 34) // safe area
            }
            .background(
                // Liquid glass background
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 8)
            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: -10)
        }
    }

    func glassMenuItem(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.white.opacity(0.5)).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    // MARK: - File Browser (mode == 1)
    var fileBrowserView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Back to Files (not back to Repos)
                Button {
                    if fileManager.isAtRoot {
                        mode = 0
                    } else {
                        fileManager.navigateUp()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text(fileManager.isAtRoot ? "Repos" : "Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Files").font(.system(size: 22, weight: .black)).foregroundColor(AppColors.text)
                    Text(fileManager.currentPathDisplay)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()

                Button { fileManager.loadFiles(at: fileManager.currentPath) } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 16)).foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 8)

            Divider().background(AppColors.border)

            if fileManager.isLoading {
                LoadingCard()
                Spacer()
            } else if fileManager.rootFiles.isEmpty {
                EmptyStateView(icon: "folder", title: "Empty folder", subtitle: "No files here")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(fileManager.rootFiles) { file in
                            fileBrowserRow(file)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    func fileBrowserRow(_ file: GitFile) -> some View {
        Button {
            if file.isDirectory {
                fileManager.loadFiles(at: URL(fileURLWithPath: file.path))
            } else {
                fileManager.readFile(file)
                showFileEditor = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: file.icon)
                    .font(.system(size: 16))
                    .foregroundColor(file.iconColor)
                    .frame(width: 22)
                Text(file.name)
                    .font(.system(size: 14, design: file.isDirectory ? .default : .monospaced))
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)
                Spacer()
                if !file.isDirectory {
                    Text(fmtSize(file.size))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.vertical, 9).padding(.horizontal, 14)
            .background(AppColors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    func fmtSize(_ b: Int64) -> String {
        if b < 1024 { return "\(b)B" }
        if b < 1_048_576 { return "\(b/1024)KB" }
        return "\(b/1_048_576)MB"
    }

    // MARK: - Import
    func importRepoFiles(_ repo: GitHubRepo) {
        guard let user = gitHubService.currentUser else { importStatus = "Error: Not logged in"; return }
        isImporting = true
        importStatus = "Fetching \(repo.name)..."
        Task {
            do {
                let files = try await gitHubService.fetchRepoTree(owner: user.login, repo: repo.name, branch: repo.defaultBranch)
                // Save to app's Projects folder
                let folder = LocalFileManager.appDocumentsURL.appendingPathComponent(repo.name, isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for f in files {
                    let dest = folder.appendingPathComponent(f.path)
                    try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? f.content.write(to: dest, atomically: true, encoding: .utf8)
                }
                await MainActor.run {
                    fileManager.loadFiles(at: folder)
                    isImporting = false
                    importStatus = "\(files.count) files imported!"
                    mode = 1 // Switch to file browser
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - New Repo Sheet
    var newRepoSheet: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("New Repository").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text)
                    Spacer()
                }
                .padding()
                Divider().background(AppColors.border)
                VStack(spacing: 16) {
                    TextField("repo-name", text: $newRepoName)
                        .font(.system(size: 15)).foregroundColor(AppColors.text)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .padding(12).background(AppColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    TextField("description (optional)", text: $newRepoDesc)
                        .font(.system(size: 15)).foregroundColor(AppColors.text)
                        .padding(12).background(AppColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button { createRepo() } label: {
                        Text(isCreating ? "Creating..." : "Create Repository")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(AppColors.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(newRepoName.isEmpty || isCreating)
                }
                .padding()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Delete Sheet
    var deleteSheet: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44)).foregroundColor(Color(hex: "#FF6B6B"))
                Text("Delete Repository?")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.text)
                Text("This will permanently delete \"\(selectedRepo?.name ?? "")\" from GitHub.")
                    .font(.system(size: 14)).foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Button { selectedRepo = nil; showDeleteAlert = false } label: {
                        Text("Cancel").font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.text)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button { deleteRepo() } label: {
                        Text("Delete").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(Color(hex: "#FF6B6B")).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(30)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers
    func langColor(_ l: String) -> Color {
        switch l.lowercased() {
        case "swift": return Color(hex: "#F05138")
        case "python": return Color(hex: "#3572A5")
        case "javascript": return Color(hex: "#F1E05A")
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
        if i < 604800 { return "\(Int(i/86400))d ago" }
        if i < 2592000 { return "\(Int(i/604800))w ago" }
        return "\(Int(i/2592000))mo ago"
    }

    func createRepo() {
        guard !newRepoName.isEmpty else { return }
        isCreating = true
        Task {
            do {
                let body: [String: Any] = ["name": newRepoName, "description": newRepoDesc, "private": false]
                let data = try JSONSerialization.data(withJSONObject: body)
                let _: EmptyResponse = try await gitHubService.makeRequest(endpoint: "/user/repos", method: "POST", body: data)
                await MainActor.run {
                    newRepoName = ""; newRepoDesc = ""; isCreating = false; showNewRepoSheet = false
                    Task { await gitHubService.fetchRepositories() }
                }
            } catch {
                await MainActor.run { isCreating = false }
            }
        }
    }

    func deleteRepo() {
        guard let repo = selectedRepo else { return }
        Task {
            await gitHubService.deleteRepository(repo: repo)
            await MainActor.run { selectedRepo = nil; showDeleteAlert = false }
        }
    }
}

// MARK: - Profile View
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
                                userCard(user)
                                HStack(spacing: 10) {
                                    StatCard(value: "\(user.publicRepos)", label: "Repos",     color: AppColors.accent,       icon: "square.stack.3d.up.fill")
                                    StatCard(value: "\(user.followers)",   label: "Followers", color: Color(hex: "#FF6B6B"),   icon: "person.2.fill")
                                    StatCard(value: "\(user.following)",   label: "Following", color: Color(hex: "#6BCB77"),   icon: "person.fill.checkmark")
                                }.padding(.horizontal)
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                Label("About", systemImage: "info.circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                                infoRow("Version",   "1.0.0")
                                infoRow("Stack",     "SwiftUI + GitHub API")
                                infoRow("Developer", "Ali Farhan")
                                infoRow("GitHub",    "@XFFF0")
                            }
                            .padding(16).glassCard().padding(.horizontal)

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Features", systemImage: "star.fill").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                                FeatureRow(icon: "bolt.circle.fill",              color: AppColors.accent,         text: "Live Actions monitoring")
                                FeatureRow(icon: "exclamationmark.triangle.fill", color: Color(hex: "#FFD93D"),    text: "Auto error detection")
                                FeatureRow(icon: "doc.text.fill",                 color: Color(hex: "#6BCB77"),    text: "Colorized build logs")
                                FeatureRow(icon: "arrow.down.circle.fill",        color: Color(hex: "#6BCB77"),    text: "Import repo files directly")
                                FeatureRow(icon: "arrow.up.circle.fill",          color: Color(hex: "#FF6B6B"),    text: "Commit & Push")
                                FeatureRow(icon: "sparkles",                      color: Color(hex: "#C77DFF"),    text: "Liquid Glass design")
                            }
                            .padding(16).glassCard().padding(.horizontal)

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

    func userCard(_ user: GitHubUser) -> some View {
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
    }

    func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(v).font(.system(size: 13, weight: .medium)).foregroundColor(AppColors.text)
        }
    }
}
