import SwiftUI

struct ReposView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @StateObject private var fileManager = LocalFileManager()
    @State private var searchText = ""
    @State private var selectedRepo: GitHubRepo?
    @State private var showRepoDetail = false
    @State private var repoToDelete: GitHubRepo?
    @State private var showDeleteAlert = false
    @State private var selectedRepoForMenu: GitHubRepo?
    @State private var showContextMenu = false
    @State private var showFileEditor = false
    @State private var mode: ViewMode = .repos
    
    enum ViewMode { case repos, files }
    enum SortOpt: String, CaseIterable { case up = "Updated", nm = "Name", st = "Stars" }
    
    var filteredRepos: [GitHubRepo] {
        var repos = gitHubService.repositories
        if !searchText.isEmpty { repos = repos.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) } }
        repos = repos.sorted { $0.updatedAt > $1.updatedAt }
        return repos
    }
    
    var body: some View {
        ZStack { AnimatedGradientBackground()
            VStack(spacing: 0) {
                headerBar
                searchBar
                if mode == .repos { reposList } else { filesList }
            }
        }
        .sheet(isPresented: $showRepoDetail) { if let r = selectedRepo { repoDetailSheet(r) } }
        .sheet(isPresented: $showContextMenu) { contextMenuSheet }
        .sheet(isPresented: $showFileEditor) { if let f = fileManager.selectedFile { fileEditorSheet(f) } }
        .alert("Delete", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { if let r = repoToDelete { Task { await gitHubService.deleteRepository(repo: r) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Delete \"\(repoToDelete?.name ?? "")\"?") }
        .onAppear { if gitHubService.repositories.isEmpty { Task { await gitHubService.fetchRepositories() } } }
    }
    
    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Repos").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                if let u = gitHubService.currentUser { Text("@\(u.login)").font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.textSecondary) }
            }
            Spacer()
            Button { Task { await gitHubService.fetchRepositories() } } label: { Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }
            Button { selectedRepoForMenu = nil; showContextMenu = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.accent) }
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
    
    var reposList: some View {
        Group {
            if gitHubService.isLoading { LoadingCard(); Spacer() } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredRepos) { repo in Button { selectedRepo = repo; showRepoDetail = true } label: { repoCardRow(repo) }
                        .padding(.horizontal).simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in selectedRepoForMenu = repo; showContextMenu = true }) }
                    }.padding(.vertical)
                }
            }
        }
    }
    
    var filesList: some View {
        VStack(spacing: 0) {
            HStack { Button { mode = .repos } label: { Image(systemName: "chevron.left.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }; VStack(alignment: .leading, spacing: 2) { Text("Files").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text); Text(fileManager.currentPathDisplay).font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.textSecondary) }; Spacer() }.padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
            if fileManager.isLoading { LoadingCard() } else if fileManager.rootFiles.isEmpty { EmptyStateView(icon: "folder.badge.plus", title: "Empty", subtitle: "Long press repo > Import").frame(maxWidth: .infinity, maxHeight: .infinity) } else {
                ScrollView { LazyVStack(spacing: 2) { ForEach(Array(fileManager.rootFiles.enumerated()), id: \.element.id) { i, file in fileRow(file) } }.padding(8) }
            }
        }
    }
    
    func repoCardRow(_ repo: GitHubRepo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: repo.isPrivate ? "lock.fill" : "globe").font(.system(size: 13)).foregroundColor(repo.isPrivate ? Color(hex: "#FFD93D") : AppColors.textSecondary)
            Text(repo.name).font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
            if let d = repo.description { Text(d).font(.system(size: 12)).foregroundColor(AppColors.textSecondary).lineLimit(1) }
            Spacer()
        }
        .padding(16).background(AppColors.surface).clipShape(RoundedRectangle(cornerRadius: 12))
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
    
    func handleFileTap(_ file: GitFile) {
        if file.isDirectory { fileManager.loadFiles(at: URL(fileURLWithPath: file.path)) } else { fileManager.readFile(file); showFileEditor = true }
    }
    
    func importRepoToFiles(_ repo: GitHubRepo) {
        guard let user = gitHubService.currentUser else { return }
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
                await MainActor.run { fileManager.loadFiles(at: LocalFileManager.appDocumentsURL); mode = .files }
            } catch { await MainActor.run { gitHubService.error = error.localizedDescription } }
        }
    }
    
    var contextMenuSheet: some View {
        ZStack { AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Button { } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }; Spacer(); Text(selectedRepoForMenu?.name ?? "Options").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text); Spacer() }.padding()
                Divider().background(AppColors.border)
                VStack(spacing: 12) {
                    if let r = selectedRepoForMenu {
                        menuBtn("arrow.down.circle.fill", Color(hex: "#6BCB77"), "Import to Files") { importRepoToFiles(r); }
                        menuBtn("folder.fill", Color(hex: "#FFD93D"), "Open Files") { mode = .files; }
                        menuBtn("safari.fill", AppColors.accent, "Open in Browser") { if let u = URL(string: r.htmlUrl) { UIApplication.shared.open(u) } }
                        menuBtn("trash.circle.fill", Color(hex: "#FF6B6B"), "Delete") { repoToDelete = r; showDeleteAlert = true; }
                    }
                }.padding()
            }
        }.preferredColorScheme(.dark)
    }
    
    func menuBtn(_ icon: String, _ color: Color, _ label: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 20)).foregroundColor(color); Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.text); Spacer() }
            .padding(16).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.3), lineWidth: 1))
        }
    }
    
    func repoDetailSheet(_ repo: GitHubRepo) -> some View {
        ZStack { AppColors.background.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack { Text(repo.name).font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text); Spacer(); Link(destination: URL(string: repo.htmlUrl)!) { Image(systemName: "safari.fill").font(.system(size: 20)).foregroundColor(AppColors.accent) } }
                .padding()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Clone URL", systemImage: "link").font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                        HStack { Text(repo.cloneUrl).font(.system(size: 12, design: .monospaced)).foregroundColor(AppColors.text).lineLimit(1); Spacer(); Button { UIPasteboard.general.string = repo.cloneUrl } label: { Image(systemName: "doc.on.doc.fill").font(.system(size: 16)).foregroundColor(AppColors.accent) } }
                        .padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.padding()
                }
            }
        }.preferredColorScheme(.dark)
    }
    
    func fileEditorSheet(_ file: GitFile) -> some View {
        FileEditorView(file: file, content: fileManager.fileContent) { newContent in
            fileManager.writeFile(file, content: newContent)
        }
    }
}