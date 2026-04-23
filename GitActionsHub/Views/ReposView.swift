import SwiftUI

struct ReposView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @StateObject private var fileManager = LocalFileManager()
    @State private var searchText = ""
    @State private var selectedRepo: GitHubRepo?
    @State private var showDeleteAlert = false
    @State private var showNewRepoSheet = false
    @State private var showFileEditor = false
    @State private var importRepo: GitHubRepo?
    @State private var isImporting = false
    @State private var importStatus = ""
    @State private var newRepoName = ""
    @State private var newRepoDesc = ""
    @State private var isCreating = false
    
    enum ViewMode { case repos, files }
    
    var filteredRepos: [GitHubRepo] {
        var repos = gitHubService.repositories
        if !searchText.isEmpty { repos = repos.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) } }
        return repos.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        ZStack { AnimatedGradientBackground()
            VStack(spacing: 0) {
                headerBar
                searchBar
                importStatusBar
                if mode == .repos { reposList } else { filesList }
            }
        }
        .sheet(isPresented: $showNewRepoSheet) { newRepoSheet }
        .sheet(isPresented: $showDeleteAlert) { deleteDialog }
        .sheet(isPresented: $showFileEditor) { if let f = fileManager.selectedFile { fileEditorSheet(f) } }
        .onAppear { if gitHubService.repositories.isEmpty { Task { await gitHubService.fetchRepositories() } } }
    }
    
    @State private var mode: ViewMode = .repos
    
    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Repos").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                if let u = gitHubService.currentUser { Text("@\(u.login)").font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.textSecondary) }
            }
            Spacer()
            Button { Task { await gitHubService.fetchRepositories() } } label: { Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }
            Button { selectedRepo = nil; showNewRepoSheet = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.accent) }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
    }
    
    var searchBar: some View {
        VStack(spacing: 10) {
            HStack { Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary); TextField("Search...", text: $searchText).foregroundColor(AppColors.text).autocorrectionDisabled() }
            .padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.border, lineWidth: 1))
            Text("\(filteredRepos.count) repos").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal).padding(.bottom, 8)
    }
    
    var importStatusBar: some View {
        Group {
            if isImporting || !importStatus.isEmpty {
                HStack {
                    if isImporting {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent)).scaleEffect(0.8)
                    }
                    Text(importStatus).font(.system(size: 13)).foregroundColor(importStatus.contains("success") ? Color(hex: "#6BCB77") : AppColors.textSecondary)
                    Spacer()
                    if !isImporting {
                        Button { importStatus = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textSecondary) }
                    }
                }
                .padding(12).background(AppColors.surface.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal).padding(.bottom, 8)
                .glassCard()
            }
        }
    }
    
    var reposList: some View {
        Group {
            if gitHubService.isLoading { LoadingCard(); Spacer() } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredRepos) { repo in Button { selectedRepo = repo } label: { repoCardRow(repo) }.padding(.horizontal) }
                    }.padding(.vertical)
                }
            }
        }
    }
    
    var filesList: some View {
        VStack(spacing: 0) {
            HStack { Button { mode = .repos } label: { Image(systemName: "chevron.left.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }; VStack(alignment: .leading, spacing: 2) { Text("Files").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text); Text(fileManager.currentPathDisplay).font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.textSecondary) }; Spacer() }.padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
            if fileManager.isLoading { LoadingCard() } else if fileManager.rootFiles.isEmpty { EmptyStateView(icon: "folder.badge.plus", title: "Empty", subtitle: "Select repo > Import").frame(maxWidth: .infinity, maxHeight: .infinity) } else {
                ScrollView { LazyVStack(spacing: 2) { ForEach(Array(fileManager.rootFiles.enumerated()), id: \.element.id) { i, file in fileRow(file) } }.padding(8) }
            }
        }
    }
    
    func repoCardRow(_ repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: repo.isPrivate ? "lock.fill" : "globe").font(.system(size: 13)).foregroundColor(repo.isPrivate ? Color(hex: "#FFD93D") : AppColors.textSecondary)
                Text(repo.name).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                Spacer()
                Button { selectedRepo = repo; showDeleteAlert = true } label: { Image(systemName: "ellipsis.circle.fill").font(.system(size: 18)).foregroundColor(AppColors.textSecondary) }
            }
            if let d = repo.description { Text(d).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2) }
            HStack(spacing: 16) {
                if let l = repo.language { Label(l, systemImage: "chevron.left.forwardslash.chevron.right").font(.system(size: 11)).foregroundColor(AppColors.accent) }
                Label("\(repo.stargazersCount)", systemImage: "star.fill").font(.system(size: 11)).foregroundColor(Color(hex: "#FFD93D"))
                if repo.isPrivate { Text("Private").font(.system(size: 10)).foregroundColor(Color(hex: "#FFD93D")).padding(.horizontal, 6).padding(.vertical, 2).background(Color(hex: "#FFD93D").opacity(0.15)).clipShape(Capsule()) }
                Spacer()
            }
            HStack(spacing: 8) {
                Button { importRepoFiles(repo) } label: { HStack(spacing: 4) { Image(systemName: "arrow.down.circle.fill").font(.system(size: 12)); Text("Import") }.font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#6BCB77")) }.buttonStyle(.plain)
                Button { if let u = URL(string: repo.htmlUrl) { UIApplication.shared.open(u) } } label: { HStack(spacing: 4) { Image(systemName: "safari.fill").font(.system(size: 12)); Text("Browser") }.font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.accent) }.buttonStyle(.plain)
                Button { UIPasteboard.general.string = repo.cloneUrl } label: { HStack(spacing: 4) { Image(systemName: "doc.on.doc.fill").font(.system(size: 12)); Text("Clone") }.font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#C77DFF")) }.buttonStyle(.plain)
            }
        }
        .padding(16).background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: 12))
        .liquidGlass(cornerRadius: 12)
    }
    
    func fileRow(_ file: GitFile) -> some View {
        Button { handleFileTap(file) } label: {
            HStack(spacing: 10) {
                Image(systemName: file.icon).font(.system(size: 16)).foregroundColor(file.iconColor).frame(width: 20)
                Text(file.name).font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.text).lineLimit(1)
                Spacer()
                if !file.isDirectory { Text(fmtSize(file.size)).font(.system(size: 10)).foregroundColor(AppColors.textSecondary) }
            }
            .padding(.vertical, 8).padding(.horizontal, 12).background(AppColors.surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    func fmtSize(_ b: Int64) -> String { b < 1024 ? "\(b)B" : b < 1_048_576 ? "\(b/1024)KB" : "\(b/1_048_576)MB" }
    
    func handleFileTap(_ file: GitFile) { if file.isDirectory { fileManager.loadFiles(at: URL(fileURLWithPath: file.path)) } else { fileManager.readFile(file); showFileEditor = true } }
    
    func importRepoFiles(_ repo: GitHubRepo) {
        guard let user = gitHubService.currentUser else { importStatus = "Error: Not logged in"; return }
        isImporting = true
        importStatus = "Fetching \(repo.name)..."
        
        Task {
            do {
                let files = try await gitHubService.fetchRepoTree(owner: user.login, repo: repo.name, branch: repo.defaultBranch)
                await MainActor.run { importStatus = "Saving \(files.count) files..." }
                
                let folder = LocalFileManager.appDocumentsURL.appendingPathComponent(repo.name, isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                
                var saved = 0
                for f in files {
                    let path = folder.appendingPathComponent(f.path)
                    try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? f.content.write(to: path, atomically: true, encoding: .utf8)
                    saved += 1
                }
                
                await MainActor.run { 
                    fileManager.loadFiles(at: LocalFileManager.appDocumentsURL)
                    mode = .files
                    isImporting = false
                    importStatus = "\(saved) files imported successfully!"
                }
            } catch {
                await MainActor.run { 
                    isImporting = false
                    importStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    var newRepoSheet: some View {
        ZStack { AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Text("New Repository").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text); Spacer() }.padding()
                Divider().background(AppColors.border)
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) { Label("Name", systemImage: "textformat").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary); TextField("repo-name", text: $newRepoName).font(.system(size: 15)).foregroundColor(AppColors.text).autocorrectionDisabled().textInputAutocapitalization(.never) }.padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 8) { Label("Description", systemImage: "text.alignleft").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary); TextField("optional", text: $newRepoDesc).font(.system(size: 15)).foregroundColor(AppColors.text) }.padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                    Button { createNewRepo() } label: { HStack { if isCreating { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8) } else { Image(systemName: "plus.circle.fill") }; Text(isCreating ? "Creating..." : "Create Repository") }.font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 50).background(AppColors.accent).clipShape(RoundedRectangle(cornerRadius: 12)) }.disabled(newRepoName.isEmpty || isCreating)
                }.padding()
            }
        }.preferredColorScheme(.dark)
    }
    
    var deleteDialog: some View {
        ZStack { 
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundColor(Color(hex: "#FF6B6B"))
                    Text("Delete Repository?").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text)
                    Text("This will delete \"\(selectedRepo?.name ?? "")\" from GitHub.").font(.system(size: 14)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
                }
                .padding(30)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AppColors.border, lineWidth: 1))
                .liquidGlass(cornerRadius: 20, intensity: 0.8)
                
                HStack(spacing: 16) {
                    Button("Cancel") { selectedRepo = nil }.font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.text).frame(maxWidth: .infinity).frame(height: 44).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 10))
                    Button("Delete") { deleteRepo() }.font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 44).background(Color(hex: "#FF6B6B")).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(30)
        }.preferredColorScheme(.dark)
    }
    
    func createNewRepo() {
        guard !newRepoName.isEmpty, let user = gitHubService.currentUser else { return }
        isCreating = true
        Task {
            do {
                let body: [String: String] = ["name": newRepoName, "description": newRepoDesc, "private": "false"]
                let data = try JSONEncoder().encode(body)
                let _: EmptyResponse = try await gitHubService.makeRequest(endpoint: "/user/repos", method: "POST", body: data)
                await MainActor.run { newRepoName = ""; newRepoDesc = ""; isCreating = false; showNewRepoSheet = false; Task { await gitHubService.fetchRepositories() } }
            } catch {
                await MainActor.run { isCreating = false; gitHubService.error = error.localizedDescription }
            }
        }
    }
    
    func deleteRepo() {
        guard let repo = selectedRepo else { return }
        Task {
            await gitHubService.deleteRepository(repo: repo)
            await MainActor.run { selectedRepo = nil }
        }
    }
    
    func fileEditorSheet(_ file: GitFile) -> some View {
        FileEditorView(file: file, content: fileManager.fileContent) { newContent in
            fileManager.writeFile(file, content: newContent)
        }
    }
}