import Foundation

struct ClipboardEntry: Identifiable, Equatable, Hashable {
    let id: Int64
    let type: String
    let content: String
    let timestamp: Date
    var isPinned: Bool

    var displayName: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(77)) + "..."
    }

    var category: TextCategory {
        ContentClassifier.classify(content)
    }

    var categoryLabel: String {
        switch category {
        case .url: return "URL"
        case .email: return "E-posta"
        case .code: return "Kod"
        case .plain: return "Metin"
        }
    }
}

public enum TextCategory: Equatable {
    case plain, url, email, code
}
