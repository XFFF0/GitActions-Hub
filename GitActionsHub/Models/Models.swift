import Foundation

struct GitFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let isTextFile: Bool
    let isBinaryFile: Bool   // ✅ جديد
    let content: String?
}
