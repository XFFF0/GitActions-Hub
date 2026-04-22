import Foundation

class LocalFileManager: ObservableObject {
    
    @Published var rootFiles: [GitFile] = []
    @Published var currentPath: String = ""
    @Published var error: String?
    @Published var currentFiles: [GitFile] = []
    @Published var isLoading = false
    
    @Published var modifiedFiles: Set<String> = []
    @Published var hasUncommittedChanges: Bool = false
    
    @Published var uploadProgress: String = ""
    @Published var uploadedCount: Int = 0
    @Published var totalToUpload: Int = 0
    
    static let textExtensions: Set<String> = [
        "swift", "m", "h", "mm", "hpp", "cpp", "c", "cs", "java", "kt", "py",
        "rb", "js", "ts", "jsx", "tsx", "html", "css", "scss", "less", "json",
        "xml", "yaml", "yml", "toml", "ini", "cfg", "conf", "sh", "bash", "zsh",
        "fish", "bat", "ps1", "sql", "md", "txt", "rst", "log", "csv", "tsv",
        "Makefile", "Dockerfile", "gitignore", "gitattributes", "editorconfig",
        "env", "properties", "gradle", "cmake", "proto", "graphql", "vue",
        "svelte", "lua", "r", "go", "rs", "dart", "php", "pl", "ex", "exs",
        "erl", "hs", "ml", "fs", "clj", "scala", "v", "sv", "vhd"
    ]
    
    static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "ico", "svg", "webp", "tiff", "tif",
        "mp3", "mp4", "wav", "avi", "mov", "pdf", "zip", "tar", "gz", "rar",
        "7z", "dmg", "iso", "app", "exe", "dll", "so", "dylib", "a", "lib",
        "o", "pyc", "class", "jar", "war", "ear", "framework", "bundle",
        "xcassets", "nib", "xib", "storyboardc", "ipa", "apk", "aab"
    ]
    
    func getAppDirectory() -> String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let appDir = (docs as NSString).appendingPathComponent("GitActionsHub")
        if !FileManager.default.fileExists(atPath: appDir) {
            try? FileManager.default.createDirectory(atPath: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }
    
    func loadFiles(at path: String? = nil) {
        let basePath = getAppDirectory()
        let targetPath = path ?? basePath
        currentPath = targetPath
        
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: targetPath)
            var files: [GitFile] = []
            
            for item in items {
                if item.hasPrefix(".") { continue }
                
                let fullPath = (targetPath as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                
                let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
                let size = (attrs?[.size] as? Int64) ?? 0
                let modDate = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
                
                // ✅ إصلاح: استخدام isDirectory.boolValue بدلاً من isDir مكرر
                let itemIsDirectory = isDirectory.boolValue
                let ext = (item as NSString).pathExtension.lowercased()
                let isText = Self.textExtensions.contains(ext) || ext.isEmpty || item.hasPrefix(".")
                let isBinary = Self.binaryExtensions.contains(ext)
                
                files.append(GitFile(
                    name: item,
                    path: fullPath,
                    isDirectory: itemIsDirectory,
                    size: size,
                    modificationDate: modDate,
                    isTextFile: !itemIsDirectory && isText,
                    isBinaryFile: !itemIsDirectory && isBinary,
                    content: nil
                ))
            }
            
            files.sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.lowercased() < b.name.lowercased()
            }
            
            if path == nil { rootFiles = files }
            currentFiles = files
            error = nil
            
        } catch {
            self.error = "تعذّر تحميل الملفات: \(error.localizedDescription)"
        }
    }
    
    func readFileContent(_ file: GitFile) -> String? {
        let url = URL(fileURLWithPath: file.path)
        if file.isTextFile {
            return try? String(contentsOf: url, encoding: .utf8)
        } else if file.isBinaryFile {
            if let data = try? Data(contentsOf: url) {
                return data.base64EncodedString()
            }
        }
        return nil
    }
    
    func writeFile(_ file: GitFile, content: String) {
        do {
            let url = URL(fileURLWithPath: file.path)
            if file.isBinaryFile, let data = Data(base64Encoded: content) {
                try data.write(to: url)
            } else {
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
            modifiedFiles.insert(file.path)
            updateUncommittedStatus()
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر حفظ الملف: \(error.localizedDescription)"
        }
    }
    
    func createFile(name: String, in directory: String? = nil, content: String = "") {
        let dir = directory ?? currentPath
        let fullPath = (dir as NSString).appendingPathComponent(name)
        let ext = (name as NSString).pathExtension.lowercased()
        let isBinary = Self.binaryExtensions.contains(ext)
        
        do {
            if isBinary {
                FileManager.default.createFile(atPath: fullPath, contents: nil)
            } else {
                try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            }
            modifiedFiles.insert(fullPath)
            updateUncommittedStatus()
            loadFiles(at: dir)
        } catch {
            self.error = "تعذّر إنشاء الملف: \(error.localizedDescription)"
        }
    }
    
    func createDirectory(name: String, in directory: String? = nil) {
        let dir = directory ?? currentPath
        let fullPath = (dir as NSString).appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
            loadFiles(at: dir)
        } catch {
            self.error = "تعذّر إنشاء المجلد: \(error.localizedDescription)"
        }
    }
    
    func deleteItem(_ file: GitFile) {
        do {
            try FileManager.default.removeItem(atPath: file.path)
            modifiedFiles.remove(file.path)
            updateUncommittedStatus()
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر حذف \(file.name): \(error.localizedDescription)"
        }
    }
    
    func renameItem(_ file: GitFile, newName: String) {
        let newFullPath = (currentPath as NSString).appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(atPath: file.path, toPath: newFullPath)
            modifiedFiles.remove(file.path)
            modifiedFiles.insert(newFullPath)
            updateUncommittedStatus()
            loadFiles(at: currentPath)
        } catch {
            self.error = "تعذّر إعادة التسمية: \(error.localizedDescription)"
        }
    }
    
    func importFile(from url: URL, to directory: String? = nil) {
        let dir = directory ?? currentPath
        let fileName = url.lastPathComponent
        let destPath = (dir as NSString).appendingPathComponent(fileName)
        
        guard url.startAccessingSecurityScopedResource() else {
            self.error = "تعذّر الوصول للملف"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.copyItem(atPath: url.path, toPath: destPath)
            modifiedFiles.insert(destPath)
            updateUncommittedStatus()
            loadFiles(at: dir)
        } catch {
            self.error = "تعذّر استيراد الملف: \(error.localizedDescription)"
        }
    }
    
    func collectAllFiles(from files: [GitFile], basePath: String = "") -> [FileToPush] {
        var result: [FileToPush] = []
        
        for file in files {
            let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
            
            if file.isDirectory {
                do {
                    let subItems = try FileManager.default.contentsOfDirectory(atPath: file.path)
                    var subFiles: [GitFile] = []
                    for item in subItems {
                        let fullPath = (file.path as NSString).appendingPathComponent(item)
                        var isDirectory: ObjCBool = false
                        FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                        let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
                        let size = (attrs?[.size] as? Int64) ?? 0
                        let modDate = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
                        let ext = (item as NSString).pathExtension.lowercased()
                        let isText = Self.textExtensions.contains(ext) || ext.isEmpty
                        let isBinary = Self.binaryExtensions.contains(ext)
                        
                        subFiles.append(GitFile(
                            name: item,
                            path: fullPath,
                            isDirectory: isDirectory.boolValue,
                            size: size,
                            modificationDate: modDate,
                            isTextFile: !isDirectory.boolValue && isText,
                            isBinaryFile: !isDirectory.boolValue && isBinary,
                            content: nil
                        ))
                    }
                    result.append(contentsOf: collectAllFiles(from: subFiles, basePath: relativePath))
                } catch {}
            } else {
                guard file.size < 100_000_000 else { continue }
                let url = URL(fileURLWithPath: file.path)
                
                if file.isTextFile {
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        result.append(FileToPush(path: relativePath, content: content, isBinary: false, size: file.size))
                    }
                } else {
                    if let data = try? Data(contentsOf: url) {
                        let base64 = data.base64EncodedString()
                        result.append(FileToPush(path: relativePath, content: base64, isBinary: true, size: file.size))
                    }
                }
            }
        }
        return result
    }
    
    func collectModifiedFiles() -> [FileToPush] {
        let allFiles = collectAllFiles(from: rootFiles)
        if modifiedFiles.isEmpty { return allFiles }
        return allFiles.filter { file in
            modifiedFiles.contains { modifiedPath in
                modifiedPath.hasSuffix(file.path) || file.path.hasSuffix(modifiedPath)
            }
        }
    }
    
    private func updateUncommittedStatus() {
        hasUncommittedChanges = !modifiedFiles.isEmpty
    }
    
    func clearModifications() {
        modifiedFiles.removeAll()
        hasUncommittedChanges = false
    }
    
    var modifiedCount: Int { modifiedFiles.count }
}
