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
    
    private func makeRequest<T: Decodable>(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
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
    
    func fetchRepoTree(owner: String, repo: String, branch: String = "main") async throws -> [RepoFile] {
        struct ContentsResponse: Codable {
            let type: String
            let name: String
            let path: String
            let content: String?
            let sha: String?
            let size: Int?
            enum CodingKeys: String, CodingKey {
                case type, name, path, content, sha, size
            }
        }
        
        var allFiles: [RepoFile] = []
        
        func fetchContents(path: String) async throws {
            let endpoint = "/repos/\(owner)/\(repo)/contents/\(path)?ref=\(branch)"
            let contents: [ContentsResponse] = try await makeRequest(endpoint: endpoint)
            
            for item in contents {
                if item.type == "dir" {
                    try await fetchContents(path: item.path)
                } else if item.type == "file", let contentB64 = item.content {
                    let cleanContent = contentB64
                        .replacingOccurrences(of: "\n", with: "")
                        .replacingOccurrences(of: "\r", with: "")
                    if let data = Data(base64Encoded: cleanContent),
                       let decoded = String(data: data, encoding: .utf8) {
                        allFiles.append(RepoFile(
                            name: item.name,
                            path: item.path,
                            content: decoded,
                            size: item.size ?? 0
                        ))
                    }
                }
            }
        }
        
        try await fetchContents(path: "")
        return allFiles
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
