import SwiftUI

struct ReposView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var searchText = ""
    @State private var selectedRepo: GitHubRepo?
    @State private var showRepoDetail = false
    @State private var sortOption: SortOption = .updated
    @State private var repoToDelete: GitHubRepo?
    @State private var showDeleteAlert = false
    
    enum SortOption: String, CaseIterable {
        case updated = "محدّث"
        case name = "الاسم"
        case stars = "النجوم"
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
        case .name: return repos.sorted { $0.name < $1.name }
        case .stars: return repos.sorted { $0.stargazersCount > $1.stargazersCount }
        default: return repos
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                VStack(spacing: 0) {
                    reposHeader
                    
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary)
                            TextField("بحث في Repositories...", text: $searchText)
                                .foregroundColor(AppColors.text).autocorrectionDisabled()
                        }
                        .padding(12).background(AppColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(searchText.isEmpty ? AppColors.border : AppColors.accent.opacity(0.5), lineWidth: 1))
                        
                        HStack {
                            Text("\(filteredRepos.count) مستودع").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Picker("ترتيب", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented).frame(width: 200)
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 8)
                    
                    if gitHubService.isLoading {
                        LoadingCard(); Spacer()
                    } else {
                        ScrollView {
                            // Fix 1: Force entire list to LTR
                            LazyVStack(spacing: 10) {
                                ForEach(filteredRepos) { repo in
                                    RepoCard(repo: repo) {
                                        selectedRepo = repo
                                        showRepoDetail = true
                                    }
                                    .padding(.horizontal)
                                    .onLongPressGesture {
                                        repoToDelete = repo
                                        showDeleteAlert = true
                                    }
                                }
                            }
                            .padding(.vertical)
                            // Fix 1: Force LTR on entire list
                            .environment(\.layoutDirection, .leftToRight)
                        }
                        .refreshable { await gitHubService.fetchRepositories() }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRepoDetail) {
            if let repo = selectedRepo { RepoDetailView(repo: repo) }
        }
        .alert("حذف المستودع", isPresented: $showDeleteAlert) {
            Button("حذف", role: .destructive) {
                if let repo = repoToDelete { Task { await gitHubService.deleteRepository(repo: repo) } }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("هل تريد حذف \"\(repoToDelete?.name ?? "")\"؟\n⚠️ لا يمكن التراجع عن هذا الإجراء.")
        }
        .onAppear {
            if gitHubService.repositories.isEmpty { Task { await gitHubService.fetchRepositories() } }
        }
    }
    
    var reposHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Repos").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                if let user = gitHubService.currentUser {
                    Text("@\(user.login)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            Spacer()
            Button { Task { await gitHubService.fetchRepositories() } } label: {
                Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
    }
}

// MARK: - Repo Card
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
                    
                    // Fix 1: Explicit LTR text direction
                    Text(repo.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                    
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
        case "logos": return Color(hex: "#FF6B6B")
        default: return Color(hex: "#8888A0")
        }
    }
    
    func shortDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let interval = Date().timeIntervalSince(date)
        if interval < 86400 { return "اليوم" }
        if interval < 86400 * 7 { return "\(Int(interval/86400))ي" }
        if interval < 86400 * 30 { return "\(Int(interval/86400/7))أ" }
        return "\(Int(interval/86400/30))ش"
    }
}

// MARK: - Repo Detail View
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
                                    .environment(\.layoutDirection, .leftToRight)
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
                            Label("كيفية Clone على iPhone", systemImage: "iphone")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.text)
                            StepInstructions(steps: [
                                "انسخ Clone URL أعلاه",
                                "افتح تطبيق Files على iPhone",
                                "ادخل: On My iPhone > GitActionsHub > Projects",
                                "ضع ملفاتك هنا",
                                "ارجع للتطبيق واستخدم Commit & Push"
                            ])
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

struct StepInstructions: View {
    let steps: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(AppColors.accent.opacity(0.2)).frame(width: 22, height: 22)
                        Text("\(index + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(AppColors.accent)
                    }
                    Text(step).font(.system(size: 13)).foregroundColor(AppColors.text).fixedSize(horizontal: false, vertical: true)
                }
            }
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
                            if let user = gitHubService.currentUser { userCard(user) }
                            if let user = gitHubService.currentUser {
                                HStack(spacing: 10) {
                                    StatCard(value: "\(user.publicRepos)", label: "مستودع", color: AppColors.accent, icon: "square.stack.3d.up.fill")
                                    StatCard(value: "\(user.followers)", label: "متابع", color: Color(hex: "#FF6B6B"), icon: "person.2.fill")
                                    StatCard(value: "\(user.following)", label: "تتابع", color: Color(hex: "#6BCB77"), icon: "person.fill.checkmark")
                                }.padding(.horizontal)
                            }
                            
                            // Fix 2: username = XFFF0
                            VStack(alignment: .leading, spacing: 16) {
                                Label("حول التطبيق", systemImage: "info.circle.fill")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                                AppInfoRow(key: "الإصدار", value: "1.0.0")
                                AppInfoRow(key: "التقنية", value: "SwiftUI + GitHub API")
                                AppInfoRow(key: "المطور", value: "علي فرحان")
                                AppInfoRow(key: "GitHub", value: "@XFFF0")
                            }
                            .padding(16).glassCard().padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Label("الميزات", systemImage: "star.fill")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                                FeatureRow(icon: "bolt.circle.fill", color: AppColors.accent, text: "مراقبة Actions مباشرة")
                                FeatureRow(icon: "exclamationmark.triangle.fill", color: Color(hex: "#FFD93D"), text: "اكتشاف أخطاء تلقائي")
                                FeatureRow(icon: "doc.text.fill", color: Color(hex: "#6BCB77"), text: "سجلات بناء ملونة")
                                FeatureRow(icon: "folder.fill", color: Color(hex: "#FFD93D"), text: "إدارة ملفات المشروع")
                                FeatureRow(icon: "arrow.up.circle.fill", color: Color(hex: "#FF6B6B"), text: "Commit & Push مباشر")
                                FeatureRow(icon: "sparkles", color: Color(hex: "#C77DFF"), text: "تصميم Liquid Glass")
                                FeatureRow(icon: "hand.tap.fill", color: Color(hex: "#FFD93D"), text: "حذف Repos بالضغط المطول")
                            }
                            .padding(16).glassCard().padding(.horizontal)
                            
                            Button { showLogoutAlert = true } label: {
                                HStack {
                                    Image(systemName: "arrow.right.square.fill")
                                    Text("تسجيل الخروج").font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#FF6B6B")).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color(hex: "#FF6B6B").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1))
                            }
                            .padding(.horizontal)
                        }.padding(.vertical)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .alert("تسجيل الخروج", isPresented: $showLogoutAlert) {
            Button("خروج", role: .destructive) { gitHubService.logout() }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("هل تريد تسجيل الخروج من حساب GitHub؟") }
    }
    
    func userCard(_ user: GitHubUser) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(AppColors.accent.opacity(0.2)).frame(width: 70, height: 70)
                AsyncImage(url: URL(string: user.avatarUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
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
                    .environment(\.layoutDirection, .leftToRight)
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#6BCB77")).frame(width: 6, height: 6)
                    Text("متصل").font(.system(size: 12)).foregroundColor(Color(hex: "#6BCB77"))
                }
            }
            Spacer()
        }
        .padding(16).glassCard().padding(.horizontal)
    }
}

struct AppInfoRow: View {
    let key: String; let value: String
    var body: some View {
        HStack {
            Text(key).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(AppColors.text)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
