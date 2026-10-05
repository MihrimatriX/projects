import Foundation

public enum ContentClassifier {
    private static let emailPattern = try! NSRegularExpression(pattern: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#)
    private static let urlPattern = try! NSRegularExpression(pattern: #"^https?://[^\s]+$"#, options: .caseInsensitive)
    private static let codePattern = try! NSRegularExpression(
        pattern: #"(\{|\}|;|=>|function\s|class\s|def\s|import\s|#include\s|<\/?[a-z]+>)"#,
        options: .caseInsensitive
    )

    public static func classify(_ text: String) -> TextCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        if emailPattern.firstMatch(in: trimmed, range: range) != nil { return .email }
        if urlPattern.firstMatch(in: trimmed, range: range) != nil { return .url }
        if codePattern.firstMatch(in: trimmed, range: range) != nil { return .code }
        return .plain
    }
}
