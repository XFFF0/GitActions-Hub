import SwiftUI

enum RepoSortMode: String, CaseIterable {
    case updated = "آخر تحديث"
    case stars = "النجوم"
    case name = "الاسم"
}

struct ReposView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var searchText = ""
    @State private var sortMode: RepoSortMode = .updated
    @State private var selectedRepo: GitHubRepo?
    @State private var repoToDelete: GitHubRepo?
    @State private var showingDeleteConfirm = false

    var filteredRepos: [GitHubRepo] {
        var repos = gitHubService.repositories

        if !searchText.isEmpty {
            repos = repos.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.fullName.localizedCaseInsensitiveContains(searchText) ||
                ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortMode {
        case .updated:
            return repos
        case .stars:
            return repos.sorted(by: { $0.stargazersCount > $1.stargazersCount })
        case .name:
            return repos.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if gitHubService.isLoading && gitHubService.repositories.isEmpty {
                    loadingView
                } else if filteredRepos.isEmpty {
                    emptyView
                } else {
                    reposList
                }
            }
            .navigationTitle("📦 المستودعات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(RepoSortMode.allCases, id: \.self) { mode in
                            Button {
                                sortMode = mode
                            } label: {
                                Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }

                    Button {
                        Task { await gitHubService.fetchRepositories() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedRepo) { repo in
                RepoDetailView(repo: repo)
            }
            .alert("حذف المستودع", isPresented: $showingDeleteConfirm) {
                Button("إلغاء", role: .cancel) {}
                Button("حذف", role: .destructive) {
                    if let repo = repoToDelete {
                        Task { await gitHubService.deleteRepository(repo: repo) }
                    }
                }
            } message: {
                Text("هل أنت متأكد من حذف \(repoToDelete?.name ?? "")؟ لا يمكن التراجع عن هذا الإجراء.")
            }
        }
        .onAppear {
            if gitHubService.repositories.isEmpty {
                Task { await gitHubService.fetchRepositories() }
            }
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            Text("جارٍ تحميل المستودعات...")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "لا توجد مستودعات" : "لا توجد نتائج")
                .font(.title3)
                .foregroundColor(.white)
            if !searchText.isEmpty {
                Button("مسح البحث") { searchText = "" }
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: - Repos List
    private var reposList: some View {
        List {
            ForEach(filteredRepos) { repo in
                Button {
                    selectedRepo = repo
                } label: {
                    repoCard(repo)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .contextMenu {
                    Button { selectedRepo = repo } label: {
                        Label("فتح", systemImage: "arrow.right.circle")
                    }
                    Button(role: .destructive) {
                        repoToDelete = repo
                        showingDeleteConfirm = true
                    } label: {
                        Label("حذف", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "بحث عن مستودع...")
    }

    // MARK: - Repo Card
    private func repoCard(_ repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(repo.fullName)
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                if repo.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.accentSecondary)
                }

                if let lang = repo.language {
                    Circle()
                        .fill(languageColor(lang))
                        .frame(width: 10, height: 10)
                }
            }

            if let desc = repo.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                if repo.stargazersCount > 0 {
                    Label("\(repo.stargazersCount)", systemImage: "star.fill")
                        .foregroundColor(.yellow)
                }
                if repo.forksCount > 0 {
                    Label("\(repo.forksCount)", systemImage: "git.branch")
                        .foregroundColor(.secondary)
                }
                if let lang = repo.language {
                    Label(lang, systemImage: "circle.fill")
                        .foregroundColor(languageColor(lang))
                }
            }
            .font(.caption2)
        }
        .padding()
        .background(Color(hex: "1A1A25"))
        .cornerRadius(12)
    }

    // MARK: - Language Color
    private func languageColor(_ language: String) -> Color {
        switch language.lowercased() {
        case "swift": return Color(hex: "F05138")
        case "python": return Color(hex: "3572A5")
        case "javascript": return Color(hex: "F1E05A")
        case "typescript": return Color(hex: "2B7489")
        case "kotlin": return Color(hex: "A97BFF")
        case "objective-c": return Color(hex: "438EFF")
        case "c++": return Color(hex: "F34B7D")
        case "logos": return Color(hex: "FF6B6B")
        default: return Color(hex: "8888A0")
        }
    }

    // MARK: - User Card
    private func userCard(_ user: GitHubUser) -> some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatar_url ?? "")) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.secondary)
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())

            Text(user.login)
                .font(.headline)
                .foregroundColor(.white)

            if let name = user.name { Text(name).font(.subheadline).foregroundColor(.secondary) }

            HStack(spacing: 20) {
                VStack {
                    Text("\(user.public_repos ?? 0)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("مستودعات")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("\(user.followers ?? 0)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("متابعين")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("\(user.following ?? 0)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("يتابع")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Button("خروج", role: .destructive) { gitHubService.logout() }
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.15))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(hex: "1A1A25"))
        .cornerRadius(16)
    }
}

// MARK: - Repo Detail View
struct RepoDetailView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @Environment(\.dismiss) var dismiss
    let repo: GitHubRepo
    @State private var workflowRuns: [WorkflowRun] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Info card
                        infoCard

                        // Recent runs
                        if workflowRuns.isEmpty {
                            Text("لا توجد أكشنز حديثة")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        } else {
                            ForEach(workflowRuns) { run in
                                runMiniCard(run)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(repo.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { dismiss() }
                }
            }
        }
        .onAppear {
            Task { await loadRuns() }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "repo")
                    .foregroundColor(AppColors.accent)
                Text(repo.fullName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if repo.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                }
            }

            if let desc = repo.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                if repo.stargazersCount > 0 {
                    Label("\(repo.stargazersCount)", systemImage: "star.fill")
                        .foregroundColor(.yellow)
                }
                if repo.forksCount > 0 {
                    Label("\(repo.forksCount)", systemImage: "git.branch")
                        .foregroundColor(.secondary)
                }
                if let lang = repo.language {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(languageColor(lang))
                            .frame(width: 8, height: 8)
                        Text(lang)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .font(.caption)

            if let url = URL(string: repo.html_url) {
                Link("فتح في GitHub", destination: url)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding()
        .background(Color(hex: "1A1A25"))
        .cornerRadius(12)
    }

    private func runMiniCard(_ run: WorkflowRun) -> some View {
        HStack(spacing: 12) {
            Image(systemName: run.statusIcon)
                .foregroundColor(run.statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(run.name)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(run.head_branch)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(run.displayConclusion)
                .font(.caption)
        }
        .padding()
        .background(Color(hex: "1A1A25"))
        .cornerRadius(10)
    }

    private func loadRuns() async {
        guard let user = gitHubService.currentUser else { return }
        await gitHubService.fetchWorkflowRuns(owner: user.login, repo: repo.name)
        workflowRuns = gitHubService.workflowRuns
    }

    private func languageColor(_ language: String) -> Color {
        switch language.lowercased() {
        case "swift": return Color(hex: "F05138")
        case "python": return Color(hex: "3572A5")
        case "javascript": return Color(hex: "F1E05A")
        case "typescript": return Color(hex: "2B7489")
        case "kotlin": return Color(hex: "A97BFF")
        default: return Color(hex: "8888A0")
        }
    }
}
