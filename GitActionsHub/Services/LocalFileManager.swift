import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Local File Manager

class LocalFileManager: ObservableObject {
    @Published var rootFiles: [GitFile] = []
    @Published var currentPath: URL
    @Published var selectedFile: GitFile?
    @Published var fileContent: String = ""
    @Published var isLoading = false
    @Published var error: String?
    
    private let fm = FileManager.default
    
    // Fix 4: Create and use app's Documents directory (visible in Files app)
    static var appDocumentsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // Create a "Projects" subfolder so user can find it easily
        let projects = docs.appendingPathComponent("Projects", isDirectory: true)
        if !FileManager.default.fileExists(atPath: projects.path) {
            try? FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        }
        return projects
    }
    
    init() {
        currentPath = LocalFileManager.appDocumentsURL
        // Fix 4: Create welcome file so user can see the folder in Files app
        createWelcomeFileIfNeeded()
        loadFiles(at: currentPath)
    }
    
    // Fix 4: Create a README so the folder appears in Files app
    private func createWelcomeFileIfNeeded() {
        let readmePath = currentPath.appendingPathComponent("README.txt")
        if !fm.fileExists(atPath: readmePath.path) {
            let content = """
GitActions Hub - مجلد المشاريع
================================
ضع ملفات مشاريعك هنا لتتمكن من:
- تعديلها من داخل التطبيق
- رفعها على GitHub عبر Commit & Push

للوصول لهذا المجلد من تطبيق Files:
Files > On My iPhone > GitActionsHub > Projects
"""
            try? content.write(to: readmePath, atomically: true, encoding: .utf8)
        }
    }
    
    func loadFiles(at url: URL) {
        isLoading = true
        currentPath = url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let files = self.buildFileTree(at: url)
            DispatchQueue.main.async { self.rootFiles = files; self.isLoading = false }
        }
    }
    
    private func buildFileTree(at url: URL) -> [GitFile] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        return contents.compactMap { fileURL in
            let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            let isDir = res?.isDirectory ?? false
            var file = GitFile(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDirectory: isDir,
                size: Int64(res?.fileSize ?? 0),
                modifiedDate: res?.contentModificationDate ?? Date()
            )
            if isDir { file.children = buildFileTree(at: fileURL) }
            return file
        }.sorted { a, b in a.isDirectory != b.isDirectory ? a.isDirectory : a.name < b.name }
    }
    
    func readFile(_ file: GitFile) {
        guard !file.isDirectory else { return }
        let url = URL(fileURLWithPath: file.path)
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            DispatchQueue.main.async { self.fileContent = content; self.selectedFile = file }
        } catch {
            DispatchQueue.main.async { self.error = "تعذّر قراءة الملف: \(error.localizedDescription)" }
        }
    }
    
    func writeFile(_ file: GitFile, content: String) {
        let url = URL(fileURLWithPath: file.path)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر حفظ الملف: \(error.localizedDescription)" }
    }
    
    func createFile(name: String, at parentPath: String, isDirectory: Bool = false) {
        let url = URL(fileURLWithPath: "\(parentPath)/\(name)")
        do {
            if isDirectory { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
            else { fm.createFile(atPath: url.path, contents: Data()) }
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر الإنشاء: \(error.localizedDescription)" }
    }
    
    func deleteFile(_ file: GitFile) {
        do {
            try fm.removeItem(at: URL(fileURLWithPath: file.path))
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر الحذف: \(error.localizedDescription)" }
    }
    
    func renameFile(_ file: GitFile, newName: String) {
        let oldURL = URL(fileURLWithPath: file.path)
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fm.moveItem(at: oldURL, to: newURL)
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر إعادة التسمية: \(error.localizedDescription)" }
    }
    
    // Fix 5: Move file up or down (reorder via rename trick with index prefix)
    func moveFile(_ file: GitFile, direction: MoveDirection) {
        guard let index = rootFiles.firstIndex(where: { $0.id == file.id }) else { return }
        let newIndex = direction == .up ? index - 1 : index + 1
        guard newIndex >= 0 && newIndex < rootFiles.count else { return }
        rootFiles.swapAt(index, newIndex)
    }
    
    func importFromFiles(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let destURL = currentPath.appendingPathComponent(url.lastPathComponent)
        do {
            if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
            try fm.copyItem(at: url, to: destURL)
            loadFiles(at: currentPath)
        } catch { self.error = "تعذّر الاستيراد: \(error.localizedDescription)" }
    }
    
    // Fix 4: Navigate to parent directory
    func navigateUp() {
        let parent = currentPath.deletingLastPathComponent()
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        // Don't go above Documents
        if currentPath.path != docs.path {
            loadFiles(at: parent)
        }
    }
    
    var isAtRoot: Bool { currentPath == LocalFileManager.appDocumentsURL }
    
    var currentPathDisplay: String {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!.path
        return currentPath.path.replacingOccurrences(of: docs, with: "📱 iPhone")
    }
}

enum MoveDirection { case up, down }

// MARK: - Git Operations Manager

class GitOperationsManager: ObservableObject {
    @Published var stagedFiles: [String] = []
    @Published var commitHistory: [CommitInfo] = []
    @Published var isLoading = false
    @Published var lastCommitResult: String?
    
    private let gitHubService: GitHubService
    
    init(gitHubService: GitHubService) { self.gitHubService = gitHubService }
    
    func commitAndPush(owner: String, repo: String, branch: String, message: String, files: [(path: String, content: String)]) async -> Bool {
        await MainActor.run { isLoading = true }
        do {
            guard let token = UserDefaults.standard.string(forKey: "gh_access_token"),
                  let baseURL = URL(string: "https://api.github.com") else { return false }
            
            // 1. Get branch SHA
            var refReq = URLRequest(url: baseURL.appendingPathComponent("/repos/\(owner)/\(repo)/git/refs/heads/\(branch)"))
            refReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            refReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (refData, _) = try await URLSession.shared.data(for: refReq)
            struct RefResponse: Codable { struct Obj: Codable { let sha: String }; let object: Obj }
            let currentSHA = try JSONDecoder().decode(RefResponse.self, from: refData).object.sha
            
            // 2. Create blobs
            var treeItems: [[String: String]] = []
            for file in files {
                var blobReq = URLRequest(url: baseURL.appendingPathComponent("/repos/\(owner)/\(repo)/git/blobs"))
                blobReq.httpMethod = "POST"
                blobReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                blobReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                blobReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                blobReq.httpBody = try JSONEncoder().encode(["content": file.content, "encoding": "utf-8"])
                let (blobData, _) = try await URLSession.shared.data(for: blobReq)
                struct BlobResp: Codable { let sha: String }
                let blobSHA = try JSONDecoder().decode(BlobResp.self, from: blobData).sha
                treeItems.append(["path": file.path, "mode": "100644", "type": "blob", "sha": blobSHA])
            }
            
            // 3. Create tree
            var treeReq = URLRequest(url: baseURL.appendingPathComponent("/repos/\(owner)/\(repo)/git/trees"))
            treeReq.httpMethod = "POST"
            treeReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            treeReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            treeReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            treeReq.httpBody = try JSONSerialization.data(withJSONObject: ["base_tree": currentSHA, "tree": treeItems])
            let (treeData, _) = try await URLSession.shared.data(for: treeReq)
            struct TreeResp: Codable { let sha: String }
            let treeSHA = try JSONDecoder().decode(TreeResp.self, from: treeData).sha
            
            // 4. Create commit
            var commitReq = URLRequest(url: baseURL.appendingPathComponent("/repos/\(owner)/\(repo)/git/commits"))
            commitReq.httpMethod = "POST"
            commitReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            commitReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            commitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            commitReq.httpBody = try JSONSerialization.data(withJSONObject: ["message": message, "tree": treeSHA, "parents": [currentSHA]])
            let (commitData, _) = try await URLSession.shared.data(for: commitReq)
            struct CommitResp: Codable { let sha: String }
            let commitSHA = try JSONDecoder().decode(CommitResp.self, from: commitData).sha
            
            // 5. Update ref
            var updateReq = URLRequest(url: baseURL.appendingPathComponent("/repos/\(owner)/\(repo)/git/refs/heads/\(branch)"))
            updateReq.httpMethod = "PATCH"
            updateReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            updateReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            updateReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            updateReq.httpBody = try JSONSerialization.data(withJSONObject: ["sha": commitSHA, "force": false])
            let _ = try await URLSession.shared.data(for: updateReq)
            
            await MainActor.run {
                let commit = CommitInfo(message: message, files: files.map { $0.path }, branch: branch, timestamp: Date(), sha: String(commitSHA.prefix(7)))
                self.commitHistory.insert(commit, at: 0)
                self.stagedFiles.removeAll()
                self.lastCommitResult = "✅ تم Push بنجاح! SHA: \(String(commitSHA.prefix(7)))"
                self.isLoading = false
            }
            return true
        } catch {
            await MainActor.run { self.lastCommitResult = "❌ فشل: \(error.localizedDescription)"; self.isLoading = false }
            return false
        }
    }
}
