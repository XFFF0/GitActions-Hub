import SwiftUI

struct ReposView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @StateObject private var fileManager = LocalFileManager()
    @State private var searchText = ""
    @State private var selectedRepo: GitHubRepo?
    @State private var showDeleteAlert = false
    @State private var showNewRepoSheet = false
    @State private var showFileEditor = false
    @State private var showContextMenu = false
    @State private var isImporting = false
    @State private var importStatus = ""
    @State private var newRepoName = ""
    @State private var newRepoDesc = ""
    @State private var isCreating = false
    @State private var mode = 0
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            VStack(spacing: 0) {
                headerView
                searchView
                if isImporting || !importStatus.isEmpty { statusView }
                if mode == 0 { reposList } else { filesList }
            }
            if showContextMenu, let repo = selectedRepo {
                contextMenuView(repo)
            }
        }
        .sheet(isPresented: $showNewRepoSheet, content: { newRepoView })
        .sheet(isPresented: $showDeleteAlert, content: { deleteView })
        .sheet(isPresented: $showFileEditor, content: { editorView })
        .onAppear { if gitHubService.repositories.isEmpty { Task { await gitHubService.fetchRepositories() } } }
    }
    
    var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Repos").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                if let u = gitHubService.currentUser { Text("@\(u.login)").font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.textSecondary) }
            }
            Spacer()
            Button { Task { await gitHubService.fetchRepositories() } } label: { Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }
            Button { selectedRepo = nil; showNewRepoSheet = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.accent) }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
    }
    
    var searchView: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary)
                TextField("Search...", text: $searchText).foregroundColor(AppColors.text).autocorrectionDisabled()
            }
            .padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12))
            Text("\(filteredRepos.count) repos").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal).padding(.bottom, 8)
    }
    
    var statusView: some View {
        HStack {
            if isImporting { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent)).scaleEffect(0.8) }
            Text(importStatus).font(.system(size: 13)).foregroundColor(importStatus.contains("success") ? Color(hex: "#6BCB77") : AppColors.textSecondary)
            Spacer()
            if !isImporting { Button { importStatus = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textSecondary) } }
        }
        .padding(12).background(AppColors.surface.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal).padding(.bottom, 8)
    }
    
    var filteredRepos: [GitHubRepo] {
        var repos = gitHubService.repositories
        if !searchText.isEmpty { repos = repos.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) } }
        return repos.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var reposList: some View {
        Group {
            if gitHubService.isLoading { LoadingCard(); Spacer() } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredRepos) { repo in repoCard(repo) }
                    }.padding(.vertical)
                }
            }
        }
    }
    
    func repoCard(_ repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: repo.isPrivate ? "lock.fill" : "globe").foregroundColor(repo.isPrivate ? Color(hex: "#FFD93D") : AppColors.textSecondary)
                Text(repo.name).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                Spacer()
                Button { selectedRepo = repo; showContextMenu = true } label: { Image(systemName: "ellipsis.circle.fill").font(.system(size: 16)).foregroundColor(AppColors.textSecondary) }
            }
            if let d = repo.description { Text(d).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(2) }
            HStack {
                if let l = repo.language { Text(l).font(.system(size: 11)).foregroundColor(AppColors.accent) }
                Text("\(repo.stargazersCount)").font(.system(size: 11)).foregroundColor(Color(hex: "#FFD93D"))
                Spacer()
            }
            HStack(spacing: 12) {
                Button { importRepoFiles(repo) } label: { Text("Import").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#6BCB77")) }
                Button { if let u = URL(string: repo.htmlUrl) { UIApplication.shared.open(u) } } label: { Text("Browser").font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.accent) }
                Button { UIPasteboard.general.string = repo.cloneUrl } label: { Text("Clone").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#C77DFF")) }
            }
        }
        .padding(16).background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    var filesList: some View {
        VStack(spacing: 0) {
            HStack {
                Button { mode = 0 } label: { Image(systemName: "chevron.left.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }
                VStack(alignment: .leading) {
                    Text("Files").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                    Text(fileManager.currentPathDisplay).font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
            
            if fileManager.isLoading { LoadingCard() } else if fileManager.rootFiles.isEmpty {
                EmptyStateView(icon: "folder.badge.plus", title: "Empty", subtitle: "Select repo > Import").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(fileManager.rootFiles) { file in fileRow(file) }
                    }.padding(8)
                }
            }
        }
    }
    
    func fileRow(_ file: GitFile) -> some View {
        Button {
            if file.isDirectory { fileManager.loadFiles(at: URL(fileURLWithPath: file.path)) } else { fileManager.readFile(file); showFileEditor = true }
        } label: {
            HStack {
                Image(systemName: file.icon).foregroundColor(file.iconColor).frame(width: 20)
                Text(file.name).font(.system(size: 14)).foregroundColor(AppColors.text).lineLimit(1)
                Spacer()
                if !file.isDirectory { Text(fmt(file.size)).font(.system(size: 10)).foregroundColor(AppColors.textSecondary) }
            }
            .padding(.vertical, 8).padding(.horizontal, 12).background(AppColors.surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    func fmt(_ b: Int64) -> String { b < 1024 ? "\(b)B" : b < 1_048_576 ? "\(b/1024)KB" : "\(b/1_048_576)MB" }
    
    func importRepoFiles(_ repo: GitHubRepo) {
        guard let user = gitHubService.currentUser else { importStatus = "Error: Not logged in"; return }
        isImporting = true; importStatus = "Fetching \(repo.name)..."
        Task {
            do {
                let files = try await gitHubService.fetchRepoTree(owner: user.login, repo: repo.name, branch: repo.defaultBranch)
                let folder = LocalFileManager.appDocumentsURL.appendingPathComponent(repo.name, isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for f in files {
                    let path = folder.appendingPathComponent(f.path)
                    try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? f.content.write(to: path, atomically: true, encoding: .utf8)
                }
                await MainActor.run { fileManager.loadFiles(at: LocalFileManager.appDocumentsURL); mode = 1; isImporting = false; importStatus = "\(files.count) files imported!" }
            } catch { await MainActor.run { isImporting = false; importStatus = "Error: \(error.localizedDescription)" } }
        }
    }
    
    func contextMenuView(_ repo: GitHubRepo) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { showContextMenu = false }
            VStack(spacing: 0) {
                HStack { Text(repo.name).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text); Spacer(); Button { showContextMenu = false } label: { Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textSecondary) } }
                .padding().background(AppColors.surface)
                VStack(spacing: 8) {
                    menuBtn(icon: "arrow.down.circle.fill", color: Color(hex: "#6BCB77"), label: "Import to Files") { importRepoFiles(repo); showContextMenu = false }
                    menuBtn(icon: "safari.fill", color: AppColors.accent, label: "Open in Browser") { if let u = URL(string: repo.htmlUrl) { UIApplication.shared.open(u) }; showContextMenu = false }
                    menuBtn(icon: "doc.on.doc.fill", color: Color(hex: "#C77DFF"), label: "Copy Clone URL") { UIPasteboard.general.string = repo.cloneUrl; showContextMenu = false }
                    menuBtn(icon: "trash.fill", color: Color(hex: "#FF6B6B"), label: "Delete Repository") { showContextMenu = false; selectedRepo = repo; showDeleteAlert = true }
                }.padding().background(AppColors.surface)
            }.padding(.horizontal, 20).padding(.bottom, 20)
        }
    }
    
    func menuBtn(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.text)
                Spacer()
            }.padding(.vertical, 14).padding(.horizontal, 16).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    var newRepoView: some View {
        ZStack { AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Text("New Repository").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text); Spacer() }.padding()
                Divider().background(AppColors.border)
                VStack(spacing: 16) {
                    TextField("repo-name", text: $newRepoName).font(.system(size: 15)).foregroundColor(AppColors.text).autocorrectionDisabled().textInputAutocapitalization(.never).padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 10))
                    TextField("description (optional)", text: $newRepoDesc).font(.system(size: 15)).foregroundColor(AppColors.text).padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 10))
                    Button { createRepo() } label: { Text(isCreating ? "Creating..." : "Create Repository").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 50).background(AppColors.accent).clipShape(RoundedRectangle(cornerRadius: 12)) }.disabled(newRepoName.isEmpty || isCreating)
                }.padding()
            }
        }.preferredColorScheme(.dark)
    }
    
    var deleteView: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundColor(Color(hex: "#FF6B6B"))
                Text("Delete Repository?").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text)
                Text("This will delete \"\(selectedRepo?.name ?? "")\" from GitHub.").font(.system(size: 14)).foregroundColor(AppColors.textSecondary).multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Button { selectedRepo = nil } label: { Text("Cancel").font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.text).frame(maxWidth: .infinity).frame(height: 44).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    Button { deleteRepo() } label: { Text("Delete").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 44).background(Color(hex: "#FF6B6B")).clipShape(RoundedRectangle(cornerRadius: 10)) }
                }
            }.padding(30)
        }.preferredColorScheme(.dark)
    }
    
    var editorView: some View {
        Group {
            if let f = fileManager.selectedFile {
                FileEditorView(file: f, content: fileManager.fileContent) { fileManager.writeFile(f, content: $0) }
            }
        }
    }
    
    func createRepo() {
        guard !newRepoName.isEmpty, let _ = gitHubService.currentUser else { return }
        isCreating = true
        Task {
            do {
                let body: [String: String] = ["name": newRepoName, "description": newRepoDesc, "private": "false"]
                let data = try JSONEncoder().encode(body)
                let _: EmptyResponse = try await gitHubService.makeRequest(endpoint: "/user/repos", method: "POST", body: data)
                await MainActor.run { newRepoName = ""; newRepoDesc = ""; isCreating = false; showNewRepoSheet = false; Task { await gitHubService.fetchRepositories() } }
            } catch { await MainActor.run { isCreating = false; gitHubService.error = error.localizedDescription } }
        }
    }
    
    func deleteRepo() {
        guard let repo = selectedRepo else { return }
        Task { await gitHubService.deleteRepository(repo: repo); await MainActor.run { selectedRepo = nil } }
    }
}