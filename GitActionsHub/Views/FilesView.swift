import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @StateObject private var fileManager = LocalFileManager()
    @EnvironmentObject var gitHubService: GitHubService
    
    @State private var showFileEditor = false
    @State private var showCreateDialog = false
    @State private var showCommitSheet = false
    @State private var showImportPicker = false
    @State private var showDeleteAlert = false
    @State private var showRenameDialog = false
    @State private var fileToDelete: GitFile?
    @State private var fileToRename: GitFile?
    @State private var newFileName = ""
    @State private var isCreatingFolder = false
    @State private var isEditMode = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                VStack(spacing: 0) {
                    filesHeader
                    pathBar
                    fileToolbar.padding(.horizontal).padding(.bottom, 8)
                    
                    if fileManager.isLoading {
                        LoadingCard()
                    } else if fileManager.rootFiles.isEmpty {
                        EmptyStateView(icon: "folder.badge.plus", title: "مجلد فارغ", subtitle: "أضف ملفات أو استورد من Files app")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(fileManager.rootFiles.enumerated()), id: \.element.id) { index, file in
                                    FileRow(
                                        file: file,
                                        depth: 0,
                                        isEditMode: isEditMode,
                                        canMoveUp: index > 0,
                                        canMoveDown: index < fileManager.rootFiles.count - 1,
                                        onTap: { handleFileTap($0) },
                                        onDelete: { fileToDelete = $0; showDeleteAlert = true },
                                        onRename: { fileToRename = $0; newFileName = $0.name; showRenameDialog = true },
                                        onMoveUp: { fileManager.moveFile(file, direction: .up) },
                                        onMoveDown: { fileManager.moveFile(file, direction: .down) }
                                    )
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        // Fix: Force LTR on entire view to prevent Arabic UI from flipping English content
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showFileEditor) {
            if let file = fileManager.selectedFile {
                FileEditorView(file: file, content: fileManager.fileContent) { newContent in
                    fileManager.writeFile(file, content: newContent)
                }
            }
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitPushSheet(gitHubService: gitHubService, fileManager: fileManager)
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { urls.forEach { fileManager.importFromFiles(url: $0) } }
        }
        .alert("إنشاء \(isCreatingFolder ? "مجلد" : "ملف")", isPresented: $showCreateDialog) {
            TextField("الاسم", text: $newFileName).autocorrectionDisabled().textInputAutocapitalization(.never)
            Button("إنشاء") {
                if !newFileName.isEmpty {
                    fileManager.createFile(name: newFileName, at: fileManager.currentPath.path, isDirectory: isCreatingFolder)
                    newFileName = ""
                }
            }
            Button("إلغاء", role: .cancel) { newFileName = "" }
        }
        .alert("إعادة تسمية", isPresented: $showRenameDialog) {
            TextField("الاسم الجديد", text: $newFileName).autocorrectionDisabled().textInputAutocapitalization(.never)
            Button("حفظ") {
                if let file = fileToRename, !newFileName.isEmpty { fileManager.renameFile(file, newName: newFileName); newFileName = "" }
            }
            Button("إلغاء", role: .cancel) { newFileName = "" }
        }
        .alert("حذف الملف", isPresented: $showDeleteAlert) {
            Button("حذف", role: .destructive) { if let file = fileToDelete { fileManager.deleteFile(file) } }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("هل تريد حذف \"\(fileToDelete?.name ?? "")\"؟") }
    }
    
    var filesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Files")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColors.text)
                Text("إدارة ملفات المشروع")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            
            Button {
                withAnimation { isEditMode.toggle() }
            } label: {
                Text(isEditMode ? "تم" : "ترتيب")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isEditMode ? Color(hex: "#6BCB77") : AppColors.textSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(isEditMode ? Color(hex: "#6BCB77").opacity(0.15) : AppColors.surfaceElevated)
                    .clipShape(Capsule())
            }
            
            Button { showCommitSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Push").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8)
                .background(LinearGradient(colors: [Color(hex: "#6BCB77"), Color(hex: "#4CAF50")], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#6BCB77").opacity(0.4), radius: 8)
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
    }
    
    var pathBar: some View {
        HStack(spacing: 8) {
            if !fileManager.isAtRoot {
                Button { fileManager.navigateUp() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        Text("رجوع").font(.system(size: 12))
                    }
                    .foregroundColor(AppColors.accent).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.accent.opacity(0.1)).clipShape(Capsule())
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(fileManager.currentPathDisplay)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary).lineLimit(1)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer()
            if fileManager.isAtRoot {
                Text("Files > iPhone > GitActionsHub > Projects")
                    .font(.system(size: 9))
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal).padding(.vertical, 6)
        .background(AppColors.surfaceElevated.opacity(0.5))
    }
    
    var fileToolbar: some View {
        HStack(spacing: 8) {
            ToolbarButton(icon: "doc.badge.plus", label: "ملف", color: AppColors.accent) {
                isCreatingFolder = false; newFileName = ""; showCreateDialog = true
            }
            ToolbarButton(icon: "folder.badge.plus", label: "مجلد", color: Color(hex: "#FFD93D")) {
                isCreatingFolder = true; newFileName = ""; showCreateDialog = true
            }
            ToolbarButton(icon: "square.and.arrow.down.fill", label: "استيراد", color: Color(hex: "#6BCB77")) {
                showImportPicker = true
            }
            ToolbarButton(icon: "arrow.clockwise", label: "تحديث", color: AppColors.textSecondary) {
                fileManager.loadFiles(at: fileManager.currentPath)
            }
        }
    }
    
    private func handleFileTap(_ file: GitFile) {
        if file.isDirectory {
            fileManager.loadFiles(at: URL(fileURLWithPath: file.path))
        } else {
            fileManager.readFile(file)
            showFileEditor = true
        }
    }
}

// MARK: - File Row
struct FileRow: View {
    let file: GitFile
    let depth: Int
    let isEditMode: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onTap: (GitFile) -> Void
    let onDelete: (GitFile) -> Void
    let onRename: (GitFile) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 0) {
                if isEditMode {
                    VStack(spacing: 2) {
                        Button { onMoveUp() } label: {
                            Image(systemName: "chevron.up").font(.system(size: 11, weight: .bold))
                                .foregroundColor(canMoveUp ? AppColors.accent : AppColors.border)
                                .frame(width: 28, height: 22)
                        }.disabled(!canMoveUp)
                        Button { onMoveDown() } label: {
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                                .foregroundColor(canMoveDown ? AppColors.accent : AppColors.border)
                                .frame(width: 28, height: 22)
                        }.disabled(!canMoveDown)
                    }.padding(.leading, 4)
                }
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if file.isDirectory { isExpanded.toggle() }
                        onTap(file)
                    }
                } label: {
                    HStack(spacing: 10) {
                        if depth > 0 {
                            Rectangle().fill(AppColors.border).frame(width: 1, height: 28)
                                .padding(.leading, CGFloat(depth) * 16)
                        }
                        if file.isDirectory {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary).frame(width: 12)
                        } else {
                            Spacer().frame(width: 12)
                        }
                        Image(systemName: file.icon).font(.system(size: 16))
                            .foregroundColor(file.iconColor).frame(width: 20)
                        // Fix 1: LTR for filenames
                        Text(file.name)
                            .font(.system(size: 14, weight: .medium, design: file.isDirectory ? .default : .monospaced))
                            .foregroundColor(AppColors.text)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        if !file.isDirectory {
                            Text(formatSize(file.size)).font(.system(size: 10)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Fix 1: Force RTL on context menu so Arabic labels show correctly
                .contextMenu {
                    Button {
                        onTap(file)
                    } label: {
                        // Fix: explicit label with LTR system text
                        HStack {
                            Text(file.isDirectory ? "فتح" : "تعديل")
                            Spacer()
                            Image(systemName: "pencil")
                        }
                    }
                    Button {
                        onRename(file)
                    } label: {
                        HStack {
                            Text("إعادة تسمية")
                            Spacer()
                            Image(systemName: "pencil.circle")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        onDelete(file)
                    } label: {
                        HStack {
                            Text("حذف")
                            Spacer()
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .background(AppColors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if file.isDirectory && isExpanded, let children = file.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    FileRow(
                        file: child, depth: depth + 1, isEditMode: isEditMode,
                        canMoveUp: index > 0, canMoveDown: index < children.count - 1,
                        onTap: onTap, onDelete: onDelete, onRename: onRename,
                        onMoveUp: onMoveUp, onMoveDown: onMoveDown
                    )
                    .padding(.leading, 12)
                }
            }
        }
    }
    
    func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024)KB" }
        return "\(bytes / (1024 * 1024))MB"
    }
}

// MARK: - File Editor
struct FileEditorView: View {
    let file: GitFile
    let content: String
    let onSave: (String) -> Void
    
    @State private var editedContent: String
    @State private var hasChanges = false
    @Environment(\.dismiss) var dismiss
    
    init(file: GitFile, content: String, onSave: @escaping (String) -> Void) {
        self.file = file; self.content = content; self.onSave = onSave
        _editedContent = State(initialValue: content)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#080810").ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: file.icon).foregroundColor(file.iconColor)
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.text)
                            .environment(\.layoutDirection, .leftToRight)
                        if hasChanges { Circle().fill(Color(hex: "#FFD93D")).frame(width: 6, height: 6) }
                        Spacer()
                        Text("\(editedContent.components(separatedBy: "\n").count) سطر")
                            .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10).background(AppColors.surface)
                    Divider().background(AppColors.border)
                    CodeEditorView(text: $editedContent, onChange: { hasChanges = true })
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إغلاق") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSave(editedContent); hasChanges = false; dismiss()
                    } label: {
                        Text("حفظ").font(.system(size: 14, weight: .bold))
                            .foregroundColor(hasChanges ? AppColors.accent : AppColors.textSecondary)
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Code Editor with line numbers
struct CodeEditorView: View {
    @Binding var text: String
    let onChange: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "#444460"))
                        .frame(minWidth: 44, alignment: .trailing)
                        .padding(.vertical, 2)
                }
                Spacer()
            }
            .padding(.leading, 8).padding(.trailing, 12).background(Color(hex: "#0C0C18"))
            
            Divider().background(AppColors.border)
            
            TextEditor(text: Binding(get: { text }, set: { text = $0; onChange() }))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(AppColors.text)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.leading, 8)
                .environment(\.layoutDirection, .leftToRight)
        }
        .background(Color(hex: "#080810"))
    }
}

// MARK: - Commit Push Sheet
struct CommitPushSheet: View {
    @ObservedObject var gitHubService: GitHubService
    @ObservedObject var fileManager: LocalFileManager
    
    @StateObject private var gitOps: GitOperationsManager
    @State private var commitMessage = ""
    @State private var selectedRepo = ""
    @State private var selectedBranch = "main"
    @State private var pendingFilesCount = 0
    @Environment(\.dismiss) var dismiss
    
    init(gitHubService: GitHubService, fileManager: LocalFileManager) {
        self.gitHubService = gitHubService
        self.fileManager = fileManager
        _gitOps = StateObject(wrappedValue: GitOperationsManager(gitHubService: gitHubService))
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Text("Commit & Push").font(.system(size: 16, weight: .bold)).foregroundColor(AppColors.text)
                    Spacer()
                    if gitOps.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent)).scaleEffect(0.8)
                    }
                }
                .padding()
                Divider().background(AppColors.border)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Files count badge
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(AppColors.accent)
                            Text("\(pendingFilesCount) ملف سيتم رفعه")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.text)
                            Spacer()
                            Text("نصية فقط")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(12)
                        .background(AppColors.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.accent.opacity(0.2), lineWidth: 1))
                        
                        // Commit message
                        VStack(alignment: .leading, spacing: 8) {
                            Label("رسالة Commit", systemImage: "text.bubble.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            TextField("مثال: fix: إصلاح خطأ في ملف...", text: $commitMessage, axis: .vertical)
                                .font(.system(size: 14)).foregroundColor(AppColors.text)
                                .padding(12).background(AppColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                                .lineLimit(3...8)
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                        
                        // Repo & Branch
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Repository", systemImage: "square.stack.3d.up.fill")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                Picker("", selection: $selectedRepo) {
                                    Text("اختر...").tag("")
                                    ForEach(gitHubService.repositories) { repo in
                                        Text(repo.name).tag(repo.name)
                                            .environment(\.layoutDirection, .leftToRight)
                                    }
                                }
                                .pickerStyle(.menu).padding(10).background(AppColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Branch", systemImage: "arrow.triangle.branch")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                TextField("main", text: $selectedBranch)
                                    .font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.text)
                                    .padding(10).background(AppColors.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                                    .frame(width: 100)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        
                        // Commit history
                        if !gitOps.commitHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("آخر Commits", systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                ForEach(gitOps.commitHistory.prefix(3)) { commit in
                                    HStack(spacing: 8) {
                                        Text(commit.sha ?? "•••••••")
                                            .font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.accent)
                                        Text(commit.message).font(.system(size: 12)).foregroundColor(AppColors.text).lineLimit(1)
                                        Spacer()
                                        Text(commit.branch).font(.system(size: 10)).foregroundColor(AppColors.textSecondary)
                                    }
                                    .padding(10).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 8))
                                    .environment(\.layoutDirection, .leftToRight)
                                }
                            }
                        }
                        
                        // Result
                        if let result = gitOps.lastCommitResult {
                            Text(result).font(.system(size: 13))
                                .foregroundColor(result.hasPrefix("✅") ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B"))
                                .padding(12).frame(maxWidth: .infinity)
                                .background((result.hasPrefix("✅") ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B")).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
                
                Button { pushToGitHub() } label: {
                    HStack(spacing: 10) {
                        if gitOps.isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 20))
                        }
                        Text(gitOps.isLoading ? "جارٍ الرفع..." : "Commit & Push").font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 54)
                    .background(LinearGradient(
                        colors: canPush ? [Color(hex: "#6BCB77"), Color(hex: "#4CAF50")] : [AppColors.border, AppColors.border],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: canPush ? Color(hex: "#6BCB77").opacity(0.3) : .clear, radius: 10)
                }
                .disabled(!canPush || gitOps.isLoading).padding()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await gitHubService.fetchRepositories() }
            // Count files upfront
            let files = fileManager.collectAllFiles(from: fileManager.rootFiles)
            pendingFilesCount = files.count
        }
    }
    
    var canPush: Bool { !commitMessage.isEmpty && !selectedRepo.isEmpty && pendingFilesCount > 0 }
    
    private func pushToGitHub() {
        guard let user = gitHubService.currentUser else { return }
        // Fix: Use collectAllFiles to get text files recursively
        let files = fileManager.collectAllFiles(from: fileManager.rootFiles)
        guard !files.isEmpty else {
            gitOps.lastCommitResult = "❌ لا توجد ملفات نصية للرفع"
            return
        }
        Task {
            _ = await gitOps.commitAndPush(
                owner: user.login,
                repo: selectedRepo,
                branch: selectedBranch,
                message: commitMessage,
                files: files
            )
        }
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 14))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(color).padding(.horizontal, 12).padding(.vertical, 8)
            .background(color.opacity(0.12)).clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
        }
    }
}
