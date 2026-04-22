import SwiftUI

// MARK: - GitFile
struct GitFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let isTextFile: Bool
    let isBinaryFile: Bool
    let content: String?
}

// MARK: - FileToPush
struct FileToPush: Identifiable {
    let id = UUID()
    let path: String
    let content: String
    let isBinary: Bool
    let size: Int64
}

// MARK: - GitHubRepo (الاسم الأصلي المستخدم في Views)
typealias GitHubRepo = Repo

// MARK: - Repo
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
    let fork: Bool?
    let stargazers_count: Int?
    let forks_count: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, full_name, owner, html_url, description, size, language, updated_at
        case private_field = "private"
        case default_branch, fork, stargazers_count, forks_count
    }
    
    var isPrivate: Bool { private_field ?? false }
}

// MARK: - RepoOwner
struct RepoOwner: Codable {
    let login: String
    let avatar_url: String?
    let id: Int?
}

// MARK: - GitHubUser
struct GitHubUser: Codable {
    let login: String
    let id: Int
    let avatar_url: String?
    let name: String?
    let bio: String?
    let public_repos: Int?
    let followers: Int?
    let following: Int?
    let html_url: String?
}

// MARK: - WorkflowRun
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
    
    // ✅ الخاصية المفقودة التي تستخدمها ActionsView
    var statusColor: Color {
        switch status {
        case "completed":
            return conclusion == "success" ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B")
        case "in_progress": return Color(hex: "#6C63FF")
        case "queued": return Color(hex: "#FFD93D")
        case "waiting": return Color(hex: "#FFD93D")
        default: return Color(hex: "#8888A0")
        }
    }
}

// MARK: - WorkflowRunsResponse
struct WorkflowRunsResponse: Codable {
    let total_count: Int
    let workflow_runs: [WorkflowRun]
}

// MARK: - WorkflowJob
struct WorkflowJob: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let started_at: String?
    let completed_at: String?
    let steps: [WorkflowStep]?
    
    var displayStatus: String {
        switch status {
        case "queued": return "⏳"
        case "in_progress": return "🔄"
        case "completed": return conclusion == "success" ? "✅" : "❌"
        default: return "•"
        }
    }
}

// MARK: - WorkflowStep
struct WorkflowStep: Codable, Identifiable {
    let number: Int
    let name: String
    let status: String
    let conclusion: String?
    let started_at: String?
    let completed_at: String?
    
    var id: Int { number }
    
    var displayConclusion: String {
        switch conclusion {
        case "success": return "✅"
        case "failure": return "❌"
        case "skipped": return "⏭️"
        case "cancelled": return "🚫"
        default: return "•"
        }
    }
}

// MARK: - Jobs Response
struct WorkflowJobsResponse: Codable {
    let total_count: Int
    let jobs: [WorkflowJob]
}

// MARK: - BuildLog
struct BuildLog: Identifiable {
    let id: Int
    let lineNumber: Int
    let text: String
    let timestamp: String?
    
    enum LogLineType {
        case error
        case warning
        case command
        case normal
    }
    
    var lineType: LogLineType {
        if text.contains("error:") || text.contains("Error:") || text.contains("ERROR:") { return .error }
        if text.contains("warning:") || text.contains("Warning:") || text.contains("WARN:") { return .warning }
        if text.hasPrefix("$") || text.hasPrefix("+ ") { return .command }
        return .normal
    }
}

// MARK: - GitHubContent
struct GitHubContent: Codable {
    let name: String
    let path: String
    let sha: String?
    let type: String
    let content: String?
    let encoding: String?
    let size: Int?
}

// MARK: - LogLine (للسجلات المبسطة)
struct LogLine: Identifiable {
    let id: Int
    let text: String
    var isError: Bool { text.contains("error:") || text.contains("Error:") || text.contains("ERROR:") }
    var isWarning: Bool { text.contains("warning:") || text.contains("Warning:") || text.contains("WARN:") }
    var isCommand: Bool { text.hasPrefix("$") || text.hasPrefix("+ ") }
}
