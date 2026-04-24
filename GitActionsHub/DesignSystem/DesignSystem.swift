import Foundation
import SwiftUI

// MARK: - GitHub Models

struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let avatarUrl: String
    let publicRepos: Int
    let followers: Int
    let following: Int
    
    enum CodingKeys: String, CodingKey {
        case id, login, name
        case avatarUrl = "avatar_url"
        case publicRepos = "public_repos"
        case followers, following
    }
}

struct GitHubRepo: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let isPrivate: Bool
    let htmlUrl: String
    let cloneUrl: String
    let defaultBranch: String
    let updatedAt: String
    let language: String?
    let stargazersCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, language
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
        case defaultBranch = "default_branch"
        case updatedAt = "updated_at"
        case stargazersCount = "stargazers_count"
    }
}

struct WorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String?
    let status: String
    let conclusion: String?
    let createdAt: String
    let updatedAt: String
    let htmlUrl: String
    let headBranch: String
    let headSha: String
    let runNumber: Int
    let event: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, event
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case runNumber = "run_number"
    }
    
    var statusColor: Color {
        switch status {
        case "completed":
            switch conclusion {
            case "success": return .green
            case "failure": return .red
            case "cancelled": return .orange
            default: return .gray
            }
        case "in_progress": return .blue
        case "queued": return .yellow
        default: return .gray
        }
    }
    
    var statusIcon: String {
        switch status {
        case "completed":
            switch conclusion {
            case "success": return "checkmark.circle.fill"
            case "failure": return "xmark.circle.fill"
            case "cancelled": return "minus.circle.fill"
            default: return "circle.fill"
            }
        case "in_progress": return "arrow.triangle.2.circlepath.circle.fill"
        case "queued": return "clock.circle.fill"
        default: return "circle.fill"
        }
    }
}

struct WorkflowJob: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let startedAt: String?
    let completedAt: String?
    let steps: [WorkflowStep]
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, steps
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct WorkflowStep: Codable, Identifiable {
    let name: String
    let status: String
    let conclusion: String?
    let number: Int
    
    var id: Int { number }
    
    enum CodingKeys: String, CodingKey {
        case name, status, conclusion, number
    }
}

struct BuildLog: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let content: String
    let type: LogLineType
    
    enum LogLineType {
        case normal, error, warning, success, info, command
        
        var color: Color {
            switch self {
            case .normal: return Color(hex: "#E8E8E8")
            case .error: return Color(hex: "#FF6B6B")
            case .warning: return Color(hex: "#FFD93D")
            case .success: return Color(hex: "#6BCB77")
            case .info: return Color(hex: "#4D96FF")
            case .command: return Color(hex: "#C77DFF")
            }
        }
        
        var icon: String? {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .command: return "chevron.right"
            default: return nil
            }
        }
    }
}

struct GitFile: Identifiable {
    let id = UUID()
    var name: String
    var path: String
    var isDirectory: Bool
    var size: Int64
    var modifiedDate: Date
    var content: String?
    var children: [GitFile]?
    var isExpanded: Bool = false
    
    var icon: String {
        if isDirectory { return "folder.fill" }
        switch (name as NSString).pathExtension.lowercased() {
        case "swift": return "swift"
        case "json": return "doc.text.fill"
        case "md": return "doc.richtext.fill"
        case "yml", "yaml": return "gearshape.fill"
        case "png", "jpg", "jpeg": return "photo.fill"
        case "sh": return "terminal.fill"
        default: return "doc.fill"
        }
    }
    
    var iconColor: Color {
        if isDirectory { return Color(hex: "#FFD93D") }
        switch (name as NSString).pathExtension.lowercased() {
        case "swift": return Color(hex: "#F05138")
        case "json": return Color(hex: "#4D96FF")
        case "md": return Color(hex: "#6BCB77")
        case "yml", "yaml": return Color(hex: "#C77DFF")
        case "png", "jpg", "jpeg": return Color(hex: "#FF6B6B")
        case "sh": return Color(hex: "#6BCB77")
        default: return Color(hex: "#9E9E9E")
        }
    }
}

struct CommitInfo: Identifiable {
    let id = UUID()
    var message: String
    var files: [String]
    var branch: String
    var timestamp: Date
    var sha: String?
    var authorName: String?
    var authorEmail: String?
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }
}
