import Foundation
import SwiftUI

class GitHubService: ObservableObject {
    @Published var currentUser: GitHubUser?
    @Published var repositories: [GitHubRepo] = []
    @Published var workflowRuns: [WorkflowRun] = []
    @Published var workflowJobs: [WorkflowJob] = []
    @Published var buildLogs: [BuildLog] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isAuthenticated = false
    
    private var accessToken: String?
    private let baseURL = "https://api.github.com"
    
    func authenticateWithOAuth(token: String) async {
        await MainActor.run { isLoading = true }
        accessToken = token
        UserDefaults.standard.set(token, forKey: "gh_access_token")
        do {
            let user = try await fetchUser()
            await MainActor.run { self.currentUser = user; self.isAuthenticated = true; self.isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false; self.isAuthenticated = false }
        }
    }
    
    func loadSavedToken() {
        if let token = UserDefaults.standard.string(forKey: "gh_access_token") {
            accessToken = token
            Task { await authenticateWithOAuth(token: token) }
        }
    }
    
    func logout() {
        accessToken = nil
        UserDefaults.standard.removeObject(forKey: "gh_access_token")
        currentUser = nil; repositories = []; workflowRuns = []; isAuthenticated = false
    }
    
    func makeRequest<T: Decodable>(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let token = accessToken else { throw GitHubError.notAuthenticated }
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { throw GitHubError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
        if httpResponse.statusCode == 401 { throw GitHubError.unauthorized }
        if httpResponse.statusCode >= 400 { throw GitHubError.serverError(httpResponse.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fetchUser() async throws -> GitHubUser { try await makeRequest(endpoint: "/user") }
    
    func fetchRepositories() async {
        await MainActor.run { isLoading = true }
        do {
            let repos: [GitHubRepo] = try await makeRequest(endpoint: "/user/repos?sort=updated&per_page=100")
            await MainActor.run { self.repositories = repos; self.isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
        }
    }
    
    func deleteRepository(repo: GitHubRepo) async {
        guard let user = currentUser else { return }
        do {
            guard let token = accessToken,
                  let url = URL(string: "\(baseURL)/repos/\(user.login)/\(repo.name)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
                await MainActor.run {
                    self.repositories.removeAll { $0.id == repo.id }
                }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    func fetchWorkflowRuns(owner: String, repo: String) async {
        await MainActor.run { isLoading = true }
        do {
            struct WorkflowRunsResponse: Codable {
                let workflowRuns: [WorkflowRun]
                enum CodingKeys: String, CodingKey { case workflowRuns = "workflow_runs" }
            }
            let response: WorkflowRunsResponse = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/actions/runs?per_page=20")
            await MainActor.run { self.workflowRuns = response.workflowRuns; self.isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
        }
    }
    
    func fetchWorkflowJobs(owner: String, repo: String, runId: Int) async {
        do {
            struct JobsResponse: Codable { let jobs: [WorkflowJob] }
            let response: JobsResponse = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs")
            await MainActor.run { self.workflowJobs = response.jobs }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    func fetchBuildLogs(owner: String, repo: String, jobId: Int) async {
        do {
            guard let token = accessToken,
                  let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/actions/jobs/\(jobId)/logs") else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
            let rawLog = String(data: data, encoding: .utf8) ?? ""
            let parsedLogs = parseLogLines(rawLog)
            await MainActor.run { self.buildLogs = parsedLogs }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    func triggerWorkflow(owner: String, repo: String, workflowId: String, branch: String) async -> Bool {
        do {
            let body = ["ref": branch]
            let bodyData = try JSONEncoder().encode(body)
            let _: EmptyResponse = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/actions/workflows/\(workflowId)/dispatches", method: "POST", body: bodyData)
            return true
        } catch { await MainActor.run { self.error = error.localizedDescription }; return false }
    }
    
    func reRunWorkflow(owner: String, repo: String, runId: Int) async -> Bool {
        do {
            let _: EmptyResponse = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/actions/runs/\(runId)/rerun", method: "POST")
            return true
        } catch { await MainActor.run { self.error = error.localizedDescription }; return false }
    }
    
    func cancelWorkflow(owner: String, repo: String, runId: Int) async -> Bool {
        do {
            let _: EmptyResponse = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/actions/runs/\(runId)/cancel", method: "POST")
            return true
        } catch { await MainActor.run { self.error = error.localizedDescription }; return false }
    }
    
    private func parseLogLines(_ raw: String) -> [BuildLog] {
        let lines = raw.components(separatedBy: "\n")
        return lines.enumerated().map { index, line in
            let cleanLine = cleanLogLine(line)
            return BuildLog(lineNumber: index + 1, content: cleanLine, type: detectLineType(cleanLine))
        }.filter { !$0.content.isEmpty }
    }
    
    private func cleanLogLine(_ line: String) -> String {
        var clean = line
        if clean.count > 29, let range = clean.range(of: #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z "#, options: .regularExpression) {
            clean.removeSubrange(range)
        }
        clean = clean.replacingOccurrences(of: #"\x1B\[[0-9;]*[mGKH]"#, with: "", options: .regularExpression)
        return clean
    }
    
    private func detectLineType(_ line: String) -> BuildLog.LogLineType {
        let lower = line.lowercased()
        if lower.contains("error:") || lower.contains("failed") || lower.contains("failure") { return .error }
        if lower.contains("warning:") || lower.contains("warn:") { return .warning }
        if lower.contains("success") || lower.contains("passed") { return .success }
        if line.hasPrefix("$") || line.hasPrefix(">") || lower.contains("run:") { return .command }
        if lower.contains("##[") || lower.contains("::notice") { return .info }
        return .normal
    }
    
    // MARK: - Fetch repo using Git Trees API (recursive, reliable)
    func fetchRepoTree(owner: String, repo: String, branch: String = "main") async throws -> [RepoFile] {
        let textExts: Set<String> = ["swift","m","h","mm","c","cpp","txt","md","json","xml","plist","yaml","yml","sh","js","ts","html","css","py","rb","go","gitignore","gitkeep","entitlements","strings","xcconfig","gradle","kt","java","toml","ini","podspec","lock","pbxproj"]

        // 1. Get branch commit SHA
        struct RefResp: Codable { struct Obj: Codable { let sha: String }; let object: Obj }
        let refData: RefResp = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/git/refs/heads/\(branch)")
        let commitSHA = refData.object.sha

        // 2. Get recursive file tree
        struct TreeItem: Codable { let path: String?; let type: String?; let sha: String?; let size: Int? }
        struct TreeResp: Codable { let tree: [TreeItem]; let truncated: Bool? }
        let treeResp: TreeResp = try await makeRequest(endpoint: "/repos/\(owner)/\(repo)/git/trees/\(commitSHA)?recursive=1")

        // 3. Filter to text files under 200KB
        let fileItems = treeResp.tree.filter { item in
            guard item.type == "blob", let p = item.path else { return false }
            let ext = (p as NSString).pathExtension.lowercased()
            let isDot = (p as NSString).lastPathComponent.hasPrefix(".")
            return (textExts.contains(ext) || (isDot && ext.isEmpty)) && (item.size ?? 0) < 200_000
        }

        // 4. Fetch content in parallel batches of 8
        var results: [RepoFile] = []
        for batchStart in stride(from: 0, to: fileItems.count, by: 8) {
            let batch = Array(fileItems[batchStart..<min(batchStart + 8, fileItems.count)])
            var batchRes: [RepoFile] = []
            try await withThrowingTaskGroup(of: RepoFile?.self) { group in
                for item in batch {
                    guard let path = item.path, let sha = item.sha else { continue }
                    group.addTask {
                        struct BlobR: Codable { let content: String? }
                        let blob: BlobR = try await self.makeRequest(endpoint: "/repos/\(owner)/\(repo)/git/blobs/\(sha)")
                        guard let b64 = blob.content else { return nil }
                        let clean = b64.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
                        guard let data = Data(base64Encoded: clean), let text = String(data: data, encoding: .utf8) else { return nil }
                        return RepoFile(name: (path as NSString).lastPathComponent, path: path, content: text, size: item.size ?? 0)
                    }
                }
                for try await r in group { if let r { batchRes.append(r) } }
            }
            results.append(contentsOf: batchRes)
        }
        return results.sorted { $0.path < $1.path }
    }
}

struct RepoFile: Identifiable {
    let id = UUID()
    var name: String
    var path: String
    var content: String
    var size: Int
}

struct EmptyResponse: Codable {}

enum GitHubError: LocalizedError {
    case notAuthenticated, invalidURL, invalidResponse, unauthorized, serverError(Int)
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated"
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Invalid or expired token"
        case .serverError(let code): return "Server error: \(code)"
        }
    }
}
