import SwiftUI
import UniformTypeIdentifiers

// MARK: - Files View

struct FilesView: View {
    @StateObject private var fileManager = LocalFileManager()
    @EnvironmentObject var gitHubService: GitHubService

    @State private var showFileEditor    = false
    @State private var showCreateDialog  = false
    @State private var showCommitSheet   = false
    @State private var showImportPicker  = false
    @State private var showDeleteAlert   = false
    @State private var showRenameDialog  = false
    @State private var fileToDelete: GitFile?
    @State private var fileToRename: GitFile?
    @State private var newFileName       = ""
    @State private var isCreatingFolder  = false
    @State private var isEditMode        = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                VStack(spacing: 0) {
                    header
                    pathBar
                    toolbar.padding(.horizontal).padding(.bottom, 8)

                    if fileManager.isLoading {
                        LoadingCard()
                    } else if fileManager.rootFiles.isEmpty {
                        EmptyStateView(icon: "folder.badge.plus", title: "Empty folder", subtitle: "Add files or import from a repo")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(fileManager.rootFiles.enumerated()), id: \.element.id) { i, file in
                                    FileRowView(
                                        file: file, depth: 0,
                                        isEditMode: isEditMode,
                                        canMoveUp: i > 0,
                                        canMoveDown: i < fileManager.rootFiles.count - 1,
                                        onTap:      { handleTap($0) },
                                        onDelete:   { fileToDelete = $0; showDeleteAlert  = true },
                                        onRename:   { fileToRename = $0; newFileName = $0.name; showRenameDialog = true },
                                        onMoveUp:   { fileManager.moveFile(file, direction: .up) },
                                        onMoveDown: { fileManager.moveFile(file, direction: .down) }
                                    )
                                }
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showFileEditor) {
            if let f = fileManager.selectedFile {
                CodeEditorSheet(file: f, content: fileManager.fileContent) {
                    fileManager.writeFile(f, content: $0)
                }
            }
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitPushSheet(gitHubService: gitHubService, fileManager: fileManager)
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) {
            if case .success(let urls) = $0 { urls.forEach { fileManager.importFromFiles(url: $0) } }
        }
        .alert("Create \(isCreatingFolder ? "Folder" : "File")", isPresented: $showCreateDialog) {
            TextField("Name", text: $newFileName).autocorrectionDisabled().textInputAutocapitalization(.never)
            Button("Create") {
                if !newFileName.isEmpty {
                    fileManager.createFile(name: newFileName, at: fileManager.currentPath.path, isDirectory: isCreatingFolder)
                    newFileName = ""
                }
            }
            Button("Cancel", role: .cancel) { newFileName = "" }
        }
        .alert("Rename", isPresented: $showRenameDialog) {
            TextField("New name", text: $newFileName).autocorrectionDisabled().textInputAutocapitalization(.never)
            Button("Save") {
                if let f = fileToRename, !newFileName.isEmpty { fileManager.renameFile(f, newName: newFileName); newFileName = "" }
            }
            Button("Cancel", role: .cancel) { newFileName = "" }
        }
        .alert("Delete", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { if let f = fileToDelete { fileManager.deleteFile(f) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Delete \"\(fileToDelete?.name ?? "")\"?") }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Files").font(.system(size: 28, weight: .black)).foregroundColor(AppColors.text)
                Text("Project file manager").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Button { withAnimation { isEditMode.toggle() } } label: {
                Text(isEditMode ? "Done" : "Reorder")
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

    private var pathBar: some View {
        HStack(spacing: 8) {
            if !fileManager.isAtRoot {
                Button { fileManager.navigateUp() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("Back").font(.system(size: 12))
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.accent.opacity(0.1)).clipShape(Capsule())
                }
            }
            Text(fileManager.currentPathDisplay)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColors.textSecondary).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal).padding(.vertical, 6)
        .background(AppColors.surfaceElevated.opacity(0.5))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            ToolbarButton(icon: "doc.badge.plus",             label: "File",    color: AppColors.accent)        { isCreatingFolder = false; newFileName = ""; showCreateDialog = true }
            ToolbarButton(icon: "folder.badge.plus",          label: "Folder",  color: Color(hex: "#FFD93D"))   { isCreatingFolder = true;  newFileName = ""; showCreateDialog = true }
            ToolbarButton(icon: "square.and.arrow.down.fill", label: "Import",  color: Color(hex: "#6BCB77"))   { showImportPicker = true }
            ToolbarButton(icon: "arrow.clockwise",            label: "Refresh", color: AppColors.textSecondary) { fileManager.loadFiles(at: fileManager.currentPath) }
        }
    }

    private func handleTap(_ file: GitFile) {
        if file.isDirectory {
            fileManager.loadFiles(at: URL(fileURLWithPath: file.path))
        } else {
            fileManager.readFile(file)
            showFileEditor = true
        }
    }
}

// MARK: - File Row

struct FileRowView: View {
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
                        Text(file.name)
                            .font(.system(size: 14, weight: .medium,
                                          design: file.isDirectory ? .default : .monospaced))
                            .foregroundColor(AppColors.text).lineLimit(1)
                        Spacer()
                        if !file.isDirectory {
                            Text(fmtSize(file.size)).font(.system(size: 10)).foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { onTap(file) } label: { Label(file.isDirectory ? "Open" : "Edit", systemImage: "pencil") }
                    Button { onRename(file) } label: { Label("Rename", systemImage: "pencil.circle") }
                    Divider()
                    Button(role: .destructive) { onDelete(file) } label: { Label("Delete", systemImage: "trash") }
                }
            }
            .background(AppColors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if file.isDirectory && isExpanded, let children = file.children {
                ForEach(Array(children.enumerated()), id: \.element.id) { i, child in
                    FileRowView(
                        file: child, depth: depth + 1, isEditMode: isEditMode,
                        canMoveUp: i > 0, canMoveDown: i < children.count - 1,
                        onTap: onTap, onDelete: onDelete, onRename: onRename,
                        onMoveUp: onMoveUp, onMoveDown: onMoveDown
                    )
                    .padding(.leading, 12)
                }
            }
        }
    }

    func fmtSize(_ b: Int64) -> String {
        if b < 1024 { return "\(b)B" }
        if b < 1_048_576 { return "\(b/1024)KB" }
        return "\(b/1_048_576)MB"
    }
}

// MARK: - Code Editor Sheet (Full featured with syntax colors + copy buttons)

struct CodeEditorSheet: View {
    let file: GitFile
    let content: String
    let onSave: (String) -> Void

    @State private var text: String
    @State private var hasChanges    = false
    @State private var showCopyMenu  = false
    @State private var copyFeedback  = ""
    @State private var searchText    = ""
    @State private var showSearch    = false
    @Environment(\.dismiss) var dismiss

    init(file: GitFile, content: String, onSave: @escaping (String) -> Void) {
        self.file = file; self.content = content; self.onSave = onSave
        _text = State(initialValue: content)
    }

    var lines: [String] { text.components(separatedBy: "\n") }

    var filteredLineIndices: [Int] {
        guard !searchText.isEmpty else { return [] }
        return lines.indices.filter { lines[$0].localizedCaseInsensitiveContains(searchText) }
    }

    var errorLines: [Int] {
        lines.indices.filter {
            let l = lines[$0].lowercased()
            return l.contains("error:") || l.contains("failed") || l.contains("fatal:")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#080810").ignoresSafeArea()
                VStack(spacing: 0) {
                    // Top bar
                    HStack(spacing: 10) {
                        Image(systemName: file.icon).foregroundColor(file.iconColor)
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.text).lineLimit(1)
                        if hasChanges {
                            Circle().fill(Color(hex: "#FFD93D")).frame(width: 6, height: 6)
                        }
                        Spacer()
                        Text("\(lines.count) lines")
                            .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)

                        // Search toggle
                        Button {
                            withAnimation { showSearch.toggle() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15))
                                .foregroundColor(showSearch ? AppColors.accent : AppColors.textSecondary)
                        }

                        // Copy menu button
                        Menu {
                            Button {
                                UIPasteboard.general.string = text
                                copyFeedback = "Copied all!"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyFeedback = "" }
                            } label: {
                                Label("Copy All Code", systemImage: "doc.on.doc.fill")
                            }

                            Button {
                                let errors = lines.enumerated()
                                    .filter {
                                        let l = $0.element.lowercased()
                                        return l.contains("error:") || l.contains("failed") || l.contains("fatal:")
                                    }
                                    .map { "L\($0.offset + 1): \($0.element)" }
                                    .joined(separator: "\n")
                                UIPasteboard.general.string = errors.isEmpty ? "No errors found" : errors
                                copyFeedback = errors.isEmpty ? "No errors" : "Copied \(errorLines.count) errors!"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyFeedback = "" }
                            } label: {
                                Label("Copy Errors Only", systemImage: "exclamationmark.triangle.fill")
                            }

                            Button {
                                let warnings = lines.enumerated()
                                    .filter { $0.element.lowercased().contains("warning:") }
                                    .map { "L\($0.offset + 1): \($0.element)" }
                                    .joined(separator: "\n")
                                UIPasteboard.general.string = warnings.isEmpty ? "No warnings found" : warnings
                                copyFeedback = warnings.isEmpty ? "No warnings" : "Copied warnings!"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copyFeedback = "" }
                            } label: {
                                Label("Copy Warnings Only", systemImage: "exclamationmark.circle.fill")
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10).background(AppColors.surface)

                    // Copy feedback toast
                    if !copyFeedback.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#6BCB77"))
                            Text(copyFeedback).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(hex: "#1A1A2E"))
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: copyFeedback)
                    }

                    // Search bar
                    if showSearch {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textSecondary)
                            TextField("Search in file...", text: $searchText)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(AppColors.text)
                                .autocorrectionDisabled()
                            if !searchText.isEmpty {
                                Text("\(filteredLineIndices.count) matches")
                                    .font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                        .padding(10).background(AppColors.surfaceElevated)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Divider().background(AppColors.border)

                    // Code editor with line numbers + syntax colors
                    SyntaxEditorView(text: $text, onChange: { hasChanges = true }, searchText: searchText)
                }
            }
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSave(text); hasChanges = false; dismiss()
                    } label: {
                        Text("Save").font(.system(size: 14, weight: .bold))
                            .foregroundColor(hasChanges ? AppColors.accent : AppColors.textSecondary)
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Syntax Editor View
// Uses a single ScrollView that scrolls both line numbers and code together

struct SyntaxEditorView: View {
    @Binding var text: String
    let onChange: () -> Void
    let searchText: String

    var lines: [String] { text.components(separatedBy: "\n") }

    var body: some View {
        GeometryReader { geo in
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers gutter
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(0..<lines.count, id: \.self) { i in
                            Text("\(i + 1)")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(lineNumColor(i))
                                .frame(minWidth: 44, alignment: .trailing)
                                .frame(height: 20)
                                .background(lineBackground(i))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .background(Color(hex: "#0C0C18"))
                    .frame(minHeight: geo.size.height)

                    // Vertical separator
                    Rectangle().fill(AppColors.border).frame(width: 1)

                    // Code content — syntax colored non-editable display
                    // + overlay transparent TextEditor for editing
                    ZStack(alignment: .topLeading) {
                        // Syntax highlighted display
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<lines.count, id: \.self) { i in
                                SyntaxLine(line: lines[i], index: i, searchText: searchText)
                                    .frame(height: 20)
                            }
                            Spacer()
                        }
                        .padding(.leading, 8)

                        // Transparent editor on top for editing capability
                        TextEditor(text: Binding(get: { text }, set: { text = $0; onChange() }))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.clear) // invisible, syntax view handles colors
                            .tint(AppColors.accent)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minWidth: max(geo.size.width - 56, 300))
                            .padding(.leading, 8)
                    }
                    .frame(minWidth: max(geo.size.width - 56, 300))
                    .frame(minHeight: geo.size.height)
                }
                .background(Color(hex: "#080810"))
            }
            .background(Color(hex: "#080810"))
        }
    }

    func lineNumColor(_ i: Int) -> Color {
        let line = lines[i].lowercased()
        if line.contains("error:") || line.contains("failed") || line.contains("fatal:") { return Color(hex: "#FF6B6B") }
        if line.contains("warning:") { return Color(hex: "#FFD93D") }
        if !searchText.isEmpty && line.localizedCaseInsensitiveContains(searchText) { return AppColors.accent }
        return Color(hex: "#555570")
    }

    func lineBackground(_ i: Int) -> Color {
        let line = lines[i].lowercased()
        if line.contains("error:") || line.contains("failed") || line.contains("fatal:") { return Color(hex: "#FF6B6B").opacity(0.08) }
        if line.contains("warning:") { return Color(hex: "#FFD93D").opacity(0.05) }
        if !searchText.isEmpty && lines[i].localizedCaseInsensitiveContains(searchText) { return AppColors.accent.opacity(0.08) }
        return Color.clear
    }
}

// MARK: - Single Syntax Colored Line

struct SyntaxLine: View {
    let line: String
    let index: Int
    let searchText: String

    var lineType: BuildLog.LogLineType {
        let l = line.lowercased()
        if l.contains("error:") || l.contains("failed") || l.contains("fatal:") { return .error }
        if l.contains("warning:") { return .warning }
        if l.contains("success") || l.contains("passed") || l.contains("succeeded") { return .success }
        if line.hasPrefix("$") || line.hasPrefix(">") || line.hasPrefix("+ ") { return .command }
        if l.contains("##[") || l.contains("::notice") || l.contains("::group") { return .info }
        return .normal
    }

    var textColor: Color { lineType.color }

    var background: Color {
        switch lineType {
        case .error: return Color(hex: "#FF6B6B").opacity(0.07)
        case .warning: return Color(hex: "#FFD93D").opacity(0.05)
        default: return Color.clear
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            background
            Text(line.isEmpty ? " " : line)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(textColor)
                .lineLimit(1)
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Commit Push Sheet

struct CommitPushSheet: View {
    @ObservedObject var gitHubService: GitHubService
    @ObservedObject var fileManager: LocalFileManager

    @StateObject private var gitOps: GitOperationsManager
    @State private var commitMessage = ""
    @State private var selectedRepo  = ""
    @State private var branch        = "main"
    @State private var fileCount     = 0
    @Environment(\.dismiss) var dismiss

    init(gitHubService: GitHubService, fileManager: LocalFileManager) {
        self.gitHubService = gitHubService
        self.fileManager   = fileManager
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
                    } else { Spacer().frame(width: 22) }
                }
                .padding()
                Divider().background(AppColors.border)

                ScrollView {
                    VStack(spacing: 16) {
                        // File count badge
                        HStack {
                            Image(systemName: "doc.fill").foregroundColor(fileCount > 0 ? AppColors.accent : Color(hex: "#FF6B6B"))
                            Text(fileCount > 0 ? "\(fileCount) text files ready to push" : "No text files found")
                                .font(.system(size: 13))
                                .foregroundColor(fileCount > 0 ? AppColors.text : Color(hex: "#FF6B6B"))
                            Spacer()
                        }
                        .padding(12)
                        .background((fileCount > 0 ? AppColors.accent : Color(hex: "#FF6B6B")).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder((fileCount > 0 ? AppColors.accent : Color(hex: "#FF6B6B")).opacity(0.25), lineWidth: 1))

                        // Commit message
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Commit message", systemImage: "text.bubble.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                            TextField("fix: description...", text: $commitMessage, axis: .vertical)
                                .font(.system(size: 14)).foregroundColor(AppColors.text)
                                .padding(12).background(AppColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                                .lineLimit(3...6)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Repository", systemImage: "square.stack.3d.up.fill")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                Picker("", selection: $selectedRepo) {
                                    Text("Select...").tag("")
                                    ForEach(gitHubService.repositories) { r in Text(r.name).tag(r.name) }
                                }
                                .pickerStyle(.menu).padding(10).background(AppColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Branch", systemImage: "arrow.triangle.branch")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                TextField("main", text: $branch)
                                    .font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.text)
                                    .padding(10).background(AppColors.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.border, lineWidth: 1))
                                    .frame(width: 100)
                            }
                        }

                        if !gitOps.commitHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Recent Commits", systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.textSecondary)
                                ForEach(gitOps.commitHistory.prefix(3)) { c in
                                    HStack(spacing: 8) {
                                        Text(c.sha ?? "•••••••").font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.accent)
                                        Text(c.message).font(.system(size: 12)).foregroundColor(AppColors.text).lineLimit(1)
                                        Spacer()
                                        Text(c.branch).font(.system(size: 10)).foregroundColor(AppColors.textSecondary)
                                    }
                                    .padding(10).background(AppColors.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        if let r = gitOps.lastCommitResult {
                            Text(r).font(.system(size: 13))
                                .foregroundColor(r.hasPrefix("✅") ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B"))
                                .multilineTextAlignment(.center).padding(12).frame(maxWidth: .infinity)
                                .background((r.hasPrefix("✅") ? Color(hex: "#6BCB77") : Color(hex: "#FF6B6B")).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                }

                Button { push() } label: {
                    HStack(spacing: 10) {
                        if gitOps.isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 20))
                        }
                        Text(gitOps.isLoading ? "Pushing..." : "Commit & Push")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 54)
                    .background(LinearGradient(
                        colors: canPush ? [Color(hex: "#6BCB77"), Color(hex: "#4CAF50")] : [AppColors.border, AppColors.border],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: canPush ? Color(hex: "#6BCB77").opacity(0.3) : .clear, radius: 10)
                }
                .disabled(!canPush || gitOps.isLoading).padding()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await gitHubService.fetchRepositories() }
            fileCount = fileManager.collectAllFiles(from: fileManager.rootFiles).count
        }
    }

    var canPush: Bool { !commitMessage.isEmpty && !selectedRepo.isEmpty && fileCount > 0 }

    private func push() {
        guard let user = gitHubService.currentUser else { return }
        let files = fileManager.collectAllFiles(from: fileManager.rootFiles)
        fileCount = files.count
        guard !files.isEmpty else { gitOps.lastCommitResult = "❌ No text files found"; return }
        Task {
            _ = await gitOps.commitAndPush(owner: user.login, repo: selectedRepo, branch: branch, message: commitMessage, files: files)
            await MainActor.run { fileCount = fileManager.collectAllFiles(from: fileManager.rootFiles).count }
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
