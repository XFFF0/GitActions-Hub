import Foundation
import SwiftUI
import UniformTypeIdentifiers

class LocalFileManager: ObservableObject {
    @Published var rootFiles: [GitFile] = []
    @Published var currentPath: URL
    @Published var selectedFile: GitFile?
    @Published var fileContent: String = ""
    @Published var isLoading = false
    @Published var error: String?

    private let fm = FileManager.default

    // Safe text extensions only
    private static let safeTextExtensions: Set<String> = [
        "swift", "m", "h", "mm", "c", "cpp",
        "txt", "md", "json", "xml", "plist",
        "yaml", "yml", "sh", "js", "ts",
        "html", "css", "py", "rb", "go",
        "entitlements", "strings", "xcconfig",
        "gradle", "kt", "java", "toml", "ini",
        "gitignore", "gitkeep", "podspec", "lock"
    ]

    static var appDocumentsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let projects = docs.appendingPathComponent("Projects", isDirectory: true)
        if !FileManager.default.fileExists(atPath: projects.path) {
            try? FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        }
        return projects
    }

    init() {
        currentPath = LocalFileManager.appDocumentsURL
        createWelcomeFileIfNeeded()
        loadFiles(at: currentPath)
    }

    private func createWelcomeFileIfNeeded() {
        let path = currentPath.appendingPathComponent("README.txt")
        guard !fm.fileExists(atPath: path.path) else { return }
        let txt = "GitActions Hub\n==============\nضع ملفات مشاريعك هنا.\nFiles > On My iPhone > GitActionsHub > Projects"
        try? txt.write(to: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Load

    func loadFiles(at url: URL) {
        isLoading = true
        currentPath = url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let files = self.buildTree(at: url)
            DispatchQueue.main.async {
                self.rootFiles = files
                self.isLoading = false
            }
        }
    }

    private func buildTree(at url: URL) -> [GitFile] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { fileURL -> GitFile? in
            let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            let isDir = res?.isDirectory ?? false
            var file = GitFile(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDirectory: isDir,
                size: Int64(res?.fileSize ?? 0),
                modifiedDate: res?.contentModificationDate ?? Date()
            )
            if isDir {
                file.children = buildTree(at: fileURL)
            }
            return file
        }.sorted { a, b in
            a.isDirectory != b.isDirectory ? a.isDirectory : a.name < b.name
        }
    }

    // MARK: - Read single file

    func readFile(_ file: GitFile) {
        guard !file.isDirectory else { return }
        let url = URL(fileURLWithPath: file.path)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            // Try UTF-8 first, then latin1
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                DispatchQueue.main.async { self.fileContent = content; self.selectedFile = file }
            } else if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
                DispatchQueue.main.async { self.fileContent = content; self.selectedFile = file }
            } else {
                DispatchQueue.main.async { self.error = "لا يمكن فتح ملف ثنائي" }
            }
        }
    }

    // MARK: - Collect ALL text files for Push (recursive, safe)

    func collectAllFiles(from files: [GitFile], basePath: String = "") -> [(path: String, content: String)] {
        var result: [(path: String, content: String)] = []

        for file in files {
            let relPath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"

            if file.isDirectory {
                // Skip .xcodeproj directories entirely
                if file.name.hasSuffix(".xcodeproj") || file.name.hasSuffix(".xcworkspace") {
                    continue
                }
                let children = file.children ?? buildTree(at: URL(fileURLWithPath: file.path))
                result.append(contentsOf: collectAllFiles(from: children, basePath: relPath))

            } else {
                // Only push safe text files under 500KB
                guard file.size < 500_000 else { continue }

                let ext = (file.name as NSString).pathExtension.lowercased()
                let isDotFile = file.name.hasPrefix(".") // .gitkeep, .gitignore etc
                let isSafe = LocalFileManager.safeTextExtensions.contains(ext) || (isDotFile && ext.isEmpty)
                guard isSafe else { continue }

                let url = URL(fileURLWithPath: file.path)
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    result.append((path: relPath, content: content))
                } else if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
                    result.append((path: relPath, content: content))
                }
                // Binary or unreadable → skip silently
            }
        }
        return result
    }

    // MARK: - Write

    func writeFile(_ file: GitFile, content: String) {
        let url = URL(fileURLWithPath: file.path)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر الحفظ: \(error.localizedDescription)"
        }
    }

    // MARK: - Create / Delete / Rename

    func createFile(name: String, at parentPath: String, isDirectory: Bool = false) {
        let url = URL(fileURLWithPath: "\(parentPath)/\(name)")
        do {
            if isDirectory {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                // Add .gitkeep so empty folders can be pushed
                let gitkeep = url.appendingPathComponent(".gitkeep")
                fm.createFile(atPath: gitkeep.path, contents: Data())
            } else {
                fm.createFile(atPath: url.path, contents: Data())
            }
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر الإنشاء: \(error.localizedDescription)"
        }
    }

    func deleteFile(_ file: GitFile) {
        do {
            try fm.removeItem(at: URL(fileURLWithPath: file.path))
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر الحذف: \(error.localizedDescription)"
        }
    }

    func renameFile(_ file: GitFile, newName: String) {
        let old = URL(fileURLWithPath: file.path)
        let new = old.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fm.moveItem(at: old, to: new)
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر إعادة التسمية: \(error.localizedDescription)"
        }
    }

    func moveFile(_ file: GitFile, direction: MoveDirection) {
        guard let i = rootFiles.firstIndex(where: { $0.id == file.id }) else { return }
        let j = direction == .up ? i - 1 : i + 1
        guard j >= 0 && j < rootFiles.count else { return }
        rootFiles.swapAt(i, j)
    }

    // MARK: - Import from Files app

    func importFromFiles(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let dest = currentPath.appendingPathComponent(url.lastPathComponent)
        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: url, to: dest)
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر الاستيراد: \(error.localizedDescription)"
        }
    }

    // MARK: - Navigation

    func navigateUp() {
        let parent = currentPath.deletingLastPathComponent()
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        if currentPath.path != docs.path { loadFiles(at: parent) }
    }

    var isAtRoot: Bool { currentPath == LocalFileManager.appDocumentsURL }

    var currentPathDisplay: String {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!.path
        return currentPath.path.replacingOccurrences(of: docs, with: "iPhone")
    }
}

enum MoveDirection { case up, down }

// MARK: - Git Operations

class GitOperationsManager: ObservableObject {
    @Published var commitHistory: [CommitInfo] = []
    @Published var isLoading = false
    @Published var lastCommitResult: String?

    private let svc: GitHubService
    init(gitHubService: GitHubService) { self.svc = gitHubService }

    func commitAndPush(
        owner: String, repo: String, branch: String,
        message: String, files: [(path: String, content: String)]
    ) async -> Bool {
        await MainActor.run { isLoading = true }

        guard !files.isEmpty else {
            await MainActor.run { lastCommitResult = "❌ لا توجد ملفات نصية للرفع"; isLoading = false }
            return false
        }

        guard let token = UserDefaults.standard.string(forKey: "gh_access_token"),
              let base = URL(string: "https://api.github.com") else {
            await MainActor.run { lastCommitResult = "❌ تحقق من التوكن"; isLoading = false }
            return false
        }

        func req(_ endpoint: String, method: String = "GET", body: Data? = nil) -> URLRequest {
            var r = URLRequest(url: base.appendingPathComponent(endpoint))
            r.httpMethod = method
            r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = body
            return r
        }

        do {
            // 1. Get current SHA
            struct RefR: Codable { struct O: Codable { let sha: String }; let object: O }
            let (rd, _) = try await URLSession.shared.data(for: req("/repos/\(owner)/\(repo)/git/refs/heads/\(branch)"))
            let sha = try JSONDecoder().decode(RefR.self, from: rd).object.sha

            // 2. Blobs
            struct BlobR: Codable { let sha: String }
            var tree: [[String: String]] = []
            for f in files {
                let bd = try JSONEncoder().encode(["content": f.content, "encoding": "utf-8"])
                let (blobData, _) = try await URLSession.shared.data(for: req("/repos/\(owner)/\(repo)/git/blobs", method: "POST", body: bd))
                let bSHA = try JSONDecoder().decode(BlobR.self, from: blobData).sha
                tree.append(["path": f.path, "mode": "100644", "type": "blob", "sha": bSHA])
            }

            // 3. Tree
            struct TreeR: Codable { let sha: String }
            let td = try JSONSerialization.data(withJSONObject: ["base_tree": sha, "tree": tree])
            let (treeData, _) = try await URLSession.shared.data(for: req("/repos/\(owner)/\(repo)/git/trees", method: "POST", body: td))
            let tSHA = try JSONDecoder().decode(TreeR.self, from: treeData).sha

            // 4. Commit
            struct CommR: Codable { let sha: String }
            let cd = try JSONSerialization.data(withJSONObject: ["message": message, "tree": tSHA, "parents": [sha]])
            let (commitData, _) = try await URLSession.shared.data(for: req("/repos/\(owner)/\(repo)/git/commits", method: "POST", body: cd))
            let cSHA = try JSONDecoder().decode(CommR.self, from: commitData).sha

            // 5. Update ref
            let ud = try JSONSerialization.data(withJSONObject: ["sha": cSHA, "force": false])
            _ = try await URLSession.shared.data(for: req("/repos/\(owner)/\(repo)/git/refs/heads/\(branch)", method: "PATCH", body: ud))

            await MainActor.run {
                commitHistory.insert(CommitInfo(message: message, files: files.map { $0.path }, branch: branch, timestamp: Date(), sha: String(cSHA.prefix(7))), at: 0)
                lastCommitResult = "✅ Push ناجح!\nSHA: \(String(cSHA.prefix(7))) · \(files.count) ملف"
                isLoading = false
            }
            return true

        } catch {
            await MainActor.run {
                lastCommitResult = "❌ \(error.localizedDescription)"
                isLoading = false
            }
            return false
        }
    }
}
