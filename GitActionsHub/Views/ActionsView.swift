import SwiftUI

// MARK: - Actions Dashboard View

struct ActionsView: View {
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedRepo: GitHubRepo?
    @State private var selectedRun: WorkflowRun?
    @State private var showRepoSelector = false
    @State private var showRunDetail = false
    @State private var autoRefresh = false
    @State private var refreshTimer: Timer?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                VStack(spacing: 0) {
                    actionsHeader
                    
                    if let repo = selectedRepo {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                statsRow
                                    .padding(.horizontal)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(
                                        title: "Workflow Runs",
                                        subtitle: "\(repo.fullName)"
                                    )
                                    .padding(.horizontal)
                                    
                                    if gitHubService.isLoading {
                                        LoadingCard()
                                    } else if gitHubService.workflowRuns.isEmpty {
                                        EmptyStateView(
                                            icon: "bolt.slash.circle",
                                            title: "No Runs",
                                            subtitle: "No Actions have been run yet"
                                        )
                                    } else {
                                        ForEach(gitHubService.workflowRuns) { run in
                                            WorkflowRunCard(run: run) {
                                                selectedRun = run
                                                showRunDetail = true
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                        .refreshable {
                            guard let user = gitHubService.currentUser else { return }
                            await gitHubService.fetchWorkflowRuns(
                                owner: user.login,
                                repo: repo.name
                            )
                        }
                    } else {
                        Spacer()
                        EmptyStateView(
                            icon: "square.stack.3d.up",
                            title: "Select Repository",
                            subtitle: "Tap the button above to select a repository"
                        )
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRepoSelector) {
            RepoSelectorSheet(selectedRepo: $selectedRepo, onSelect: { repo in
                selectedRepo = repo
                showRepoSelector = false
                loadRuns(for: repo)
            })
        }
        .sheet(isPresented: $showRunDetail) {
            if let run = selectedRun, let repo = selectedRepo {
                RunDetailView(run: run, repo: repo)
            }
        }
        .onAppear {
            Task { await gitHubService.fetchRepositories() }
        }
    }
    
    private func loadRuns(for repo: GitHubRepo) {
        guard let user = gitHubService.currentUser else { return }
        Task {
            await gitHubService.fetchWorkflowRuns(owner: user.login, repo: repo.name)
        }
    }
    
    var actionsHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Actions")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColors.text)
                
                Text("CI/CD Monitor")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Button {
                autoRefresh.toggle()
                if autoRefresh, let repo = selectedRepo {
                    startAutoRefresh(for: repo)
                } else {
                    refreshTimer?.invalidate()
                }
            } label: {
                Image(systemName: autoRefresh ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                    .font(.system(size: 22))
                    .foregroundColor(autoRefresh ? AppColors.accent : AppColors.textSecondary)
                    .glow(color: autoRefresh ? AppColors.accent : .clear, radius: 6)
            }
            
            Button {
                showRepoSelector = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 14))
                    Text(selectedRepo?.name ?? "Select Repo")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.accent.opacity(0.8))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    var statsRow: some View {
        let runs = gitHubService.workflowRuns
        let successCount = runs.filter { $0.conclusion == "success" }.count
        let failureCount = runs.filter { $0.conclusion == "failure" }.count
        let inProgress = runs.filter { $0.status == "in_progress" }.count
        
        return HStack(spacing: 10) {
            StatCard(value: "\(runs.count)", label: "Total", color: AppColors.accent, icon: "bolt.fill")
            StatCard(value: "\(successCount)", label: "Success", color: Color(hex: "#6BCB77"), icon: "checkmark.circle.fill")
            StatCard(value: "\(failureCount)", label: "Failed", color: Color(hex: "#FF6B6B"), icon: "xmark.circle.fill")
            StatCard(value: "\(inProgress)", label: "Running", color: Color(hex: "#FFD93D"), icon: "arrow.clockwise")
        }
    }
    
    private func startAutoRefresh(for repo: GitHubRepo) {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            guard let user = self.gitHubService.currentUser else { return }
            Task {
                await self.gitHubService.fetchWorkflowRuns(owner: user.login, repo: repo.name)
            }
        }
    }
}

// MARK: - Workflow Run Card

struct WorkflowRunCard: View {
    let run: WorkflowRun
    let onTap: () -> Void
    
    @State private var spinRotation: Double = 0
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(run.statusColor.opacity(0.15))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: run.statusIcon)
                            .font(.system(size: 18))
                            .foregroundColor(run.statusColor)
                            .rotationEffect(.degrees(run.status == "in_progress" ? spinRotation : 0))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.name ?? "Workflow Run")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.text)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text("#\(run.runNumber)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.accent)
                            
                            Text("•")
                                .foregroundColor(AppColors.border)
                            
                            Text(run.headBranch)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text("•")
                                .foregroundColor(AppColors.border)
                            
                            Text(run.event)
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        StatusBadge(status: run.status, conclusion: run.conclusion)
                        
                        Text(relativeTime(run.updatedAt))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10))
                    Text(String(run.headSha.prefix(7)))
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
        .onAppear {
            if run.status == "in_progress" {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    spinRotation = 360
                }
            }
        }
    }
    
    func relativeTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Now" }
        if interval < 3600 { return "\(Int(interval/60))m" }
        if interval < 86400 { return "\(Int(interval/3600))h" }
        return "\(Int(interval/86400))d"
    }
}

// MARK: - Run Detail View

struct RunDetailView: View {
    let run: WorkflowRun
    let repo: GitHubRepo
    
    @EnvironmentObject var gitHubService: GitHubService
    @State private var selectedJob: WorkflowJob?
    @State private var showLogs = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(run.name ?? "Workflow Run")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.text)
                        Text("#\(run.runNumber) · \(run.headBranch)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: run.status, conclusion: run.conclusion)
                }
                .padding()
                
                Divider()
                    .background(AppColors.border)
                
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            if run.status == "in_progress" {
                                ActionButton(
                                    icon: "stop.circle.fill",
                                    label: "Cancel",
                                    color: .orange
                                ) {
                                    Task {
                                        let owner = gitHubService.currentUser?.login ?? ""
                                        _ = await gitHubService.cancelWorkflow(owner: owner, repo: repo.name, runId: run.id)
                                    }
                                }
                            } else {
                                ActionButton(
                                    icon: "arrow.counterclockwise.circle.fill",
                                    label: "Re-run",
                                    color: AppColors.accent
                                ) {
                                    Task {
                                        let owner = gitHubService.currentUser?.login ?? ""
                                        _ = await gitHubService.reRunWorkflow(owner: owner, repo: repo.name, runId: run.id)
                                    }
                                }
                            }
                            
                            ActionButton(
                                icon: "doc.text.fill",
                                label: "Logs",
                                color: Color(hex: "#6BCB77")
                            ) {
                                if let job = gitHubService.workflowJobs.first {
                                    selectedJob = job
                                    showLogs = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Jobs", subtitle: "\(gitHubService.workflowJobs.count) tasks")
                                .padding(.horizontal)
                            
                            ForEach(gitHubService.workflowJobs) { job in
                                JobCard(job: job) {
                                    selectedJob = job
                                    Task {
                                        let owner = gitHubService.currentUser?.login ?? ""
                                        await gitHubService.fetchBuildLogs(owner: owner, repo: repo.name, jobId: job.id)
                                    }
                                    showLogs = true
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                let owner = gitHubService.currentUser?.login ?? ""
                await gitHubService.fetchWorkflowJobs(owner: owner, repo: repo.name, runId: run.id)
            }
        }
        .sheet(isPresented: $showLogs) {
            if let job = selectedJob {
                BuildLogsView(job: job, logs: gitHubService.buildLogs)
            }
        }
    }
}

// MARK: - Job Card

struct JobCard: View {
    let job: WorkflowJob
    let onTap: () -> Void
    
    var statusColor: Color {
        switch job.status {
        case "completed":
            switch job.conclusion {
            case "success": return .green
            case "failure": return Color(hex: "#FF6B6B")
            default: return .gray
            }
        case "in_progress": return AppColors.accent
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: job.status == "completed" && job.conclusion == "success"
                        ? "checkmark.circle.fill"
                        : job.status == "in_progress"
                        ? "arrow.clockwise.circle.fill"
                        : "xmark.circle.fill"
                    )
                    .foregroundColor(statusColor)
                    
                    Text(job.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.text)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(job.steps.prefix(5)) { step in
                        StepRow(step: step)
                    }
                    if job.steps.count > 5 {
                        Text("+ \(job.steps.count - 5) more steps")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

struct StepRow: View {
    let step: WorkflowStep
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stepColor)
                .frame(width: 6, height: 6)
            
            Text(step.name)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
    }
    
    var stepColor: Color {
        switch step.conclusion {
        case "success": return .green
        case "failure": return Color(hex: "#FF6B6B")
        case "skipped": return .gray
        default:
            return step.status == "in_progress" ? AppColors.accent : .gray
        }
    }
}

// MARK: - Build Logs View

struct BuildLogsView: View {
    let job: WorkflowJob
    let logs: [BuildLog]
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var filterType: BuildLog.LogLineType? = nil
    @State private var showErrorsOnly = false
    @State private var copiedError: String? = nil
    @State private var scrollToError = false
    @State private var selectedFilter: LogFilter = .all
    
    enum LogFilter: String, CaseIterable {
        case all = "All"
        case errors = "Errors"
        case warnings = "Warnings"
    }
    
    var filteredLogs: [BuildLog] {
        var result = logs
        
        switch selectedFilter {
        case .all:
            break
        case .errors:
            result = result.filter { $0.type == .error }
        case .warnings:
            result = result.filter { $0.type == .warning }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    var errorCount: Int { logs.filter { $0.type == .error }.count }
    var warningCount: Int { logs.filter { $0.type == .warning }.count }
    var lineCount: Int { logs.count }
    var filteredCount: Int { filteredLogs.count }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text("Build Logs")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.text)
                        
                        Spacer()
                        
                        Menu {
                            Button {
                                let allLogs = logs.map { "L\($0.lineNumber): \($0.content)" }.joined(separator: "\n")
                                UIPasteboard.general.string = allLogs
                                copiedError = "Copied \(logs.count) lines"
                            } label: {
                                Label("All Lines", systemImage: "doc.on.doc")
                            }
                            
                            Button {
                                let errors = logs.filter { $0.type == .error }.map { "L\($0.lineNumber): \($0.content)" }.joined(separator: "\n")
                                UIPasteboard.general.string = errors
                                copiedError = "Copied \(errorCount) errors"
                            } label: {
                                Label("Errors Only (\(errorCount))", systemImage: "exclamationmark.triangle")
                            }
                            
                            Button {
                                let warnings = logs.filter { $0.type == .warning }.map { "L\($0.lineNumber): \($0.content)" }.joined(separator: "\n")
                                UIPasteboard.general.string = warnings
                                copiedError = "Copied \(warningCount) warnings"
                            } label: {
                                Label("Warnings Only (\(warningCount))", systemImage: "exclamationmark.circle")
                            }
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        LogStatBadge(count: errorCount, label: "Error", color: Color(hex: "#FF6B6B"), icon: "exclamationmark.triangle.fill")
                        LogStatBadge(count: warningCount, label: "Warning", color: Color(hex: "#FFD93D"), icon: "exclamationmark.circle.fill")
                        LogStatBadge(count: filteredCount, label: "Lines", color: AppColors.textSecondary, icon: "text.alignleft")
                        
                        Spacer()
                        
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(LogFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Search logs...", text: $searchText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(AppColors.text)
                    }
                    .padding(10)
                    .background(AppColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(AppColors.border, lineWidth: 1)
                    )
                }
                .padding()
                
                Divider().background(AppColors.border)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredLogs) { log in
                            LogLineView(log: log)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(hex: "#080810"))
            }
        }
        .overlay(alignment: .top) {
            if let msg = copiedError {
                Text(msg)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copiedError = nil }
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Log Line View

struct LogLineView: View {
    let log: BuildLog
    @State private var isCopied = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("\(log.lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(hex: "#555570"))
                .frame(width: 48, alignment: .trailing)
                .padding(.trailing, 12)
            
            if let icon = log.type.icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(log.type.color)
                    .frame(width: 14)
                    .padding(.trailing, 6)
                    .padding(.top, 1)
            } else {
                Spacer().frame(width: 20)
            }
            
            Text(log.content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(log.type.color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if log.type == .error || log.type == .warning {
                Button {
                    UIPasteboard.general.string = "L\(log.lineNumber): \(log.content)"
                    withAnimation { isCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { isCopied = false }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(isCopied ? .green : AppColors.textSecondary)
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.leading, 8)
        .background(
            log.type == .error
                ? Color(hex: "#FF6B6B").opacity(0.08)
                : log.type == .warning
                ? Color(hex: "#FFD93D").opacity(0.05)
                : Color.clear
        )
    }
}

// MARK: - Helper Components

struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(AppColors.text)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard()
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct LogStatBadge: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 10))
        }
        .foregroundColor(color)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

struct LoadingCard: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
            Text("Loading...")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
        .padding(.horizontal)
    }
}

struct RepoSelectorSheet: View {
    @Binding var selectedRepo: GitHubRepo?
    let onSelect: (GitHubRepo) -> Void
    
    @EnvironmentObject var gitHubService: GitHubService
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    
    var filtered: [GitHubRepo] {
        if search.isEmpty { return gitHubService.repositories }
        return gitHubService.repositories.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            ($0.description?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Search...", text: $search)
                            .foregroundColor(AppColors.text)
                    }
                    .padding(12)
                    .background(AppColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                    
                    List(filtered) { repo in
                        Button {
                            onSelect(repo)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                                            .font(.system(size: 12))
                                            .foregroundColor(repo.isPrivate ? Color(hex: "#FFD93D") : AppColors.textSecondary)
                                        Text(repo.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(AppColors.text)
                                    }
                                    if let desc = repo.description {
                                        Text(desc)
                                            .font(.system(size: 12))
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if let lang = repo.language {
                                    Text(lang)
                                        .font(.system(size: 10))
                                        .foregroundColor(AppColors.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(AppColors.accent.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .listRowBackground(AppColors.surface)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
