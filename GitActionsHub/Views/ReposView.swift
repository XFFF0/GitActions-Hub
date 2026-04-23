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
    @State private var newRepoName = ""
    @State private var selectedRepoForMenu: GitHubRepo?
    @State private var showContextMenu = false
    @State private var showFileEditor = false
    @State private var mode: ViewMode = .repos
    
    enum ViewMode { case repos, files }
    
    enum SortOption: String, CaseIterable { case updated = "Updated", case name = "Name", case stars = "Stars" }

    var filteredRepos: [GitHubRepo] {
        var repos = gitHubService.repositories
        if !searchText.isEmpty { repos = repos.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) } }
        switch sortOption { case .name: return repos.sorted { $0.name < $1.name }; case .stars: return repos.sorted { $0.stargazersCount > $1.stargazersCount }; default: return repos }
    }
    
    var body: some View {
        NavigationStack { ZStack { AnimatedGradientBackground(); if mode == .repos { reposContent } else { filesContent } }.navigationBarHidden(true) }
        .sheet(isPresented: $showRepoDetail) { if let r = selectedRepo { RepoDetailView(repo: r) } }
        .sheet(isPresented: $showContextMenu) { ContextMenuSheetView(repo: selectedRepoForMenu, onDelete: { d in repoToDelete = d; showDeleteAlert = true }, onImport: { r in importRepoToFiles(r) }, onOpenFiles: { mode = .files }) }
        .sheet(isPresented: $showFileEditor) { if let f = fileManager.selectedFile { FileEditorView(file: f, content: fileManager.fileContent) { fileManager.writeFile(f, content: $0) } } }
        .alert("Delete", isPresented: $showDeleteAlert) { Button("Delete", role: .destructive) { if let r = repoToDelete { Task { await gitHubService.deleteRepository(repo: r) } }; Button("Cancel", role: .cancel) {} } message: { Text("Delete \"\(repoToDelete?.name ?? "")\"?") }
        .onAppear { if gitHubService.repositories.isEmpty { Task { await gitHubService.fetchRepositories() } } }
    }
    
    var reposContent: some View {
        VStack(spacing: 0) {
            HStack { VStack(alignment: .leading, spacing: 2) { Text("Repos").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text); if let u = gitHubService.currentUser { Text("@\(u.login)").font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.textSecondary) }; Spacer(); Button { Task { await gitHubService.fetchRepositories() } } label: { Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }; Button { selectedRepoForMenu = nil; showContextMenu = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.accent) } }.padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
            VStack(spacing: 10) { HStack { Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary); TextField("Search...", text: $searchText).foregroundColor(AppColors.text).autocorrectionDisabled() }.padding(12).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(searchText.isEmpty ? AppColors.border : AppColors.accent.opacity(0.5), lineWidth: 1)); HStack { Text("\(filteredRepos.count) repos").font(.system(size: 12)).foregroundColor(AppColors.textSecondary); Spacer(); Picker("Sort", selection: $sortOption) { ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 210) } }.padding(.horizontal).padding(.bottom, 8)
            if gitHubService.isLoading { LoadingCard(); Spacer() } else {
                ScrollView { LazyVStack(spacing: 10) { ForEach(filteredRepos) { repo in RepoCard(repo: repo) { selectedRepo = repo; showRepoDetail = true }.padding(.horizontal).simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in selectedRepoForMenu = repo; showContextMenu = true }) } }.padding(.vertical) }
            }
        }
    }
    
    var filesContent: some View {
        VStack(spacing: 0) {
            HStack { Button { mode = .repos } label: { Image(systemName: "chevron.left.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }; VStack(alignment: .leading, spacing: 2) { Text("Files").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text); Text(fileManager.currentPathDisplay).font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.textSecondary) }; Spacer() }.padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
            if fileManager.isLoading { LoadingCard() } else if fileManager.rootFiles.isEmpty { EmptyStateView(icon: "folder.badge.plus", title: "Empty", subtitle: "Long press repo > Import").frame(maxWidth: .infinity, maxHeight: .infinity) } else {
                ScrollView { LazyVStack(spacing: 2) { ForEach(Array(fileManager.rootFiles.enumerated()), id: \.element.id) { i, file in Button { handleFileTap(file) } label: { HStack(spacing: 10) { Image(systemName: file.icon).font(.system(size: 16)).foregroundColor(file.iconColor).frame(width: 20); Text(file.name).font(.system(size: 14, weight: .medium, design: file.isDirectory ? .default : .monospaced)).foregroundColor(AppColors.text).lineLimit(1); Spacer(); if !file.isDirectory { Text(fmtSize(file.size)).font(.system(size: 10)).foregroundColor(AppColors.textSecondary) } }.padding(.vertical, 8).padding(.horizontal, 12).background(AppColors.surface.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8)) } }.padding(8) }
            }
        }
    }
    
    func fmtSize(_ b: Int64) -> String { b < 1024 ? "\(b)B" : b < 1_048_576 ? "\(b/1024)KB" : "\(b/1_048_576)MB" }
    func handleFileTap(_ file: GitFile) { if file.isDirectory { fileManager.loadFiles(at: URL(fileURLWithPath: file.path)) } else { fileManager.readFile(file); showFileEditor = true } }
    func importRepoToFiles(_ repo: GitHubRepo) { guard let user = gitHubService.currentUser else { return }; Task { do { let files = try await gitHubService.fetchRepoTree(owner: user.login, repo: repo.name, branch: repo.defaultBranch); let folder = LocalFileManager.appDocumentsURL.appendingPathComponent(repo.name, isDirectory: true); try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); for f in files { let path = folder.appendingPathComponent(f.path); try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true); try? f.content.write(to: path, atomically: true, encoding: .utf8) }; await MainActor.run { fileManager.loadFiles(at: LocalFileManager.appDocumentsURL); mode = .files } } catch { await MainActor.run { gitHubService.error = error.localizedDescription } } } }
}

struct ContextMenuSheetView: View {
    @EnvironmentObject var gitHubService: GitHubService
    let repo: GitHubRepo?
    let onDelete: (GitHubRepo) -> Void
    let onImport: (GitHubRepo) -> Void
    let onOpenFiles: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack { AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary) }; Spacer(); Text(repo?.name ?? "Options").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text); Spacer(); Spacer().frame(width: 22) }.padding()
                Divider().background(AppColors.border)
                VStack(spacing: 12) {
                    if let r = repo {
                        btn("arrow.down.circle.fill", Color(hex: "#6BCB77"), "Import to Files") { onImport(r); dismiss() }
                        btn("folder.fill", Color(hex: "#FFD93D"), "Open Files") { onOpenFiles(); dismiss() }
                        btn("safari.fill", AppColors.accent, "Open in Browser") { if let url = URL(string: r.htmlUrl) { UIApplication.shared.open(url) }; dismiss() }
                        btn("trash.circle.fill", Color(hex: "#FF6B6B"), "Delete") { onDelete(r); dismiss() }
                    } else { btn("plus.circle.fill", AppColors.accent, "Create Repository") { }; btn("link.circle.fill", Color(hex: "#6BCB77"), "Clone from URL") { } }
                }.padding()
            }
        }.preferredColorScheme(.dark)
    }
    
    func btn(_ icon: String, _ color: Color, _ label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) { HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 20)).foregroundColor(color); Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.text); Spacer(); Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(AppColors.textSecondary) }.padding(16).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.3), lineWidth: 1)) }
    }
}