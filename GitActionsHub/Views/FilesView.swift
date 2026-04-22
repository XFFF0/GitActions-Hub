import SwiftUI

struct FilesView: View {
    @StateObject private var fileManager = LocalFileManager()
    @StateObject private var githubService = GitHubService()
    
    // Repository Info
    @State private var selectedRepo: Repo?
    @State private var owner: String = ""
    @State private var repoName: String = ""
    @State private var branch: String = "main"
    
    // UI State
    @State private var commitMessage: String = ""
    @State private var showingCommitSheet = false
    @State private var showingNewFileSheet = false
    @State private var newFileName: String = ""
    @State private var newFileContent: String = ""
    @State private var isNewDirectory: Bool = false
    @State private var showingRenameSheet = false
    @State private var renameTarget: GitFile?
    @State private var renameText: String = ""
    @State private var showingRepoSelector = false
    @State private var showingFilePicker = false
    @State private var showingEditor = false
    @State private var editingFile: GitFile?
    @State private var editingContent: String = ""
    @State private var showingDeleteConfirm = false
    @State private var deleteTarget: GitFile?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // الخلفية
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ✅ شريط معلومات المستودع
                    repoInfoBar
                    
                    // ✅ شريط التغييرات
                    if fileManager.hasUncommittedChanges {
                        changesBar
                    }
                    
                    // ✅ شريط تقدم الرفع
                    if githubService.isPushing {
                        pushProgressBar
                    }
                    
                    // قائمة الملفات
                    if fileManager.currentFiles.isEmpty && !fileManager.isLoading {
                        emptyState
                    } else {
                        fileList
                    }
                }
            }
            .navigationTitle("📁 الملفات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button { showingRepoSelector = true } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showingNewFileSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    Button { showingFilePicker = true } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    if fileManager.hasUncommittedChanges {
                        Button { showingCommitSheet = true } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRepoSelector) {
                repoSelectorSheet
            }
            .sheet(isPresented: $showingCommitSheet) {
                commitSheet
            }
            .sheet(isPresented: $showingNewFileSheet) {
                newFileSheet
            }
            .sheet(isPresented: $showingEditor) {
                fileEditorSheet
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(onPick: { url in
                    fileManager.importFile(from: url)
                })
            }
            .alert("إعادة تسمية", isPresented: $showingRenameSheet) {
                TextField("الاسم الجديد", text: $renameText)
                Button("إلغاء", role: .cancel) {}
                Button("تأكيد") {
                    if let file = renameTarget {
                        fileManager.renameItem(file, newName: renameText)
                    }
                }
            }
            .alert("حذف", isPresented: $showingDeleteConfirm) {
                Button("إلغاء", role: .cancel) {}
                Button("حذف", role: .destructive) {
                    if let file = deleteTarget {
                        fileManager.deleteItem(file)
                    }
                }
            } message: {
                Text("هل تريد حذف \(deleteTarget?.name ?? "")؟")
            }
        }
        .onAppear {
            fileManager.loadFiles()
        }
    }
    
    // MARK: - شريط معلومات المستودع
    private var repoInfoBar: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "branch")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(selectedRepo != nil ? "\(owner)/\(repoName)" : "اختر مستودع")
                    .font(.caption)
                    .foregroundColor(selectedRepo != nil ? .primary : .secondary)
                Spacer()
                Text(branch)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            
            Divider()
        }
        .background(Color(.systemGray6).opacity(0.5))
    }
    
    // MARK: - شريط التغييرات
    private var changesBar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.orange)
                Text("\(fileManager.modifiedCount) تغيير غير مرفوع")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Button("رفع") {
                    showingCommitSheet = true
                }
                .font(.caption.bold())
                .foregroundColor(.green)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
        }
        .background(Color.orange.opacity(0.08))
    }
    
    // MARK: - شريط تقدم الرفع ✅
    private var pushProgressBar: some View {
        VStack(spacing: 6) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text(githubService.pushProgress)
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            ProgressView(value: Double(githubService.pushFileIndex), total: Double(max(githubService.pushFileTotal, 1)))
                .tint(.green)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
    }
    
    // MARK: - الحالة الفارغة
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("لا توجد ملفات")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("أضف ملفات جديدة أو استورد من تطبيق الملفات")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - قائمة الملفات
    private var fileList: some View {
        List {
            // ✅ زر العودة للمجلد الأعلى
            if fileManager.currentPath != fileManager.getAppDirectory() {
                Button {
                    let parent = (fileManager.currentPath as NSString).deletingLastPathComponent
                    fileManager.loadFiles(at: parent)
                } label: {
                    HStack {
                        Image(systemName: "chevron.up")
                            .foregroundColor(.secondary)
                        Text("..")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // الملفات
            ForEach(fileManager.currentFiles) { file in
                fileRow(file)
                    .contextMenu {
                        fileContextMenu(file)
                    }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - صف الملف
    private func fileRow(_ file: GitFile) -> some View {
        Button {
            if file.isDirectory {
                fileManager.loadFiles(at: file.path)
            } else {
                openFile(file)
            }
        } label: {
            HStack(spacing: 12) {
                // أيقونة
                Image(systemName: file.isDirectory ? "folder.fill" : fileIcon(file.name))
                    .font(.title3)
                    .foregroundColor(file.isDirectory ? .blue : iconColor(file.name))
                    .frame(width: 30)
                
                // معلومات الملف
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        if !file.isDirectory {
                            Text(formatFileSize(file.size))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // ✅ مؤشر التعديل
                        if fileManager.modifiedFiles.contains(file.path) {
                            Text("معدّل")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        if file.isBinaryFile {
                            Text("ثنائي")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Spacer()
                
                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - قائمة سياق الملف
    @ViewBuilder
    private func fileContextMenu(_ file: GitFile) -> some View {
        if !file.isDirectory {
            Button { openFile(file) } label: {
                Label("فتح", systemImage: "doc.text")
            }
        }
        
        Button {
            renameTarget = file
            renameText = file.name
            showingRenameSheet = true
        } label: {
            Label("إعادة تسمية", systemImage: "pencil")
        }
        
        Button(role: .destructive) {
            deleteTarget = file
            showingDeleteConfirm = true
        } label: {
            Label("حذف", systemImage: "trash")
        }
    }
    
    // MARK: - نافذة اختيار المستودع
    private var repoSelectorSheet: some View {
        NavigationStack {
            List {
                if githubService.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if githubService.repos.isEmpty {
                    Text("لا توجد مستودعات")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(githubService.repos) { repo in
                        Button {
                            selectedRepo = repo
                            owner = repo.owner.login
                            repoName = repo.name
                            branch = repo.default_branch ?? "main"
                            showingRepoSelector = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(repo.full_name)
                                        .font(.body)
                                    if let desc = repo.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if repo.isPrivate {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if selectedRepo?.id == repo.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("اختر المستودع")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { showingRepoSelector = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await githubService.fetchRepos() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            if githubService.repos.isEmpty {
                Task { await githubService.fetchRepos() }
            }
        }
    }
    
    // MARK: - ✅ نافذة الرفع (Commit & Push)
    private var commitSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // معلومات المستودع
                if selectedRepo != nil {
                    HStack {
                        Image(systemName: "repo")
                            .foregroundColor(.secondary)
                        Text("\(owner)/\(repoName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(branch)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // رسالة الالتزام
                TextField("رسالة الالتزام...", text: $commitMessage)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                // ✅ عدد الملفات المطلوب رفعها
                let filesToPush = fileManager.collectModifiedFiles()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("الملفات المطلوب رفعها:")
                            .font(.caption.bold())
                        Spacer()
                        Text("\(filesToPush.count) ملف")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if filesToPush.count <= 10 {
                        ForEach(filesToPush) { file in
                            HStack {
                                Image(systemName: file.isBinary ? "doc.binary" : "doc.text")
                                    .font(.caption)
                                    .foregroundColor(file.isBinary ? .purple : .secondary)
                                Text(file.path)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatFileSize(file.size))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        ForEach(filesToPush.prefix(5)) { file in
                            HStack {
                                Image(systemName: file.isBinary ? "doc.binary" : "doc.text")
                                    .font(.caption)
                                    .foregroundColor(file.isBinary ? .purple : .secondary)
                                Text(file.path)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatFileSize(file.size))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text("... و \(filesToPush.count - 5) ملف آخر")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // ✅ تحذير إذا لم يتم اختيار مستودع
                if selectedRepo == nil {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("اختر مستودع أولاً من الأعلى")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("رفع التغييرات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { showingCommitSheet = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("رفع") {
                        Task { await performPush() }
                    }
                    .bold()
                    .foregroundColor(selectedRepo == nil || commitMessage.isEmpty ? .gray : .green)
                    .disabled(selectedRepo == nil || commitMessage.isEmpty || githubService.isPushing)
                }
            }
        }
    }
    
    // MARK: - ✅ تنفيذ الرفع
    private func performPush() async {
        guard selectedRepo != nil else { return }
        
        let files = fileManager.collectModifiedFiles()
        
        let success = await githubService.pushFiles(
            owner: owner,
            repo: repoName,
            branch: branch,
            message: commitMessage,
            files: files,
            fileManager: fileManager
        )
        
        await MainActor.run {
            showingCommitSheet = false
            
            if success {
                commitMessage = ""
            }
        }
    }
    
    // MARK: - نافذة إنشاء ملف جديد
    private var newFileSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle("مجلد", isOn: $isNewDirectory)
                    .padding(.horizontal)
                
                TextField("اسم الملف أو المجلد", text: $newFileName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                if !isNewDirectory {
                    TextEditor(text: $newFileContent)
                        .font(.system(.body, design: .monospaced))
                        .border(Color(.systemGray4), width: 1)
                        .frame(minHeight: 200)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle(isNewDirectory ? "مجلد جديد" : "ملف جديد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") {
                        newFileName = ""
                        newFileContent = ""
                        isNewDirectory = false
                        showingNewFileSheet = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("إنشاء") {
                        if isNewDirectory {
                            fileManager.createDirectory(name: newFileName)
                        } else {
                            fileManager.createFile(name: newFileName, content: newFileContent)
                        }
                        newFileName = ""
                        newFileContent = ""
                        isNewDirectory = false
                        showingNewFileSheet = false
                    }
                    .disabled(newFileName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - نافذة تعديل الملف
    private var fileEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let file = editingFile {
                    TextEditor(text: $editingContent)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
            .navigationTitle(editingFile?.name ?? "تعديل")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") {
                        editingFile = nil
                        editingContent = ""
                        showingEditor = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("حفظ") {
                        if let file = editingFile {
                            fileManager.writeFile(file, content: editingContent)
                        }
                        editingFile = nil
                        editingContent = ""
                        showingEditor = false
                    }
                    .bold()
                    .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - فتح ملف
    private func openFile(_ file: GitFile) {
        if file.isBinaryFile {
            // لا يمكن تعديل الملفات الثنائية
            return
        }
        
        if let content = fileManager.readFileContent(file) {
            editingFile = file
            editingContent = content
            showingEditor = true
        }
    }
    
    // MARK: - أيقونة الملف
    private func fileIcon(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text.javascript"
        case "py": return "doc.text.python"
        case "html": return "doc.text.html"
        case "css": return "doc.text.css"
        case "json": return "doc.text.json"
        case "md": return "doc.text.markdown"
        case "yaml", "yml": return "doc.text.config"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "pdf": return "doc.pdf"
        case "zip", "tar", "gz": return "doc.zipper"
        default: return "doc.text"
        }
    }
    
    // MARK: - لون الأيقونة
    private func iconColor(_ name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js": return .yellow
        case "ts": return .blue
        case "py": return .green
        case "html": return .red
        case "css": return .purple
        case "json": return .cyan
        case "md": return .white
        case "yaml", "yml": return .pink
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return .teal
        default: return .secondary
        }
    }
    
    // MARK: - تنسيق حجم الملف
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls { onPick(url) }
        }
    }
}
