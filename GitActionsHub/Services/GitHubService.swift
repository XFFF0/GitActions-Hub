import Foundation

// MARK: - Models
struct Repo: Codable, Identifiable {
    let id: Int
    let name: String
    let full_name: String
    let owner: RepoOwner
    let html_url: String
    let description: String?
    let private_field: Bool?
    let default_branch: String?
    let size: Int?
    let language: String?
    let updated_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, full_name, owner, html_url, description, size, language, updated_at
        case private_field = "private"
        case default_branch
    }
    
    var isPrivate: Bool { private_field ?? false }
}

struct RepoOwner: Codable {
    let login: String
    let avatar_url: String?
}

struct WorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let head_branch: String
    let status: String
    let conclusion: String?
    let created_at: String
    let updated_at: String
    let html_url: String
    let head_sha: String?
    let event: String?
    
    var displayStatus: String {
        switch status {
        case "queued": return "⏳ في الانتظار"
        case "in_progress": return "🔄 قيد التنفيذ"
        case "completed": return "✅ مكتمل"
        case "waiting": return "⏸️ بانتظار الموافقة"
        default: return status
        }
    }
    
    var displayConclusion: String {
        switch conclusion {
        case "success": return "✅ نجاح"
        case "failure": return "❌ فشل"
        case "cancelled": return "🚫 ملغى"
        case "skipped": return "⏭️ متخطى"
        case "timed_out": return "⏰ انتهت المهلة"
        case "action_required": return "⚠️ يتطلب إجراء"
        case nil: return ""
        default: return conclusion ?? ""
        }
    }
    
    var isRunning: Bool {
        return status == "in_progress" || status == "queued" || status == "waiting"
    }
}

struct WorkflowRunsResponse: Codable {
    let total_count: Int
    let workflow_runs: [WorkflowRun]
}

struct LogLine: Identifiable {
    let id: Int
    let text: String
    var isError: Bool { text.contains("error:") || text.contains("Error:") || text.contains("ERROR:") }
    var isWarning: Bool { text.contains("warning:") || text.contains("Warning:") || text.contains("WARN:") }
    var isCommand: Bool { text.hasPrefix("$") || text.hasPrefix("+ ") }
}

struct GitHubContent: Codable {
    let name: String
    let path: String
    let sha: String?
    let `type`: String
    let content: String?
    let encoding: String?
    let size: Int?
}

// MARK: - GitHub Service
class GitHubService: ObservableObject {
    
    @Published var repos: [Repo] = []
    @Published var workflowRuns: [WorkflowRun] = []
    @Published var logLines: [LogLine] = []
    @Published var error: String?
    @Published var isLoading = false
    @Published var lastCommitResult: String?
    
    // ✅ حالة الرفع
    @Published var isPushing = false
    @Published var pushProgress: String = ""
    @Published var pushFileIndex: Int = 0
    @Published var pushFileTotal: Int = 0
    
    private let baseURL = "https://api.github.com"
    
    var token: String {
        UserDefaults.standard.string(forKey: "gh_access_token") ?? ""
    }
    
    var isAuthenticated: Bool {
        !token.isEmpty
    }
    
    var username: String {
        UserDefaults.standard.string(forKey: "gh_username") ?? ""
    }
    
    // MARK: - Token Validation
    func validateToken(_ token: String) async -> Bool {
        var req = URLRequest(url: URL(string: "\(baseURL)/user")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // حفظ اسم المستخدم
                var req2 = URLRequest(url: URL(string: "\(baseURL)/user")!)
                req2.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req2.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: req2)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let login = json["login"] as? String {
                    UserDefaults.standard.set(login, forKey: "gh_username")
                }
                return true
            }
        } catch {}
        return false
    }
    
    // MARK: - Generic Request Helper
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
    
    // MARK: - Fetch Repos
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
                    await MainActor.run { error = "❌ التوكن غير صالح — سجّل الدخول مجدداً"; isLoading = false }
                    return
                }
                
                let repos = try JSONDecoder().decode([Repo].self, from: data)
                allRepos.append(contentsOf: repos)
                
                // التحقق من وجود صفحة تالية
                if repos.count < 100 { break }
                page += 1
            } catch {
                await MainActor.run { self.error = "تعذّر جلب المستودعات: \(error.localizedDescription)"; isLoading = false }
                return
            }
        } while true
        
        await MainActor.run { repos = allRepos; isLoading = false }
    }
    
    // MARK: - Fetch Workflow Runs
    func fetchWorkflowRuns(owner: String, repo: String) async {
        await MainActor.run { isLoading = true; error = nil }
        
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs?per_page=50")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                await MainActor.run { error = "❌ المستودع غير موجود أو ليس لديك صلاحية"; isLoading = false }
                return
            }
            
            let result = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
            await MainActor.run { workflowRuns = result.workflow_runs; isLoading = false }
        } catch {
            await MainActor.run { self.error = "تعذّر جلب الأكشنز: \(error.localizedDescription)"; isLoading = false }
        }
    }
    
    // MARK: - Fetch Build Logs
    func fetchLogs(owner: String, repo: String, runId: Int) async {
        await MainActor.run { isLoading = true; logLines = []; error = nil }
        
        // 1. جلب Jobs
        let jobsReq = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs")
        do {
            let (jobsData, _) = try await URLSession.shared.data(for: jobsReq)
            guard let jobsJson = try? JSONSerialization.jsonObject(with: jobsData) as? [String: Any],
                  let jobs = jobsJson["jobs"] as? [[String: Any]],
                  let firstJob = jobs.first else {
                await MainActor.run { error = "❌ لا توجد مهام"; isLoading = false }
                return
            }
            
            guard let logsUrlString = firstJob["url"] as? String else {
                await MainActor.run { error = "❌ لا يوجد رابط للسجلات"; isLoading = false }
                return
            }
            
            // 2. جلب Logs
            let logsReq = makeRequest("/repos/\(owner)/\(repo)/actions/jobs/\(firstJob["id"] ?? 0)/logs")
            let (logsData, _) = try await URLSession.shared.data(for: logsReq)
            
            guard let logText = String(data: logsData, encoding: .utf8) else {
                await MainActor.run { error = "❌ تعذّر قراءة السجلات"; isLoading = false }
                return
            }
            
            let lines = logText.components(separatedBy: "\n")
            let logLines = lines.enumerated().map { index, line in
                LogLine(id: index + 1, text: line)
            }
            
            await MainActor.run { self.logLines = logLines; isLoading = false }
            
        } catch {
            await MainActor.run { self.error = "تعذّر جلب السجلات: \(error.localizedDescription)"; isLoading = false }
        }
    }
    
    // MARK: - ✅ رفع الملفات — Contents API (الطريقة الأساسية)
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
            await MainActor.run {
                error = "❌ لم يتم العثور على التوكن"
                isPushing = false
            }
            return false
        }
        
        guard !files.isEmpty else {
            await MainActor.run {
                lastCommitResult = "⚠️ لا توجد ملفات للرفع"
                isPushing = false
            }
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
            
            let success = await uploadSingleFile(
                owner: owner,
                repo: repo,
                branch: branch,
                message: "\(message) — \(file.path)",
                file: file
            )
            
            if success {
                successCount += 1
            } else {
                failCount += 1
                failedFiles.append(file.path)
            }
        }
        
        await MainActor.run {
            isPushing = false
            
            if failCount == 0 {
                lastCommitResult = "✅ تم رفع \(successCount) ملف بنجاح!"
                fileManager.clearModifications()
            } else if successCount > 0 {
                lastCommitResult = "⚠️ تم رفع \(successCount) ملف، فشل \(failCount)"
                error = "الملفات التي فشلت: \(failedFiles.joined(separator: ", "))"
                fileManager.clearModifications()
            } else {
                lastCommitResult = "❌ فشل رفع جميع الملفات"
                error = "فشل رفع: \(failedFiles.joined(separator: ", "))"
            }
            
            pushProgress = ""
        }
        
        return successCount > 0
    }
    
    // MARK: - ✅ رفع ملف واحد — Contents API
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
        
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)?ref=\(branch)"
        
        // ✅ الخطوة 1: التحقق من وجود الملف مسبقاً
        let existingSHA = await getFileSHA(owner: owner, repo: repo, path: file.path, branch: branch)
        
        // ✅ الخطوة 2: رفع أو تحديث الملف
        guard let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "message": message,
            "branch": branch,
            "content": file.content // Base64 للثنائية، نص عادي للنصية
        ]
        
        // ✅ إذا الملف موجود، أضف SHA للتحديث
        if let sha = existingSHA {
            body["sha"] = sha
        }
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: req)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200, 201:
                    return true
                case 409:
                    // تعارض — الريبو تم تحديثه
                    await MainActor.run { error = "❌ تعارض — تم تحديث المستودع. حاول مجدداً." }
                    return false
                case 403:
                    await MainActor.run { error = "❌ ليس لديك صلاحية الكتابة على هذا المستودع" }
                    return false
                case 404:
                    // ✅ المستودع قد يكون فارغ — نحاول إنشاء ملف أولي
                    return await handleEmptyRepo(owner: owner, repo: repo, branch: branch, file: file)
                case 422:
                    // خطأ في البيانات — ربما محتوى Base64 غير صالح
                    await MainActor.run { error = "❌ خطأ في بيانات الملف: \(file.path)" }
                    return false
                case 413:
                    await MainActor.run { error = "❌ الملف太大 حجمه: \(file.path)" }
                    return false
                default:
                    return false
                }
            }
        } catch {
            return false
        }
        
        return false
    }
    
    // MARK: - ✅ الحصول على SHA لملف موجود
    private func getFileSHA(owner: String, repo: String, path: String, branch: String) async -> String? {
        let encodedPath = path
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
        
        let req = makeRequest("/repos/\(owner)/\(repo)/contents/\(encodedPath)?ref=\(branch)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            
            let content = try JSONDecoder().decode(GitHubContent.self, from: data)
            return content.sha
        } catch {
            return nil
        }
    }
    
    // MARK: - ✅ معالجة المستودع الفارغ
    private func handleEmptyRepo(
        owner: String,
        repo: String,
        branch: String,
        file: FileToPush
    ) async -> Bool {
        // محاولة إنشاء الملف مباشرة بدون SHA
        let encodedPath = file.path
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
        
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "message": "Initial commit — \(file.path)",
            "branch": branch,
            "content": file.content
        ]
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: req)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                return true
            }
        } catch {}
        
        return false
    }
    
    // MARK: - ✅ الحصول على الفرع الافتراضي
    func getDefaultBranch(owner: String, repo: String) async -> String {
        let req = makeRequest("/repos/\(owner)/\(repo)")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return "main" }
            
            let repo = try JSONDecoder().decode(Repo.self, from: data)
            return repo.default_branch ?? "main"
        } catch {
            return "main"
        }
    }
    
    // MARK: - Re-run Workflow
    func reRunWorkflow(owner: String, repo: String, runId: Int) async {
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/rerun", method: "POST")
        _ = try? await URLSession.shared.data(for: req)
    }
    
    // MARK: - Cancel Workflow
    func cancelWorkflow(owner: String, repo: String, runId: Int) async {
        let req = makeRequest("/repos/\(owner)/\(repo)/actions/runs/\(runId)/cancel", method: "POST")
        _ = try? await URLSession.shared.data(for: req)
    }
    
    // MARK: - ✅ الحصول على ملفات الريبو البعيدة (لمقارنة التغييرات)
    func fetchRemoteFiles(owner: String, repo: String, path: String = "", branch: String = "main") async -> [GitHubContent] {
        let encodedPath = path.isEmpty ? "" : "/\(path)"
        let req = makeRequest("/repos/\(owner)/\(repo)/contents\(encodedPath)?ref=\(branch)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }
            
            return try JSONDecoder().decode([GitHubContent].self, from: data)
        } catch {
            return []
        }
    }
}
