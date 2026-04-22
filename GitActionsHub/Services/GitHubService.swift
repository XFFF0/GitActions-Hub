import Foundation
import SwiftUI

class GitHubService: ObservableObject {
    
    @Published var repos: [Repo] = []
    @Published var workflowRuns: [WorkflowRun] = []
    @Published var logLines: [LogLine] = []
    @Published var error: String?
    @Published var isLoading = false
    @Published var lastCommitResult: String?
    
    @Published var currentUser: GitHubUser?
    @Published var isAuthenticated: Bool = false
    
    // ✅ buildLogs — تستخدمها ActionsView
    @Published var buildLogs: [BuildLog] = []
    
    @Published var isPushing = false
    @Published var pushProgress: String = ""
    @Published var pushFileIndex: Int = 0
    @Published var pushFileTotal: Int = 0
    
    private let baseURL = "https://api.github.com"
    
    var token: String {
        UserDefaults.standard.string(forKey: "gh_access_token") ?? ""
    }
    
    var username: String {
        UserDefaults.standard.string(forKey: "gh_username") ?? ""
    }
    
    // ✅ Alias
    var repositories: [GitHubRepo] { repos }
    
    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        let url = URL(string: "\(baseURL)\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body { req.httpBody = body }
        return req
    }
    
    // MARK: - Token & Auth
    func loadSavedToken() {
        let savedToken = UserDefaults.standard.string(forKey: "gh_access_token")
        if let t = savedToken, !t.isEmpty {
            isAuthenticated = true
            loadSavedUser()
        } else {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    private func loadSavedUser() {
        guard let userData = UserDefaults.standard.data(forKey: "gh_user_data") else { return }
        currentUser = try? JSONDecoder().decode(GitHubUser.self, from: userData)
    }
    
    private func saveUser(_ user: GitHubUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "gh_user_data")
        }
        UserDefaults.standard.set(user.login, forKey: "gh_username")
    }
    
    func authenticateWithOAuth(token: String) async {
        guard !token.isEmpty else {
            await MainActor.run { self.error = "التوكن فارغ" }
            return
        }
        UserDefaults.standard.set(token, forKey: "gh_access_token")
        
        var req = URLRequest(url: URL(string: "\(baseURL)/user")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else { return }
            if httpResponse.statusCode == 200 {
                let user = try JSONDecoder().decode(GitHubUser.self, from: data)
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.error = nil
                }
                saveUser(user)
            } else {
                UserDefaults.standard.removeObject(forKey: "gh_access_token")
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.error = "التوكن غير صالح"
                }
            }
        } catch {
            await MainActor.run { self.error = "فشل الاتصال: \(error.localizedDescription)" }
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "gh_access_token")
        UserDefaults.standard.removeObject(forKey: "gh_user_data")
        UserDefaults.standard.removeObject(forKey: "gh_username")
        currentUser = nil
        isAuthenticated = false
        repos = []
        workflowRuns = []
        logLines = []
        buildLogs = []
        error = nil
    }
    
    func validateToken(_ token: String) async -> Bool {
        var req = URLRequest(url: URL(string: "\(baseURL)/user")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let user = try JSONDecoder().decode(GitHubUser.self, from: data)
                await MainActor.run { self.currentUser = user; self.isAuthenticated = true }
                saveUser(user)
                return true
            }
        } catch {}
        return false
    }
    
    func fetchRepositories() async { await fetchRepos() }
    
    func fetchRepos() async {
        await MainActor.run { isLoading = true; error = nil }
        var allRepos: [Repo] = []
        var page = 1
        repeat {
            let req = makeRequest("/user/repos?sort=updated&per_page=100&page=\(page)")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let httpResponse = response as? HTTPURLResponse else { break }
                if httpResponse.statusCode == 401 {
                    await MainActor.run { error = "التوكن غير صالح"; isLoading = false }
                    return
                }
                let pageRepos = try JSONDecoder().decode([Repo].self, from: data)
                allRepos.append(contentsOf: pageRepos)
                if pageRepos.count < 100 { break }
                page += 1
            } catch {
                await MainActor.run { self.error = "تعذر جلب المستودعات"; isLoading = false }
                return
            }
        } while true
        let finalRepos = allRepos
        await MainActor.run { self.repos = finalRepos; self.isLoading = false }
    }
    
    func fetchWorkflowRuns(owner: String, repo: String) async {
        await MainActor.run { isLoading = true; error = nil }
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs?per_page=50")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                await MainActor.run { error = "المستودع غير موجود"; isLoading = false }
                return
            }
            let result = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
            await MainActor.run { workflowRuns = result.workflow_runs; isLoading = false }
        } catch {
            await MainActor.run { self.error = "تعذر جلب الاكشنز"; isLoading = false }
        }
    }
    
    // ✅ fetchWorkflowJobs — تستخدمها ActionsView
    func fetchWorkflowJobs(owner: String, repo: String, runId: Int) async {
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let result = try JSONDecoder().decode(WorkflowJobsResponse.self, from: data)
            
            // جلب سجلات أول job
            if let firstJob = result.jobs.first {
                let logsReq = makeRequest("/repos/\(owner)/\(repo)/actions/jobs/\(firstJob.id)/logs")
                let (logsData, _) = try await URLSession.shared.data(for: logsReq)
                if let logText = String(data: logsData, encoding: .utf8) {
                    let lines = logText.components(separatedBy: "\n")
                    let logs = lines.enumerated().map { i, line in
                        BuildLog(id: i, lineNumber: i + 1, text: line, timestamp: nil)
                    }
                    await MainActor.run { self.buildLogs = logs }
                }
            }
        } catch {}
    }
    
    func fetchLogs(owner: String, repo: String, runId: Int) async {
        await MainActor.run { isLoading = true; logLines = []; error = nil }
        let jobsReq = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs")
        do {
            let (jobsData, _) = try await URLSession.shared.data(for: jobsReq)
            guard let jobsJson = try? JSONSerialization.jsonObject(with: jobsData) as? [String: Any],
                  let jobs = jobsJson["jobs"] as? [[String: Any]],
                  let firstJob = jobs.first,
                  let jobId = firstJob["id"] as? Int else {
                await MainActor.run { error = "لا توجد مهام"; isLoading = false }
                return
            }
            let logsReq = makeRequest("/repos/\(owner)/\(repo)/actions/jobs/\(jobId)/logs")
            let (logsData, _) = try await URLSession.shared.data(for: logsReq)
            guard let logText = String(data: logsData, encoding: .utf8) else {
                await MainActor.run { error = "تعذر قراءة السجلات"; isLoading = false }
                return
            }
            let lines = logText.components(separatedBy: "\n")
            let logLines = lines.enumerated().map { LogLine(id: $0.offset + 1, text: $0.element) }
            await MainActor.run { self.logLines = logLines; isLoading = false }
        } catch {
            await MainActor.run { self.error = "تعذر جلب السجلات"; isLoading = false }
        }
    }
    
    func fetchJobs(owner: String, repo: String, runId: Int) async -> [WorkflowJob] {
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            return try JSONDecoder().decode(WorkflowJobsResponse.self, from: data).jobs
        } catch { return [] }
    }
    
    func fetchJobLogs(owner: String, repo: String, jobId: Int) async -> [BuildLog] {
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/jobs/\(jobId)/logs")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let logText = String(data: data, encoding: .utf8) else { return [] }
            return logText.components(separatedBy: "\n").enumerated().map { i, line in
                BuildLog(id: i, lineNumber: i + 1, text: line, timestamp: nil)
            }
        } catch { return [] }
    }
    
    // ✅ deleteRepository — تستخدمها ReposView
    func deleteRepository(repo: GitHubRepo) async {
        let req = makeRequest("/repos/\(repo.owner.login)/\(repo.name)", method: "DELETE")
        _ = try? await URLSession.shared.data(for: req)
        await fetchRepos()
    }
    
    // MARK: - رفع الملفات
    func pushFiles(
        owner: String,
        repo: String,
        branch: String,
        message: String,
        files: [FileToPush],
        fileManager: LocalFileManager
    ) async -> Bool {
        await MainActor.run {
            isPushing = true
            pushFileIndex = 0
            pushFileTotal = files.count
            pushProgress = "جارٍ الرفع..."
            lastCommitResult = nil
            error = nil
        }
        
        guard !token.isEmpty else {
            await MainActor.run { error = "التوكن غير موجود"; isPushing = false }
            return false
        }
        guard !files.isEmpty else {
            await MainActor.run { lastCommitResult = "لا توجد ملفات"; isPushing = false }
            return false
        }
        
        var successCount = 0
        var failCount = 0
        var failedFiles: [String] = []
        
        for (index, file) in files.enumerated() {
            await MainActor.run {
                pushFileIndex = index + 1
                pushProgress = "رفع \(index + 1)/\(files.count): \(file.path)"
            }
            
            let filePath = file.path
            let success = await uploadSingleFile(
                owner: owner,
                repo: repo,
                branch: branch,
                message: message + " - " + filePath,
                file: file
            )
            
            if success { successCount += 1 }
            else { failCount += 1; failedFiles.append(filePath) }
        }
        
        let sCount = successCount
        let fCount = failCount
        let fFiles = failedFiles
        
        await MainActor.run {
            isPushing = false
            if fCount == 0 {
                lastCommitResult = "تم رفع \(sCount) ملف بنجاح!"
                fileManager.clearModifications()
            } else if sCount > 0 {
                lastCommitResult = "رفع \(sCount) ملف، فشل \(fCount)"
                fileManager.clearModifications()
            } else {
                lastCommitResult = "فشل رفع جميع الملفات"
            }
            pushProgress = ""
        }
        return successCount > 0
    }
    
    private func uploadSingleFile(
        owner: String,
        repo: String,
        branch: String,
        message: String,
        file: FileToPush
    ) async -> Bool {
        let encodedPath = file.path
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
        
        let existingSHA = await getFileSHA(owner: owner, repo: repo, path: file.path, branch: branch)
        
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)?ref=\(branch)") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "message": message,
            "branch": branch,
            "content": file.content
        ]
        if let sha = existingSHA { body["sha"] = sha }
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200, 201: return true
                case 404: return await handleEmptyRepo(owner: owner, repo: repo, branch: branch, file: file)
                default: return false
                }
            }
        } catch {}
        return false
    }
    
    private func getFileSHA(owner: String, repo: String, path: String, branch: String) async -> String? {
        let encodedPath = path.replacingOccurrences(of: " ", with: "%20")
        let req = makeRequest("/repos/\(owner)/\(repo)/contents/\(encodedPath)?ref=\(branch)")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let content = try JSONDecoder().decode(GitHubContent.self, from: data)
            return content.sha
        } catch { return nil }
    }
    
    private func handleEmptyRepo(owner: String, repo: String, branch: String, file: FileToPush) async -> Bool {
        let encodedPath = file.path.replacingOccurrences(of: " ", with: "%20")
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["message": "Initial commit - " + file.path, "branch": branch, "content": file.content]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) { return true }
        } catch {}
        return false
    }
    
    func getDefaultBranch(owner: String, repo: String) async -> String {
        let req = makeRequest("/repos/\(owner)/\(repo)")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return "main" }
            return try JSONDecoder().decode(Repo.self, from: data).default_branch ?? "main"
        } catch { return "main" }
    }
    
    func reRunWorkflow(owner: String, repo: String, runId: Int) async {
        _ = try? await URLSession.shared.data(for: makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/rerun", method: "POST"))
    }
    
    func cancelWorkflow(owner: String, repo: String, runId: Int) async {
        _ = try? await URLSession.shared.data(for: makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/cancel", method: "POST"))
    }
}
